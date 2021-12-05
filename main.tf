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

module "rdsModule" {
  source                         = "./modules/rds"
  vpc_id = module.vpcModule.vpc_id
  security_group_id = module.vpcModule.database_securitygroup_id
  rds_identifier = var.rds_identifier
  rds_identifier_replica = var.rds_identifier_replica
  username = var.rds_username
  password = var.rds_password
  depends_on = [
    module.vpcModule
  ]
}

module "s3Module" {
  source = "./modules/s3"
  environment = var.aws_profile
  domain = var.s3_domain
  name = var.s3_name
}

module "ec2Module" {
  source                         = "./modules/ec2"
  vpc_id = module.vpcModule.vpc_id
  security_group_id = module.vpcModule.application_securitygroup_id
  lb_security_group_id = module.vpcModule.lb_securitygroup_id
  s3_bucket = module.s3Module.s3_bucket
  codedeploy_bucket = var.codedeploy_bucket
  rds_identifier = var.rds_identifier
  rds_identifier_replica = var.rds_identifier_replica
  database_username = var.rds_username
  database_password = var.rds_password
  environment = var.aws_profile
  domain = var.s3_domain
  ssh_key = var.ec2_ssh_key
  dev_account_id = var.dev_account_id
    depends_on = [
      module.vpcModule,
      module.s3Module,
      module.rdsModule
  ]
}

