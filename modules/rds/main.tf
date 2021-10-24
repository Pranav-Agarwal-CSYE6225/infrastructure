data "aws_subnet_ids" "subnets" {
  vpc_id = var.vpc_id
}

resource "aws_db_subnet_group" "rds" {
  name       = "rds"
  subnet_ids = data.aws_subnet_ids.subnets.ids
}

resource "aws_db_parameter_group" "rds" {
  name   = "rds"
  family = "mysql8"
}

resource "aws_db_instance" "rds" {
  identifier             = "csye6225"
  instance_class         = "db.t3.micro"
  multi_az = false
  engine                 = "mysql"
  engine_version         = "8.0.25"
  username               = "csye6225"
  password               = "root"
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.rds.name
  publicly_accessible    = false
}