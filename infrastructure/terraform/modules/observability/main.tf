locals {
  common_tags = merge(var.tags, {
    Module = "observability"
  })

  alarm_actions = var.enable_observability ? [aws_sns_topic.alarms[0].arn] : []
}

resource "aws_sns_topic" "alarms" {
  count = var.enable_observability ? 1 : 0

  name = "${var.project_name}-alarms"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alarms"
  })
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.enable_observability && var.alarm_notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

resource "aws_cloudwatch_log_group" "flask_bootstrap" {
  count = var.enable_observability ? 1 : 0

  name              = "/ollama-chat/flask/bootstrap"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Name = "/ollama-chat/flask/bootstrap" })
}

resource "aws_cloudwatch_log_group" "flask_app" {
  count = var.enable_observability ? 1 : 0

  name              = "/ollama-chat/flask/app"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Name = "/ollama-chat/flask/app" })
}

resource "aws_cloudwatch_log_group" "flask_ollama_pull" {
  count = var.enable_observability ? 1 : 0

  name              = "/ollama-chat/flask/ollama-pull"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Name = "/ollama-chat/flask/ollama-pull" })
}

resource "aws_cloudwatch_log_group" "react_bootstrap" {
  count = var.enable_observability ? 1 : 0

  name              = "/ollama-chat/react/bootstrap"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Name = "/ollama-chat/react/bootstrap" })
}

resource "aws_cloudwatch_log_group" "react_app" {
  count = var.enable_observability ? 1 : 0

  name              = "/ollama-chat/react/app"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Name = "/ollama-chat/react/app" })
}

resource "aws_cloudwatch_metric_alarm" "flask_unhealthy_hosts" {
  count = var.enable_observability ? 1 : 0

  alarm_name          = "${var.project_name}-flask-unhealthy-hosts"
  alarm_description   = "Flask target group has unhealthy hosts."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.flask_target_group_arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "react_unhealthy_hosts" {
  count = var.enable_observability ? 1 : 0

  alarm_name          = "${var.project_name}-react-unhealthy-hosts"
  alarm_description   = "React target group has unhealthy hosts."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.react_target_group_arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "flask_no_healthy_hosts" {
  count = var.enable_observability ? 1 : 0

  alarm_name          = "${var.project_name}-flask-no-healthy-hosts"
  alarm_description   = "No healthy Flask targets behind the ALB."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.flask_target_group_arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "flask_target_5xx" {
  count = var.enable_observability ? 1 : 0

  alarm_name          = "${var.project_name}-flask-target-5xx"
  alarm_description   = "Elevated HTTP 5xx responses from Flask targets."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.flask_target_group_arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "flask_asg_capacity" {
  count = var.enable_observability ? 1 : 0

  alarm_name          = "${var.project_name}-flask-asg-under-capacity"
  alarm_description   = "Flask ASG in-service instances below desired capacity."
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 2
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions

  metric_query {
    id          = "capacity_gap"
    expression  = "m1 - m2"
    label       = "DesiredMinusInService"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "GroupDesiredCapacity"
      namespace   = "AWS/AutoScaling"
      period      = 300
      stat        = "Minimum"
      dimensions = {
        AutoScalingGroupName = var.flask_asg_name
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "GroupInServiceInstances"
      namespace   = "AWS/AutoScaling"
      period      = 300
      stat        = "Minimum"
      dimensions = {
        AutoScalingGroupName = var.flask_asg_name
      }
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "flask_cpu_high" {
  count = var.enable_observability ? 1 : 0

  alarm_name          = "${var.project_name}-flask-cpu-high"
  alarm_description   = "Flask ASG average CPU utilization above 80%."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions

  dimensions = {
    AutoScalingGroupName = var.flask_asg_name
  }

  tags = local.common_tags
}
