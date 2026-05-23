output "flask_launch_template_id" {
  value = aws_launch_template.flask.id
}

output "react_launch_template_id" {
  value = aws_launch_template.react.id
}

output "flask_asg_name" {
  value = aws_autoscaling_group.flask.name
}

output "react_asg_name" {
  value = aws_autoscaling_group.react.name
}
