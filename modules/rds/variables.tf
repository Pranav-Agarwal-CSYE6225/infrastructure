variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "security_group_id" {
  type        = string
  description = "Database security group ID"
}

variable "rds_identifier" {
  type        = string
  description = "Identifier for the RDS instance"
}

variable "username" {
  type        = string
  description = "username for the RDS instance"
}

variable "password" {
  type        = string
  description = "password for the RDS instance"
}