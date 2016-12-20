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

variable "aws_region" {
  description = "AWS Region in which the deployment is taking place in"
}

variable "environment" {
  description = "Environment of sub stack"
}

variable "tf_state_bucket_name" {
  description = "Name of the S3 bucket in which the terraform state files are stored"
}

variable "env_state_key" {
  description = "Key for the environment terraform state on S3"
}

variable "global_admiral_state_key" {
  description = "Key for the global-admiral terraform state on S3"
  default = "global-admiral/terraform.tfstate"
}

variable "instance_type" {
  description = "EC2 Instance type for the deployed application"
  default = "t2.medium"
}

variable "app_name" {
  description = "Name of the application to deploy"
}

variable "ssl_certificate_arn" {
  description = "Required if you want ssl resources"
  default = ""
}

## Blue group parameters
variable "ami_blue_group" {
  description = "AMI ID to be deployed on blue group"
}

variable "blue_cluster_max_size" {
  description = "Maximum instances in blue group"
}

variable "blue_cluster_min_size" {
  description = "Minimum instances in blue group"
}

variable "blue_cluster_desired_size" {
  description = "Desired instances in blue group"
}

variable "blue_group_load_balancers" {
  description = "List of load balancers to add to blue auto sscaling group"
}

variable "blue_group_min_elb_capacity" {
  description = "Minimum number of healthy instances attached to the ELB."
}


## Green group parameters
variable "ami_green_group" {
  description = "AMI ID to be deployed on green group"
}

variable "green_cluster_max_size" {
  description = "Maximum instances in green group"
}

variable "green_cluster_min_size" {
  description = "Minimum instances in green group"
}

variable "green_cluster_desired_size" {
  description = "Desired instances in green group"
}

variable "green_group_load_balancers" {
  description = "List of load balancers to add to green auto sscaling group"
}

variable "green_group_min_elb_capacity" {
  description = "Minimum number of healthy instances attached to the ELB."
}
variable "is_elb_internal" {
  description = "If set false, This will exxpose the resoure publically."
}
