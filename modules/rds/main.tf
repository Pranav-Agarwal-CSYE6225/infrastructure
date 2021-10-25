data "aws_subnet_ids" "subnets" {
  vpc_id = var.vpc_id
}

resource "aws_db_subnet_group" "rds" {
  name       = "rds"
  subnet_ids = data.aws_subnet_ids.subnets.ids
}

resource "aws_db_parameter_group" "rds" {
  name   = "rds"
  family = "mysql8.0"
}

resource "aws_db_instance" "rds" {
  identifier             = var.rds_identifier
  instance_class         = "db.t3.micro"
  skip_final_snapshot = true
  allocated_storage = 20
  max_allocated_storage = 0
  multi_az = false
  engine                 = "mysql"
  engine_version         = "8.0.25"
  username               = var.username
  password               = var.password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.rds.name
  publicly_accessible    = false
}