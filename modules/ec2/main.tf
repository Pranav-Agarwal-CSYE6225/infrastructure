data "aws_subnet_ids" "subnets" {
  vpc_id = var.vpc_id
}

resource "aws_instance" "webapp" {
  ami           = "ami-04a677f17a209bfbe"
  instance_type = "t2.micro"
  disable_api_termination = false
  vpc_security_group_ids = [var.security_group_id]
  subnet_id = element(tolist(data.aws_subnet_ids.subnets.ids),0)

  root_block_device{
    delete_on_termination = true
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "Webapp"
  }
}