variable "aws_profile" {
  type        = string
  description = "AWS account profile to create resources in"
}

variable "aws_region" {
  type        = string
  description = "AWS region to create resources in"
}

variable "vpc_name" {
  type        = string
  description = "VPC resource name on AWS"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR range"
}

variable "vpc_subnet_map" {
  type        = map(string)
  description = "mapping of subnet AZ to CIDR block"
}