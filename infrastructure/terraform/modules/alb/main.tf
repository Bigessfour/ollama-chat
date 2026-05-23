locals {
  common_tags = merge(var.tags, {
    Module = "alb"
  })
}

resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb"
  })
}

resource "aws_lb_target_group" "flask" {
  name     = "${var.project_name}-flask-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = var.flask_health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-flask-tg"
  })
}

resource "aws_lb_target_group" "react" {
  name     = "${var.project_name}-react-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = var.react_health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-react-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.react.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
