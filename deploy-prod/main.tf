###############################################################################
# Copyright 2016 Aurora Solutions
#
#    http://www.aurorasolutions.io
#
# Aurora Solutions is an innovative services and product company at
# the forefront of the software industry, with processes and practices
# involving Domain Driven Design(DDD), Agile methodologies to build
# scalable, secure, reliable and high performance products.
#
# Stakater is an Infrastructure-as-a-Code DevOps solution to automate the
# creation of web infrastructure stack on Amazon. Stakater is a collection
# of Blueprints; where each blueprint is an opinionated, reusable, tested,
# supported, documented, configurable, best-practices definition of a piece
# of infrastructure. Stakater is based on Docker, CoreOS, Terraform, Packer,
# Docker Compose, GoCD, Fleet, ETCD, and much more.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

## Configures providers
provider "aws" {
  region = "${var.aws_region}"
}

# Remote states
data "terraform_remote_state" "env_state" {
    backend = "s3"
    config {
        bucket = "${var.tf_state_bucket_name}"
        key = "${var.env_state_key}"
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
      command = "../scripts/create-keypair.sh -k ${var.app_name}-${var.environment}-key -r ${var.aws_region} -b ${data.terraform_remote_state.env_state.config-bucket-name}"
  }
}

## Template files
data "template_file" "deployer-policy" {
  template = "${file("../policy/role-policy.json")}"

  vars {
    config_bucket_arn = "${data.terraform_remote_state.env_state.config-bucket-arn}"
    cloudinit_bucket_arn = "${data.terraform_remote_state.env_state.cloudinit-bucket-arn}"
    global_admiral_config_bucket_arn = "${data.terraform_remote_state.global-admiral.config-bucket-arn}"
  }
}

## Creates Active ELB security group
resource "aws_security_group" "deployer-sg-elb-active" {
  count       = "${signum(length(var.ssl_certificate_arn)) + 1 % 2}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
  name_prefix = "${var.app_name}-${var.environment}-elb-active-"
  vpc_id      = "${data.terraform_remote_state.env_state.vpc_id}"

  tags {
    Name        = "${var.app_name}-${var.environment}-elb-active"
    managed_by  = "Stakater"
  }

  lifecycle {
    create_before_destroy = true
  }

  # Allow HTTP traffic
  ingress {
    cidr_blocks = ["${split(",",var.active_elb_cidr_block)}"]
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

## Creates Active ELB security group
resource "aws_security_group" "deployer-sg-elb-active-ssl" {
  count       = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
  name_prefix = "${var.app_name}-${var.environment}-elb-active-"
  vpc_id      = "${data.terraform_remote_state.env_state.vpc_id}"

  tags {
    Name        = "${var.app_name}-${var.environment}-elb-active"
    managed_by  = "Stakater"
  }

  lifecycle {
    create_before_destroy = true
  }

  # Allow HTTP traffic
  ingress {
    cidr_blocks = ["${split(",",var.active_elb_cidr_block)}"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["${split(",",var.active_elb_cidr_block)}"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
}

## Creates Test ELB security group
resource "aws_security_group" "deployer-sg-elb-test" {
  count       = "${signum(length(var.ssl_certificate_arn)) + 1 % 2}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
  name_prefix = "${var.app_name}-${var.environment}-elb-test-"
  vpc_id      = "${data.terraform_remote_state.env_state.vpc_id}"

  tags {
    Name        = "${var.app_name}-${var.environment}-elb-test"
    managed_by  = "Stakater"
  }

  lifecycle {
    create_before_destroy = true
  }

  # Allow HTTP traffic
  ingress {
    cidr_blocks = ["${split(",",var.test_elb_cidr_block)}"]
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

## Creates Test ELB security group
resource "aws_security_group" "deployer-sg-elb-test-ssl" {
  count       = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
  name_prefix = "${var.app_name}-${var.environment}-elb-test-"
  vpc_id      = "${data.terraform_remote_state.env_state.vpc_id}"

  tags {
    Name        = "${var.app_name}-${var.environment}-elb-test"
    managed_by  = "Stakater"
  }

  lifecycle {
    create_before_destroy = true
  }

  # Allow HTTP traffic
  ingress {
    cidr_blocks = ["${split(",",var.test_elb_cidr_block)}"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["${split(",",var.test_elb_cidr_block)}"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
}

## Creates Active ELB
resource "aws_elb" "deployer-elb-active" {
  count                     = "${signum(length(var.ssl_certificate_arn)) + 1 % 2}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
  name                      = "${replace(var.app_name, "_", "-")}-${replace(var.environment, "_", "-")}-elb-active" #replace _ with - as _ is not allowed in elb-name
  security_groups           = ["${aws_security_group.deployer-sg-elb-active.id}"]
  subnets                   = ["${split(",",data.terraform_remote_state.env_state.public_subnet_ids)}"]
  internal                  = "${var.is_elb_internal}"
  cross_zone_load_balancing = true
  connection_draining       = true

  tags {
    Name        = "${var.app_name}-${var.environment}-elb-active"
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
    interval            = 10
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ELB Stickiness policy
resource "aws_lb_cookie_stickiness_policy" "deployer-elb-active-stickiness-policy" {
      count = "${signum(length(var.ssl_certificate_arn)) + 1 % 2}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
      name = "${aws_elb.deployer-elb-active.name}-stickiness"
      load_balancer = "${aws_elb.deployer-elb-active.id}"
      lb_port = 80
}

resource "aws_elb" "deployer-elb-active-ssl" {
  count                     = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certicate_id is set, this will result in 1 and will create ssl resource
  name                      = "${replace(var.app_name, "_", "-")}-${replace(var.environment, "_", "-")}-elb-active" #replace _ with - as _ is not allowed in elb-name
  security_groups           = ["${aws_security_group.deployer-sg-elb-active-ssl.id}"]
  subnets                   = ["${split(",",data.terraform_remote_state.env_state.public_subnet_ids)}"]
  internal                  = false
  cross_zone_load_balancing = true
  connection_draining       = true

  tags {
    Name        = "${var.app_name}-${var.environment}-elb-active"
    managed_by  = "Stakater"
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 443
    lb_protocol       = "https"
    ssl_certificate_id = "${var.ssl_certificate_arn}"
  }

  health_check {
    healthy_threshold   = 10
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:22"
    interval            = 10
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_cookie_stickiness_policy" "deployer-elb-active-stickiness-policy-ssl-80" {
      count = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
      name = "${aws_elb.deployer-elb-active-ssl.name}-stickiness"
      load_balancer = "${aws_elb.deployer-elb-active-ssl.id}"
      lb_port = 80
}

# ELB Stickiness policy
resource "aws_lb_cookie_stickiness_policy" "deployer-elb-active-stickiness-policy-ssl-443" {
      count = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
      name = "${aws_elb.deployer-elb-active-ssl.name}-stickiness"
      load_balancer = "${aws_elb.deployer-elb-active-ssl.id}"
      lb_port = 443
}

# Route53 record
resource "aws_route53_record" "deployer-prod-active" {
  count = "${signum(length(var.ssl_certificate_arn)) + 1 % 2}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
  zone_id = "${data.terraform_remote_state.env_state.route53_private_zone_id}"
  name = "${var.app_name}-${var.environment}-active"
  type = "A"

  alias {
    name = "${aws_elb.deployer-elb-active.dns_name}"
    zone_id = "${aws_elb.deployer-elb-active.zone_id}"
    evaluate_target_health = true
  }
}

# Route53 record
resource "aws_route53_record" "deployer-prod-active-ssl" {
  count = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
  zone_id = "${data.terraform_remote_state.env_state.route53_private_zone_id}"
  name = "${var.app_name}-${var.environment}-active"
  type = "A"

  alias {
    name = "${aws_elb.deployer-elb-active-ssl.dns_name}"
    zone_id = "${aws_elb.deployer-elb-active-ssl.zone_id}"
    evaluate_target_health = true
  }
}

## Creates Test ELB
resource "aws_elb" "deployer-elb-test" {
  count                     = "${signum(length(var.ssl_certificate_arn)) + 1 % 2}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
  name                      = "${replace(var.app_name, "_", "-")}-${var.environment}-elb-test" #replace _ with - as _ is not allowed in elb-name
  security_groups           = ["${aws_security_group.deployer-sg-elb-test.id}"]
  subnets                   = ["${split(",",data.terraform_remote_state.env_state.public_subnet_ids)}"]
  internal                  = "${var.is_elb_internal}"
  cross_zone_load_balancing = true
  connection_draining       = true

  tags {
    Name        = "${var.app_name}-${var.environment}-elb-test"
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
    interval            = 10
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ELB Stickiness policy
resource "aws_lb_cookie_stickiness_policy" "deployer-elb-test-stickiness-policy" {
      count = "${signum(length(var.ssl_certificate_arn)) + 1 % 2}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
      name = "${aws_elb.deployer-elb-test.name}-stickiness"
      load_balancer = "${aws_elb.deployer-elb-test.id}"
      lb_port = 80
}

resource "aws_elb" "deployer-elb-test-ssl" {
  count                     = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
  name                      = "${replace(var.app_name, "_", "-")}-${var.environment}-elb-test" #replace _ with - as _ is not allowed in elb-name
  security_groups           = ["${aws_security_group.deployer-sg-elb-test-ssl.id}"]
  subnets                   = ["${split(",",data.terraform_remote_state.env_state.public_subnet_ids)}"]
  internal                  = false
  cross_zone_load_balancing = true
  connection_draining       = true

  tags {
    Name        = "${var.app_name}-${var.environment}-elb-test"
    managed_by  = "Stakater"
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 443
    lb_protocol       = "https"
    ssl_certificate_id = "${var.ssl_certificate_arn}"
  }

  health_check {
    healthy_threshold   = 10
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:22"
    interval            = 10
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_cookie_stickiness_policy" "deployer-elb-test-stickiness-policy-ssl-80" {
      count = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
      name = "${aws_elb.deployer-elb-test-ssl.name}-stickiness"
      load_balancer = "${aws_elb.deployer-elb-test-ssl.id}"
      lb_port = 80
}

resource "aws_lb_cookie_stickiness_policy" "deployer-elb-test-stickiness-policy-ssl-443" {
      count = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
      name = "${aws_elb.deployer-elb-test-ssl.name}-stickiness"
      load_balancer = "${aws_elb.deployer-elb-test-ssl.id}"
      lb_port = 443
}

# Route53 record
resource "aws_route53_record" "deployer-prod-test" {
  count = "${signum(length(var.ssl_certificate_arn)) + 1 % 2}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
  zone_id = "${data.terraform_remote_state.env_state.route53_private_zone_id}"
  name = "${var.app_name}-${var.environment}-test"
  type = "A"

  alias {
    name = "${aws_elb.deployer-elb-test.dns_name}"
    zone_id = "${aws_elb.deployer-elb-test.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "deployer-prod-test-ssl" {
  count = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 1 and will create ssl resource
  zone_id = "${data.terraform_remote_state.env_state.route53_private_zone_id}"
  name = "${var.app_name}-${var.environment}-test"
  type = "A"

  alias {
    name = "${aws_elb.deployer-elb-test-ssl.dns_name}"
    zone_id = "${aws_elb.deployer-elb-test-ssl.zone_id}"
    evaluate_target_health = true
  }
}

