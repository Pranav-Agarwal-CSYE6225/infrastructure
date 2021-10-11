provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

module "vpcModule" {
  source         = "./modules/vpc"
  vpc_name       = "vpc1"
  vpc_cidr_block = "10.0.0.0/16"
  subnet_map     = var.subnet_map
}