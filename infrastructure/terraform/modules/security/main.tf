locals {
  common_tags = merge(var.tags, {
    Module = "security"
  })
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB for ${var.project_name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

resource "aws_security_group" "react" {
  name        = "${var.project_name}-react-sg"
  description = "React nginx for ${var.project_name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-react-sg"
  })
}

resource "aws_security_group" "flask" {
  name        = "${var.project_name}-flask-sg"
  description = "Flask backend for ${var.project_name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Gunicorn from ALB only (no direct internet access to Flask)"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  dynamic "ingress" {
    for_each = var.enable_ssh_between_tiers ? [1] : []
    content {
      description     = "SSH from React tier"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [aws_security_group.react.id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-flask-sg"
  })
}
