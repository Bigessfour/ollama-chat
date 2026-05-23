output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "flask_target_group_arn" {
  value = aws_lb_target_group.flask.arn
}

output "react_target_group_arn" {
  value = aws_lb_target_group.react.arn
}

output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "flask_target_group_arn_suffix" {
  value = aws_lb_target_group.flask.arn_suffix
}

output "react_target_group_arn_suffix" {
  value = aws_lb_target_group.react.arn_suffix
}
