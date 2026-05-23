data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(var.tags, {
    Module = "iam"
  })

  pat_parameter_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_name}"
  api_key_parameter_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.api_key_ssm_parameter_name}"
}

resource "aws_iam_role" "flask_ec2" {
  name = "${var.project_name}-flask-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-flask-ec2-role"
    Tier = "backend"
  })
}

resource "aws_iam_role" "react_ec2" {
  name = "${var.project_name}-react-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-react-ec2-role"
    Tier = "frontend"
  })
}

resource "aws_iam_role_policy_attachment" "flask_ssm_core" {
  role       = aws_iam_role.flask_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "react_ssm_core" {
  role       = aws_iam_role.react_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "flask_cloudwatch_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  role       = aws_iam_role.flask_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "react_cloudwatch_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  role       = aws_iam_role.react_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "flask_cloudwatch_logs" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name = "flask-cloudwatch-logs"
  role = aws_iam_role.flask_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ollama-chat/flask/*",
        "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ollama-chat/flask/*:*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "react_cloudwatch_logs" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name = "react-cloudwatch-logs"
  role = aws_iam_role.react_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ollama-chat/react/*",
        "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ollama-chat/react/*:*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "flask_secrets_read" {
  name = "flask-secrets-read"
  role = aws_iam_role.flask_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = local.pat_parameter_arn
      }],
      var.api_key != "" ? [{
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = local.api_key_parameter_arn
      }] : []
    )
  })
}

resource "aws_iam_role_policy" "react_ghcr_pat_read" {
  name = "react-ghcr-pat-read"
  role = aws_iam_role.react_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = local.pat_parameter_arn
    }]
  })
}

resource "aws_iam_instance_profile" "flask" {
  name = "${var.project_name}-flask-ec2-profile"
  role = aws_iam_role.flask_ec2.name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-flask-ec2-profile"
  })
}

resource "aws_iam_instance_profile" "react" {
  name = "${var.project_name}-react-ec2-profile"
  role = aws_iam_role.react_ec2.name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-react-ec2-profile"
  })
}

resource "aws_ssm_parameter" "ghcr_pat" {
  name  = var.ssm_parameter_name
  type  = "SecureString"
  value = var.ghcr_pat

  tags = merge(local.common_tags, {
    Name = var.ssm_parameter_name
  })

  lifecycle {
    # Rotate PAT via AWS Console/CLI, or: terraform apply -replace=module.iam.aws_ssm_parameter.ghcr_pat
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "api_key" {
  count = var.api_key != "" ? 1 : 0

  name  = var.api_key_ssm_parameter_name
  type  = "SecureString"
  value = var.api_key

  tags = merge(local.common_tags, {
    Name = var.api_key_ssm_parameter_name
  })

  lifecycle {
    ignore_changes = [value]
  }
}
