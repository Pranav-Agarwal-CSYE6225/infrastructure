resource "aws_vpc" "vpc" {
  cidr_block                       = var.vpc_cidr_block
  enable_dns_hostnames             = true
  enable_dns_support               = true
  enable_classiclink_dns_support   = true
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "subnet" {

  depends_on = [aws_vpc.vpc]

  for_each = var.subnet_map

  cidr_block              = each.value
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags = {
    Name = "csye6225-subnet-${each.key}" 
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main"
  }
}

//Create route table
resource "aws_route_table" "main-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

}

//Attach route table to all the subnets
resource "aws_route_table_association" "a" {
  for_each = aws_subnet.subnet
  subnet_id = each.value.id
  route_table_id = aws_route_table.main-route-table.id
}