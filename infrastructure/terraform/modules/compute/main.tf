data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  common_tags = merge(var.tags, {
    Module = "compute"
  })

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
}

resource "aws_launch_template" "flask" {
  name_prefix   = "${var.project_name}-flask-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.flask_instance_type

  iam_instance_profile {
    name = var.flask_instance_profile_name
  }

  vpc_security_group_ids = [var.flask_security_group_id]

  metadata_options {
    http_endpoint               = local.metadata_options.http_endpoint
    http_tokens                 = local.metadata_options.http_tokens
    http_put_response_hop_limit = local.metadata_options.http_put_response_hop_limit
    instance_metadata_tags      = local.metadata_options.instance_metadata_tags
  }

  user_data = var.flask_user_data

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-flask"
      Tier = "backend"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "react" {
  name_prefix   = "${var.project_name}-react-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.react_instance_type

  iam_instance_profile {
    name = var.react_instance_profile_name
  }

  vpc_security_group_ids = [var.react_security_group_id]

  metadata_options {
    http_endpoint               = local.metadata_options.http_endpoint
    http_tokens                 = local.metadata_options.http_tokens
    http_put_response_hop_limit = local.metadata_options.http_put_response_hop_limit
    instance_metadata_tags      = local.metadata_options.instance_metadata_tags
  }

  user_data = var.react_user_data

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-react"
      Tier = "frontend"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "flask" {
  name                = "${var.project_name}-flask-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.flask_target_group_arn]
  health_check_type   = "ELB"
  health_check_grace_period = var.flask_health_check_grace_period

  min_size         = var.flask_asg_min
  max_size         = var.flask_asg_max
  desired_capacity = var.flask_asg_desired

  launch_template {
    id      = aws_launch_template.flask.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-flask-asg"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "react" {
  name                = "${var.project_name}-react-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.react_target_group_arn]
  health_check_type   = "ELB"
  health_check_grace_period = var.react_health_check_grace_period

  min_size         = var.react_asg_min
  max_size         = var.react_asg_max
  desired_capacity = var.react_asg_desired

  launch_template {
    id      = aws_launch_template.react.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-react-asg"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
