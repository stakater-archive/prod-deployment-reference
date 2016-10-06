# Remote states
data "terraform_remote_state" "prod" {
    backend = "s3"
    config {
        bucket = "${var.tf_state_bucket_name}"
        key = "${var.prod_state_key}"
        region = "${var.aws_region}"
    }
}

data "terraform_remote_state" "global-admiral" {
    backend = "s3"
    config {
        bucket = "${var.tf_state_bucket_name}"
        key = "${var.global_admiral_state_key}"
        region = "${var.aws_region}"
    }
}

# Create keypair if not exists and upload to s3
# make sure this resource is created before the module prod-deployer
resource "null_resource" "create-key-pair" {
  provisioner "local-exec" {
      command = "./scripts/create-keypair.sh -k ${var.app_name}-key -r ${var.aws_region} -b ${data.terraform_remote_state.prod.config-bucket-name}"
  }
}

## Provisions basic autoscaling group
module "prod-deployer" {
  source = "git::https://github.com/stakater/blueprint-instance-pool-aws.git//modules/instance-pool"

  # Resource tags
  name = "${var.app_name}"

  # VPC parameters
  vpc_id  = "${data.terraform_remote_state.prod.vpc_id}"
  vpc_cidr  = "${data.terraform_remote_state.prod.vpc_cidr}"
  subnets = "${data.terraform_remote_state.prod.private_app_subnet_ids}"
  region  = "${var.aws_region}"

  # LC parameters
  ami              = "${var.prod_ami}" # The AMI that is to be launched
  instance_type    = "${var.instance_type}"
  iam_assume_role_policy = "${file("./policy/assume-role-policy.json")}"
  iam_role_policy  = "${data.template_file.deployer-policy.rendered}"
  user_data        = "" # No user data as custom AMI will be launched
  key_name         = "${var.app_name}-key"
  root_vol_size    = 30
  data_ebs_device_name  = "/dev/sdf"
  data_ebs_vol_size     = 50
  logs_ebs_device_name  = "/dev/sdg"
  logs_ebs_vol_size     = 20

  # ASG parameters
  max_size         = "2"
  min_size         = "2"
  min_elb_capacity = "2"
  load_balancers   = "${aws_elb.deployer-elb.id}"
}

## Template files
data "template_file" "deployer-policy" {
  template = "${file("./policy/role-policy.json")}"

  vars {
    config_bucket_arn = "${data.terraform_remote_state.prod.config-bucket-arn}"
    cloudinit_bucket_arn = "${data.terraform_remote_state.prod.cloudinit-bucket-arn}"
    global_admiral_config_bucket_arn = "${data.terraform_remote_state.global-admiral.config-bucket-arn}"
  }
}

## Creates ELB security group
resource "aws_security_group" "deployer-sg-elb" {
  name_prefix = "${var.app_name}-prod-elb-"
  vpc_id      = "${data.terraform_remote_state.prod.vpc_id}"

  tags {
    Name        = "${var.app_name}-prod-elb"
    managed_by  = "Stakater"
  }

  lifecycle {
    create_before_destroy = true
  }

  # Allow HTTP traffic
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
}

## Creates ELB
resource "aws_elb" "deployer-elb" {
  name                      = "${replace(var.app_name, "_", "-")}-prod-elb" #replace _ with - as _ is not allowed in elb-name
  security_groups           = ["${aws_security_group.deployer-sg-elb.id}"]
  subnets                   = ["${split(",",data.terraform_remote_state.prod.public_subnet_ids)}"]
  internal                  = false
  cross_zone_load_balancing = true
  connection_draining       = true

  tags {
    Name        = "${var.app_name}-prod-elb"
    managed_by  = "Stakater"
  }

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 10
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:22"
    interval            = 30
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ELB Stickiness policy
resource "aws_lb_cookie_stickiness_policy" "deployer-elb-stickiness-policy" {
      name = "${aws_elb.deployer-elb.name}-stickiness"
      load_balancer = "${aws_elb.deployer-elb.id}"
      lb_port = 80
}

# Route53 record
resource "aws_route53_record" "deployer" {
  zone_id = "${data.terraform_remote_state.global-admiral.route53_private_zone_id}"
  name = "${var.app_name}"
  type = "A"

  alias {
    name = "${aws_elb.deployer-elb.dns_name}"
    zone_id = "${aws_elb.deployer-elb.zone_id}"
    evaluate_target_health = true
  }
}


####################################
# ASG Scaling Policies
####################################
## Provisions autoscaling policies and associated resources
module "deployer-scale-up-policy" {
  source = "git::https://github.com/stakater/blueprint-instance-pool-aws.git//modules/asg-policy"

  # Resource tags
  name = "${var.app_name}-prod-scaleup-policy"

  # ASG parameters
  asg_name = "${module.prod-deployer.asg_name}"
  asg_id   = "${module.prod-deployer.asg_id}"

  # Notification parameters
  notifications = "autoscaling:EC2_INSTANCE_LAUNCH_ERROR,autoscaling:EC2_INSTANCE_TERMINATE_ERROR"

  # Monitor parameters
  adjustment_type          = "PercentChangeInCapacity"
  scaling_adjustment       = 30
  cooldown                 = 300
  min_adjustment_magnitude = 2
  comparison_operator      = "GreaterThanOrEqualToThreshold"
  evaluation_periods       = 2
  metric_name              = "CPUUtilization"
  period                   = 120
  threshold                = 10
}

module "deployer-scale-down-policy" {
  source = "git::https://github.com/stakater/blueprint-instance-pool-aws.git//modules/asg-policy"

  # Resource tags
  name = "${var.app_name}-prod-scaledown-policy"

  # ASG parameters
  asg_name = "${module.prod-deployer.asg_name}"
  asg_id   = "${module.prod-deployer.asg_id}"

  # Notification parameters
  notifications = "autoscaling:EC2_INSTANCE_LAUNCH_ERROR,autoscaling:EC2_INSTANCE_TERMINATE_ERROR"

  # Monitor parameters
  adjustment_type     = "ChangeInCapacity"
  scaling_adjustment  = 2
  cooldown            = 300
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  period              = 120
  threshold           = 10
}


## Adds security group rules
resource "aws_security_group_rule" "sg-deployer" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  cidr_blocks              = ["${data.terraform_remote_state.prod.vpc_cidr}"]
  security_group_id        = "${module.prod-deployer.security_group_id}"

  lifecycle {
    create_before_destroy = true
  }
}

## Adds security group rule in docker registry
# Allow registry to be accessed by this VPC
resource "aws_security_group_rule" "sg-deployer-registry" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = ["${data.terraform_remote_state.prod.vpc_cidr}"]
  security_group_id        = "${data.terraform_remote_state.global-admiral.docker-registry-sg-id}"

  lifecycle {
    create_before_destroy = true
  }
}