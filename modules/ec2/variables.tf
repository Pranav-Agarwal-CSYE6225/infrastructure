variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "security_group_id" {
    type = string
    description = "security group for ec2 instance"
}