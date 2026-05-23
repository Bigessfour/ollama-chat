output "flask_instance_profile_name" {
  value = aws_iam_instance_profile.flask.name
}

output "react_instance_profile_name" {
  value = aws_iam_instance_profile.react.name
}

output "flask_instance_profile_arn" {
  value = aws_iam_instance_profile.flask.arn
}

output "react_instance_profile_arn" {
  value = aws_iam_instance_profile.react.arn
}

output "flask_role_name" {
  value = aws_iam_role.flask_ec2.name
}

output "react_role_name" {
  value = aws_iam_role.react_ec2.name
}

output "ssm_parameter_name" {
  value = aws_ssm_parameter.ghcr_pat.name
}

output "api_key_ssm_parameter_name" {
  value = var.api_key != "" ? aws_ssm_parameter.api_key[0].name : null
}

# Backward-compatible aliases
output "instance_profile_name" {
  value = aws_iam_instance_profile.flask.name
}

output "instance_profile_arn" {
  value = aws_iam_instance_profile.flask.arn
}

output "role_name" {
  value = aws_iam_role.flask_ec2.name
}
