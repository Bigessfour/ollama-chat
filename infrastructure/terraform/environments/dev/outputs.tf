output "alb_dns_name" {
  description = "ALB DNS hostname (use for ALB_DNS / VITE_API_URL)."
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "Base URL for the application."
  value       = "http://${module.alb.alb_dns_name}"
}

output "api_health_url" {
  value = "http://${module.alb.alb_dns_name}/api/health"
}

output "api_live_url" {
  value = "http://${module.alb.alb_dns_name}/live"
}

output "api_ready_url" {
  value = "http://${module.alb.alb_dns_name}/api/ready"
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "flask_target_group_arn" {
  value = module.alb.flask_target_group_arn
}

output "react_target_group_arn" {
  value = module.alb.react_target_group_arn
}

output "flask_asg_name" {
  value = module.compute.flask_asg_name
}

output "react_asg_name" {
  value = module.compute.react_asg_name
}

output "ssm_parameter_name" {
  value = module.iam.ssm_parameter_name
}

output "alarm_sns_topic_arn" {
  value = module.observability.sns_topic_arn
}

output "cloudwatch_log_groups" {
  value = module.observability.log_group_names
}

output "post_apply_commands" {
  description = "Suggested commands after terraform apply."
  value       = <<-EOT
    export GHCR_PAT=<your_pat>
    ./infrastructure/push-backend.sh
    export ALB_DNS=$(terraform output -raw alb_dns_name)
    ./infrastructure/push-frontend.sh
    curl http://${module.alb.alb_dns_name}/api/ready
  EOT
}
