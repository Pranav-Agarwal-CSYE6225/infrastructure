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

data "aws_ami" "webapp_ami" {
  owners           = [var.dev_account_id]
  most_recent      = true

  filter {
    name   = "name"
    values = ["Webapp-Ubuntu"]
  }
}

resource "aws_codedeploy_app" "code_deploy_app" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

resource "aws_codedeploy_deployment_group" "code_deploy_deployment_group" {
  app_name               = aws_codedeploy_app.code_deploy_app.name
  deployment_group_name  = "csye6225-webapp-deployment"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  service_role_arn       = aws_iam_role.code_deploy_role.arn
  autoscaling_groups = [aws_autoscaling_group.autoscaling.name]

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "Webapp"
  }

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  depends_on = [aws_codedeploy_app.code_deploy_app]
}


// resource "aws_instance" "webapp" {
//   ami           = var.ami_id
//   instance_type = "t2.micro"
//   iam_instance_profile = aws_iam_instance_profile.s3_profile.name
//   disable_api_termination = false
//   key_name = aws_key_pair.ssh_key.key_name
//   vpc_security_group_ids = [var.security_group_id]
//   subnet_id = element(tolist(data.aws_subnet_ids.subnets.ids),0)
//   user_data = data.template_file.config_data.rendered
//   root_block_device{
//     delete_on_termination = true
//     volume_size = 20
//     volume_type = "gp2"
//   }

//   tags = {
//     Name = "Webapp"
//   }
// }

resource "aws_lb" "application-Load-Balancer" {
  name               = "application-Load-Balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.lb_security_group_id]
  subnets            = data.aws_subnet_ids.subnets.ids
  ip_address_type    = "ipv4"
  tags = {
    Name        = "applicationLoadBalancer"
  }
}

resource "aws_launch_configuration" "as_conf" {
  name                   = "asg_launch_config"
  image_id               = data.aws_ami.webapp_ami.id
  instance_type          = "t2.micro"
  security_groups        = [var.security_group_id]
  key_name               = aws_key_pair.ssh_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.s3_profile.name
  associate_public_ip_address = true
  user_data = data.template_file.config_data.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }
}

resource "aws_autoscaling_group" "autoscaling" {
  name                 = "autoscaling-group"
  launch_configuration = aws_launch_configuration.as_conf.name
  min_size             = 3
  max_size             = 5
  default_cooldown     = 60
  desired_capacity     = 3
  vpc_zone_identifier = data.aws_subnet_ids.subnets.ids
  target_group_arns =  [aws_lb_target_group.albTargetGroup.arn]
  tag {
    key                 = "Name"
    value               = "Webapp"
    propagate_at_launch = true
  }
}

resource "aws_lb_target_group" "albTargetGroup" {
  name     = "albTargetGroup"
  port     = "5000"
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  tags = {
    name = "albTargetGroup"
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    path                = "/"
    port                = "5000"
    matcher             = "200"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.application-Load-Balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.albTargetGroup.arn
  }
}

resource "aws_autoscaling_policy" "WebServerScaleUpPolicy" {
  name                   = "WebServerScaleUpPolicy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.autoscaling.name
  cooldown               = 60
  scaling_adjustment     = 1
}

resource "aws_autoscaling_policy" "WebServerScaleDownPolicy" {
  name                   = "WebServerScaleDownPolicy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.autoscaling.name
  cooldown               = 60
  scaling_adjustment     = -1
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmLow" {
  alarm_description = "Scale-down if CPU < 3% for 10 minutes"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  period              = "60"
  evaluation_periods  = "1"
  threshold           = "3"
  alarm_name          = "CPUAlarmLow"
  alarm_actions     = [aws_autoscaling_policy.WebServerScaleDownPolicy.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling.name
  }
  comparison_operator = "LessThanThreshold"
 
  
}

resource "aws_cloudwatch_metric_alarm" "CPUAlarmHigh" {
  alarm_description = "Scale-up if CPU > 5% for 10 minutes"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  period              = "60"
  evaluation_periods  = "1"
  threshold           = "5"
  alarm_name          = "CPUAlarmHigh"
  alarm_actions     = [aws_autoscaling_policy.WebServerScaleUpPolicy.arn]
  dimensions = {
  AutoScalingGroupName = aws_autoscaling_group.autoscaling.name
  }
  comparison_operator = "GreaterThanThreshold"
}

resource "aws_iam_role" "code_deploy_role" {
  name = "CodeDeployServiceRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.code_deploy_role.name
}

resource "aws_iam_role" "ec2_s3_access_role" {
  name               = "EC2ServiceRole"
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

resource "aws_iam_policy" "cloudwatch_policy" {
    name = "CloudWatchAgentServerPolicy"
    description = "policy to use cloudwatch"
    policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "cloudwatch:PutMetricData",
                    "ec2:DescribeVolumes",
                    "ec2:DescribeTags",
                    "logs:PutLogEvents",
                    "logs:DescribeLogStreams",
                    "logs:DescribeLogGroups",
                    "logs:CreateLogStream",
                    "logs:CreateLogGroup"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ssm:GetParameter"
                ],
                "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
            }
        ]
    }
    EOF

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

resource "aws_iam_role_policy_attachment" "attach_cloudwatch" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

resource "aws_iam_instance_profile" "s3_profile" {                             
    name  = "s3_profile"                         
    role = aws_iam_role.ec2_s3_access_role.name
}

data "aws_route53_zone" "selected" {
  name         = "${var.environment}.${var.domain}"
}

// resource "aws_route53_record" "www" {
//   zone_id = data.aws_route53_zone.selected.zone_id
//   name    = "${var.environment}.${var.domain}"
//   type    = "A"
//   ttl     = "300"
//   records = [aws_instance.webapp.public_ip]
// }

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.environment}.${var.domain}"
  type    = "A"

  alias {
    name    = aws_lb.application-Load-Balancer.dns_name
    zone_id = aws_lb.application-Load-Balancer.zone_id
    evaluate_target_health = true
  }
}