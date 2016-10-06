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

variable "prod_ami" {
  description = "AMI ID to be deployed"
}

variable "instance_type" {
  description = "EC2 Instance type for the deployed application"
  default = "t2.medium"
}

variable "app_name" {
  description = "Name of the application to deploy"
}