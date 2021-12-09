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

data "aws_db_instance" "database_replica" {
  db_instance_identifier = var.rds_identifier_replica
}

resource "aws_sns_topic" "EmailNotificationRecipeEndpoint" {
  name          = "EmailNotificationRecipeEndpoint"
}


data "template_file" "config_data" {
  template = <<-EOF
		#! /bin/bash
        cd home/ubuntu
        mkdir server
        cd server
        echo "{\"host\":\"${data.aws_db_instance.database.endpoint}\",\"hostRdsReadReplica\":\"${data.aws_db_instance.database_replica.endpoint}\",\"username\":\"${var.database_username}\",\"password\":\"${var.database_password}\",\"database\":\"${var.rds_identifier}\",\"port\":3306,\"s3\":\"${var.s3_bucket}\",\"topic_arn\":\"${aws_sns_topic.EmailNotificationRecipeEndpoint.arn}\"}" > config.json
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

resource "aws_lb" "application-Load-Balancer" {
  name               = "load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.lb_security_group_id]
  subnets            = data.aws_subnet_ids.subnets.ids
  ip_address_type    = "ipv4"
  tags = {
    Name        = "applicationLoadBalancer"
  }
}

resource "aws_kms_key" "ebs_key" {
  description              = "EBS-key"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Id": "key-default-1",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${var.prod_account_id}:root",
                    "arn:aws:iam::${var.prod_account_id}:user/dev"
                ]
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow service-linked role use of the customer managed key",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.prod_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
            },
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow attachment of persistent resources",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.prod_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
            },
            "Action": "kms:CreateGrant",
            "Resource": "*",
            "Condition": {
                "Bool": {
                    "kms:GrantIsForAWSResource": "true"
                }
            }
        }
    ]
}
EOF
}

// resource "aws_launch_configuration" "as_conf" {
//   name                   = "asg_launch_config"
//   image_id               = data.aws_ami.webapp_ami.id
//   instance_type          = "t2.micro"
//   security_groups        = [var.security_group_id]
//   key_name               = aws_key_pair.ssh_key.key_name
//   iam_instance_profile        = aws_iam_instance_profile.s3_profile.name
//   associate_public_ip_address = true
//   user_data = data.template_file.config_data.rendered

//   root_block_device {
//     volume_type           = "gp2"
//     volume_size           = 20
//     delete_on_termination = true
//     encrypted             = true
//     kms_key_id            = aws_kms_key.ebs_key.key_id
//   }
// }

resource "aws_launch_template" "as_temp" {
  name                                 = "as_temp"
  image_id                             = data.aws_ami.webapp_ami.id
  instance_type                        = "t2.micro"
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile {
    arn = aws_iam_instance_profile.s3_profile.arn
  }
  key_name                             = aws_key_pair.ssh_key.key_name
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp2"
      volume_size = 20
      delete_on_termination = true
      encrypted = true
      kms_key_id = aws_kms_key.ebs_key.arn
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name          = "Webapp"
    }
  }
  user_data = base64encode(data.template_file.config_data.rendered)
}

resource "aws_autoscaling_group" "autoscaling" {
  name                 = "autoscaling-group"
  launch_template {
    id      = aws_launch_template.as_temp.id
    version = aws_launch_template.as_temp.latest_version
  }
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

data "aws_acm_certificate" "sectigo_issued" {
  domain      = "${var.environment}.${var.domain}"
  statuses = ["ISSUED"]
  types       = ["IMPORTED"]
  most_recent = true
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.application-Load-Balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn = data.aws_acm_certificate.sectigo_issued.arn

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

resource "aws_dynamodb_table" "dynamoDbTable" {
    provider = aws
    name = "csye6225-dynamo"
    hash_key = "UserName"
    range_key      = "token"

    read_capacity = 5
    write_capacity = 5

     attribute {
         name = "UserName"
         type = "S"
     }
     attribute {
          name = "token"
          type = "S"
    }

     ttl {
       attribute_name = "TimeToExist"
       enabled = true
     }
}

resource "aws_codedeploy_app" "csye6225-lambda" {
  compute_platform = "Lambda"
  name             = "csye6225-lambda"
}

resource "aws_codedeploy_deployment_config" "lambda_deployment_config" {
  deployment_config_name = "lambda_deployment_config"
  compute_platform       = "Lambda"

  traffic_routing_config {
    type = "TimeBasedLinear"

    time_based_linear {
      interval   = 10
      percentage = 10
    }
  }
}

resource "aws_codedeploy_deployment_group" "csye6225-lambda-deployment" {
  app_name              = aws_codedeploy_app.csye6225-lambda.name
  deployment_group_name = "csye6225-lambda-deployment"
  service_role_arn      = aws_iam_role.CodeDeployLambdaServiceRole.arn
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
  deployment_config_name = aws_codedeploy_deployment_config.lambda_deployment_config.id
 auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

}

data "archive_file" "lambda_zip" {
  type = "zip"
  source_file = "index.js"
  output_path = "lambda_function.zip"
}

resource "aws_s3_bucket_object" "object" {
  bucket = var.codedeploy_bucket
  key    = "lambda_function.zip"
  source = "./lambda_function.zip"
}

resource "aws_lambda_function" "lambdaFunction" {
  s3_bucket = var.codedeploy_bucket
  s3_key    = "lambda_function.zip"
  function_name    = "email_function"
  role             = aws_iam_role.CodeDeployLambdaServiceRole.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  environment {
    variables = {
      timeToLive = "5"
    }
  }
}

resource "aws_sns_topic_subscription" "topicId" {
  topic_arn       = aws_sns_topic.EmailNotificationRecipeEndpoint.arn
  protocol        = "lambda"
  endpoint        = aws_lambda_function.lambdaFunction.arn
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.EmailNotificationRecipeEndpoint.arn
  function_name = aws_lambda_function.lambdaFunction.function_name
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

resource "aws_iam_role" "CodeDeployLambdaServiceRole" {
  name           = "iam_for_lambda_with_sns"
  path           = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com","codedeploy.us-east-1.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
    Name = "CodeDeployLambdaServiceRole"
  }
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

resource "aws_iam_policy" "lambda_policy" {
name        = "lambda"
policy =  <<EOF
{
          "Version" : "2012-10-17",
          "Statement": [
            {
              "Sid": "LambdaDynamoDBAccess",
              "Effect": "Allow",
              "Action": ["dynamodb:GetItem",
              "dynamodb:PutItem",
              "dynamodb:UpdateItem"],
              "Resource": "arn:aws:dynamodb:us-east-1:***************:table/csye6225-dynamo"
            },
            {
              "Sid": "LambdaSESAccess",
              "Effect": "Allow",
              "Action": ["ses:VerifyEmailAddress",
              "ses:SendEmail",
              "ses:SendRawEmail"],
              "Resource": "arn:aws:ses:us-east-1:***************:identity/*"
            },
            {
              "Sid": "LambdaS3Access",
              "Effect": "Allow",
              "Action": ["s3:GetObject","s3:PutObject"],
              "Resource": "arn:aws:s3:::lambda.codedeploy.bucket/*"
            },
            {
              "Sid": "LambdaSNSAccess",
              "Effect": "Allow",
              "Action": ["sns:ConfirmSubscription"],
              "Resource": "${aws_sns_topic.EmailNotificationRecipeEndpoint.arn}"
            }
          ]
        }
EOF
}

resource "aws_iam_policy" "topic_policy" {
name        = "Topic"
description = ""
depends_on  = [aws_sns_topic.EmailNotificationRecipeEndpoint]
policy      = <<EOF
{
          "Version" : "2012-10-17",
          "Statement": [
            {
              "Sid": "AllowEC2ToPublishToSNSTopic",
              "Effect": "Allow",
              "Action": ["sns:Publish",
              "sns:CreateTopic"],
              "Resource": "${aws_sns_topic.EmailNotificationRecipeEndpoint.arn}"
            }
          ]
        }
EOF
}

resource "aws_iam_role_policy_attachment" "topic_policy_attach" {
  role       = "${aws_iam_role.ec2_s3_access_role.name}"
  policy_arn = "${aws_iam_policy.topic_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "sns_policy_attach" {
  role       = "${aws_iam_role.ec2_s3_access_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"

}


resource "aws_iam_policy" "lambdaS3" {
name        = "lambdaS3"
description = "A Upload policy"
policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ActionsWhichSupportResourceLevelPermissions",
            "Effect": "Allow",
            "Action": [
                "lambda:AddPermission",
                "lambda:RemovePermission",
                "lambda:CreateAlias",
                "lambda:UpdateAlias",
                "lambda:DeleteAlias",
                "lambda:UpdateFunctionCode",
                "lambda:UpdateFunctionConfiguration",
                "lambda:PutFunctionConcurrency",
                "lambda:DeleteFunctionConcurrency",
                "lambda:PublishVersion"
            ],
            "Resource": "arn:aws:lambda:us-east-1:***************:function:email_function"
        }
]
}
EOF
}

resource "aws_iam_policy_attachment" "githubActions-LambdaS3-policy-attach" {
name       = "lambdaS3-policy"
users      = ["ghactions-app"]
policy_arn = "${aws_iam_policy.lambdaS3.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach_predefinedrole" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach_role" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "${aws_iam_policy.lambda_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "topic_policy_attach_role" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "${aws_iam_policy.topic_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "dynamoDB_policy_attach_role" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "ses_policy_attach_role" {
role       = "${aws_iam_role.CodeDeployLambdaServiceRole.name}"
depends_on = [aws_iam_role.CodeDeployLambdaServiceRole]
policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

resource "aws_iam_policy" "dynamoDbEc2Policy"{
  name = "DynamoDb-Ec2"
  description = "ec2 will be able to talk to dynamodb"
  policy = <<-EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [      
              "dynamodb:List*",
              "dynamodb:DescribeReservedCapacity*",
              "dynamodb:DescribeLimits",
              "dynamodb:DescribeTimeToLive"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:CreateTable",
                "dynamodb:Delete*",
                "dynamodb:Update*",
                "dynamodb:PutItem",
                "dynamodb:GetItem"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/csye6225-dynamo"
        }
    ]
    }
    EOF
  }

resource "aws_iam_role_policy_attachment" "attachDynamoDbPolicyToRole" {
  role       = aws_iam_role.ec2_s3_access_role.name
  policy_arn = aws_iam_policy.dynamoDbEc2Policy.arn
}
