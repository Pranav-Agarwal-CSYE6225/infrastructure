variable "aws_profile" {
  type        = string
  description = "AWS account profile to create resources in"
}

variable "aws_region" {
  type        = string
  description = "AWS region to create resources in"
}

variable "subnet_map" {
  type        = map(string)
  description = "mapping of subnet AZ to CIDR block"
}