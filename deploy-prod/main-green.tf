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

## Blue Green Deployment
# Green Group

## Provisions basic autoscaling group
module "prod-green-group-deployer" {
  source = "git::https://github.com/stakater/blueprint-instance-pool-aws.git//modules/instance-pool"

  # Resource tags
  name = "${var.app_name}-${var.environment}-green-group"

  # VPC parameters
  vpc_id  = "${data.terraform_remote_state.env_state.vpc_id}"
  subnets = "${data.terraform_remote_state.env_state.private_app_subnet_ids}"
  region  = "${var.aws_region}"

  # LC parameters
  ami              = "${var.ami_green_group}" # The AMI that is to be launched
  instance_type    = "${var.instance_type}"
  iam_assume_role_policy = "${file("../policy/assume-role-policy.json")}"
  iam_role_policy  = "${data.template_file.deployer-policy.rendered}"
  user_data        = "" # No user data as custom AMI will be launched
  key_name         = "${var.app_name}-${var.environment}-key"
  root_vol_size    = 50
  data_ebs_device_name  = ""
  data_ebs_vol_size     = 0
  logs_ebs_device_name  = ""
  logs_ebs_vol_size     = 0

  # ASG parameters
  max_size         = "${var.green_cluster_max_size}"
  min_size         = "${var.green_cluster_min_size}"
  desired_size     = "${var.green_cluster_desired_size}"
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
  name = "${var.app_name}-${var.environment}-green-group-scaleup-policy"

  # ASG parameters
  asg_name = "${module.prod-green-group-deployer.asg_name}"
  asg_id   = "${module.prod-green-group-deployer.asg_id}"

  # Notification parameters
  notifications = "autoscaling:EC2_INSTANCE_LAUNCH_ERROR,autoscaling:EC2_INSTANCE_TERMINATE_ERROR"

  # Monitor parameters
  adjustment_type          = "ChangeInCapacity"
  scaling_adjustment       = 1
  cooldown                 = 300
  comparison_operator      = "GreaterThanOrEqualToThreshold"
  evaluation_periods       = 2
  metric_name              = "CPUUtilization"
  period                   = 60
  threshold                = 80
}

module "deployer-green-group-scale-down-policy" {
  source = "git::https://github.com/stakater/blueprint-instance-pool-aws.git//modules/asg-policy"

  # Resource tags
  name = "${var.app_name}-${var.environment}-green-group-scaledown-policy"

  # ASG parameters
  asg_name = "${module.prod-green-group-deployer.asg_name}"
  asg_id   = "${module.prod-green-group-deployer.asg_id}"

  # Notification parameters
  notifications = "autoscaling:EC2_INSTANCE_LAUNCH_ERROR,autoscaling:EC2_INSTANCE_TERMINATE_ERROR"

  # Monitor parameters
  adjustment_type     = "ChangeInCapacity"
  scaling_adjustment  = -1
  cooldown            = 300
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 30
  metric_name         = "CPUUtilization"
  period              = 60
  threshold           = 50
}


## Adds security group rules
# Allow ssh from within vpc
resource "aws_security_group_rule" "green-group-sg-deployer-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  cidr_blocks              = ["${data.terraform_remote_state.env_state.vpc_cidr}"]
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
  cidr_blocks              = ["${data.terraform_remote_state.env_state.vpc_cidr}"]
  security_group_id        = "${module.prod-green-group-deployer.security_group_id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "green-group-sg-deployer-app-ssl" {
  count                    = "${signum(length(var.ssl_certificate_arn))}" # if ssl_certificate_arn is set, this will result in 0 and will create non-ssl resource
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = ["${data.terraform_remote_state.env_state.vpc_cidr}"]
  security_group_id        = "${module.prod-green-group-deployer.security_group_id}"

  lifecycle {
    create_before_destroy = true
  }
}
