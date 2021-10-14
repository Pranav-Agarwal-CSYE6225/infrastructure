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

variable "enable_classiclink_dns_support" {
  type        = bool
  description = "A boolean flag to enable/disable ClassicLink DNS Support for the VPC"
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "A boolean flag to enable/disable DNS hostnames in the VPC"
}