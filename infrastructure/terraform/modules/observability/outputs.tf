output "sns_topic_arn" {
  value = var.enable_observability ? aws_sns_topic.alarms[0].arn : null
}

output "log_group_names" {
  value = var.enable_observability ? [
    aws_cloudwatch_log_group.flask_bootstrap[0].name,
    aws_cloudwatch_log_group.flask_app[0].name,
    aws_cloudwatch_log_group.flask_ollama_pull[0].name,
    aws_cloudwatch_log_group.react_bootstrap[0].name,
    aws_cloudwatch_log_group.react_app[0].name,
  ] : []
}
