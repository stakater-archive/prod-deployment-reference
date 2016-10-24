## Blue Green Deployment
# Green Group

## Provisions basic autoscaling group
module "prod-green-group-deployer" {
  source = "git::https://github.com/stakater/blueprint-instance-pool-aws.git//modules/instance-pool"

  # Resource tags
  name = "${var.app_name}-green-group"

  # VPC parameters
  vpc_id  = "${data.terraform_remote_state.prod.vpc_id}"
  subnets = "${data.terraform_remote_state.prod.private_app_subnet_ids}"
  region  = "${var.aws_region}"

  # LC parameters
  ami              = "${var.ami_green_group}" # The AMI that is to be launched
  instance_type    = "${var.instance_type}"
  iam_assume_role_policy = "${file("../policy/assume-role-policy.json")}"
  iam_role_policy  = "${data.template_file.deployer-policy.rendered}"
  user_data        = "" # No user data as custom AMI will be launched
  key_name         = "${var.app_name}-key"
  root_vol_size    = 30
  data_ebs_device_name  = "/dev/sdf"
  data_ebs_vol_size     = 50
  logs_ebs_device_name  = "/dev/sdg"
  logs_ebs_vol_size     = 20

  # ASG parameters
  max_size         = "${var.green_cluster_max_size}"
  min_size         = "${var.green_cluster_min_size}"
  min_elb_capacity = "${var.green_group_min_elb_capacity}"
  load_balancers   = "${var.green_group_load_balancers}"
}

####################################
# ASG Scaling Policies
####################################
## Provisions autoscaling policies and associated resources
module "deployer-green-group-scale-up-policy" {
  source = "git::https://github.com/stakater/blueprint-instance-pool-aws.git//modules/asg-policy"

  # Resource tags
  name = "${var.app_name}-prod-green-group-scaleup-policy"

  # ASG parameters
  asg_name = "${module.prod-green-group-deployer.asg_name}"
  asg_id   = "${module.prod-green-group-deployer.asg_id}"

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

module "deployer-green-group-scale-down-policy" {
  source = "git::https://github.com/stakater/blueprint-instance-pool-aws.git//modules/asg-policy"

  # Resource tags
  name = "${var.app_name}-prod-green-group-scaledown-policy"

  # ASG parameters
  asg_name = "${module.prod-green-group-deployer.asg_name}"
  asg_id   = "${module.prod-green-group-deployer.asg_id}"

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
# Allow ssh from within vpc
resource "aws_security_group_rule" "green-group-sg-deployer-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  cidr_blocks              = ["${data.terraform_remote_state.prod.vpc_cidr}"]
  security_group_id        = "${module.prod-green-group-deployer.security_group_id}"

  lifecycle {
    create_before_destroy = true
  }
}

# Allow Outgoing traffic
resource "aws_security_group_rule" "green-group-sg-deployer-outgoing" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id        = "${module.prod-green-group-deployer.security_group_id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "green-group-sg-deployer-app" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  cidr_blocks              = ["${data.terraform_remote_state.prod.vpc_cidr}"]
  security_group_id        = "${module.prod-green-group-deployer.security_group_id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "green-group-sg-deployer-app-ssl" {
  count                    = "${var.enable_ssl}" # if enable_ssl is set to false, this will result in 0 and will create non-ssl resource
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = ["${data.terraform_remote_state.prod.vpc_cidr}"]
  security_group_id        = "${module.prod-green-group-deployer.security_group_id}"

  lifecycle {
    create_before_destroy = true
  }
}
