provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

module "vpcModule" {
  source                         = "./modules/vpc"
  name                           = var.vpc_name
  cidr_block                     = var.vpc_cidr_block
  subnet_map                     = var.vpc_subnet_map
  enable_dns_hostnames           = var.vpc_enable_dns_hostnames
  enable_classiclink_dns_support = var.vpc_enable_classiclink_dns_support
}