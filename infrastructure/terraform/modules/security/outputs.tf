output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "react_sg_id" {
  value = aws_security_group.react.id
}

output "flask_sg_id" {
  value = aws_security_group.flask.id
}
