data "aws_subnet_ids" "subnets" {
  vpc_id = var.vpc_id
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "ssh_key"
  public_key = var.ssh_key
}

data "aws_db_instance" "database" {
  db_instance_identifier = var.rds_identifier
}

data "template_file" "config_data" {
  template = <<-EOF
		#! /bin/bash
        cd home/ubuntu
        mkdir server
        cd server
        echo "{\"host\":\"${data.aws_db_instance.database.endpoint}\",\"username\":\"${var.database_username}\",\"password\":\"${var.database_password}\",\"database\":\"${var.rds_identifier}\",\"port\":3306,\"s3\":\"${var.s3_bucket}\"}" > config.json
        cd ..
        sudo chmod -R 777 server
    EOF
}

resource "aws_instance" "webapp" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.s3_profile.name}"
  disable_api_termination = false
  key_name = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [var.security_group_id]
  subnet_id = element(tolist(data.aws_subnet_ids.subnets.ids),0)
  user_data = data.template_file.config_data.rendered
  root_block_device{
    delete_on_termination = true
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "Webapp"
  }
}

resource "aws_iam_role" "ec2_s3_access_role" {
  name               = "S3EC2ServiceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "image_policy" {
    name = "s3-image-policy"
    description = "policy to access S3 bucket to store images"
    policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sts:AssumeRole",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${var.s3_bucket}",
                "arn:aws:s3:::${var.s3_bucket}/*"
            ]
        }
    ]
    }
    EOF

}

resource "aws_iam_policy" "codedeploy_policy" {
    name = "CodeDeploy-EC2-S3"
    description = "policy to access S3 bucket to store codedeploy artifacts"
    policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${var.codedeploy_bucket}",
                "arn:aws:s3:::${var.codedeploy_bucket}/*"
            ]
        }
    ]
    }
    EOF

}

resource "aws_iam_role_policy_attachment" "attach_image" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.image_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_codedeploy" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.codedeploy_policy.arn
}

resource "aws_iam_instance_profile" "s3_profile" {                             
    name  = "s3_profile"                         
    role = aws_iam_role.ec2_s3_access_role.name
}

data "aws_route53_zone" "selected" {
  name         = "${var.environment}.${var.domain}"
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.environment}.${var.domain}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.webapp.public_ip]
}