// GLOBAL VARS

variable "aws_profile" {
  type        = string
  description = "AWS account profile to create resources in"
}

variable "aws_region" {
  type        = string
  description = "AWS region to create resources in"
}

// VPC - 1 VARS

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

variable "vpc_enable_classiclink_dns_support" {
  type        = bool
  description = "A boolean flag to enable/disable ClassicLink DNS Support for the VPC"
}

variable "vpc_enable_dns_hostnames" {
  type        = bool
  description = "A boolean flag to enable/disable DNS hostnames in the VPC"
}