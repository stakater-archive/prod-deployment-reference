## Configures providers
provider "aws" {
  region = "${var.aws_region}"
}

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
      command = "../scripts/create-keypair.sh -k ${var.app_name}-key -r ${var.aws_region} -b ${data.terraform_remote_state.prod.config-bucket-name}"
  }
}

## Template files
data "template_file" "deployer-policy" {
  template = "${file("../policy/role-policy.json")}"

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



