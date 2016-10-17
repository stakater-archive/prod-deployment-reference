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
