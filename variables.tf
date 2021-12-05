// GLOBAL VARS

variable "aws_profile" {
  type        = string
  description = "AWS account profile to create resources in"
}

variable "aws_region" {
  type        = string
  description = "AWS region to create resources in"
}

// VPC VARS

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

// RDS VARS

variable "rds_identifier" {
  type        = string
}

variable "rds_identifier_replica" {
  type        = string
}

variable "rds_username" {
  type        = string
}

variable "rds_password" {
  type        = string
}

// S3 VARS

variable "s3_domain" {
  type        = string
}

variable "s3_name" {
  type        = string
}

// EC2 VARS 

variable "ec2_ssh_key" {
  type        = string
}

variable "codedeploy_bucket"{
    type = string
    description = "s3 codedeploy bucket name for the ec2 instance"
}

variable "dev_account_id"{
    type = string
    description = "dev account id to take ami from"
}