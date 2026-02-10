#✓health checks
#✓logs
#✓alertas simples (email o webhook)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

resource "aws_sns_topic" "cpu_alarm" {
  name = "cpu-sns-topic"
}

resource "aws_sns_topic_subscription" "cpu_alarm_target" {
  topic_arn = aws_sns_topic.cpu_alarm.arn
  protocol  = "email"
  endpoint  = var.email
}

resource "aws_sns_topic" "db_script_alarm" {
  name = "db-script-sns-topic"
}


resource "aws_sns_topic_subscription" "db_script_alarm_target" {
  topic_arn = aws_sns_topic.db_script_alarm.arn
  protocol  = "email"
  endpoint  = var.email
}

data "aws_iam_policy_document" "ec2_publish_sns" {
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      aws_sns_topic.db_script_alarm.arn
    ]
  }
}

resource "aws_iam_policy" "ec2_publish_sns" {
  name   = "ec2-publish-sns"
  policy = data.aws_iam_policy_document.ec2_publish_sns.json
}

resource "aws_iam_role_policy_attachment" "attach_ec2_publish_sns" {
  role       = var.ec2_role_name
  policy_arn = aws_iam_policy.ec2_publish_sns.arn
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent" {
  role       = var.ec2_role_name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_cloudwatch_log_group" "docker" {
  name              = "/ec2/docker"
  retention_in_days = 14
}

resource "aws_cloudwatch_metric_alarm" "foobar" {
  alarm_name                = "terraform-CPU-USAGE"
  alarm_description         = "This metric monitors ec2 cpu utilization"

  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  statistic                 = "Average"

  period                    = 120
  evaluation_periods        = 2
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = 80

  dimensions = {
    InstanceId = var.instance_id
  }

  
  insufficient_data_actions = []

  alarm_actions = [aws_sns_topic.cpu_alarm.arn]

}