# Infrastructure
Contains Terraform infrastructure code for provisioning and managing network resources

## Setup Instructions
1. clone the repository
2. run terraform init
3. create a .tfvars file with the following properties - 
    aws_profile                        = "prod"
    aws_region                         = "us-east-1"
    vpc_name                           = "vpc-1"
    vpc_cidr_block                     = "10.0.0.0/16"
    vpc_enable_dns_hostnames           = true
    vpc_enable_classiclink_dns_support = true
    vpc_subnet_map = {
        "us-east-1a" : "10.0.1.0/24"
        "us-east-1b" : "10.0.2.0/24"
        "us-east-1c" : "10.0.3.0/24"
    }
4. adjust the tfvars as needed
5. run terraform plan/apply/destroy supplying the .tfvars file
   eg :- terraform plan -var-file="dev.tfvars"
