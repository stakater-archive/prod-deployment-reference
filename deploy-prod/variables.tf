variable "aws_region" {
  description = "AWS Region in which the deployment is taking place in"
}

variable "tf_state_bucket_name" {
  description = "Name of the S3 bucket in which the terraform state files are stored"
}

variable "prod_state_key" {
  description = "Key for the prod environment terraform state on S3"
  default = "prod/terraform.tfstate"
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

variable "enable_ssl" {
  description = "If set to true, This will create resources with SSL settings enabled. If false, it will create resources without SSL settings enabled"
  default = "0"
}

variable "ssl_certificate_id" {
  description = "Required if enable_ssl is set"
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

variable "green_group_load_balancers" {
  description = "List of load balancers to add to green auto sscaling group"
}

variable "green_group_min_elb_capacity" {
  description = "Minimum number of healthy instances attached to the ELB."
}
