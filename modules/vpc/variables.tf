variable "cidr_block" {
  type        = string
  description = "CIDR for VPC"
}

variable "name" {
  type        = string
  description = "name for VPC"
}

variable "subnet_map" {
  type        = map(string)
  description = "mapping of subnet AZ to CIDR block"
}