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
    rds_identifier = "csye6225"
    rds_identifier_replica = "csye6225-replica"
    rds_username = "csye6225"
    rds_password = "RandomString123#"
    s3_domain = "******"
    s3_name = "*******"
    ec2_ssh_key = "*****"
    codedeploy_bucket = "******"
    dev_account_id = "***********"
    prod_account_id = "**********"
4.  import your SSL certificate into ACM using the command - 
        aws acm import-certificate 
            --certificate fileb://certName.crt 
            --certificate-chain fileb://certChain.ca-bundle 
            --private-key fileb://privateKeyFile.key
5. adjust the tfvars as needed
6. run terraform plan/apply/destroy supplying the .tfvars file
   eg :- terraform plan -var-file="[FILE NAME].tfvars"
