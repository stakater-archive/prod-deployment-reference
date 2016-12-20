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
variable "internal_support" {
  description = "If set false, This will exxpose the resoure publically."
}
