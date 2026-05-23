locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }, var.additional_tags)

  user_data_path = "${path.module}/../../../user-data"
  cors_origins   = "http://${module.alb.alb_dns_name}"

  # file() + replace() avoids templatefile interpreting bash ${TOKEN:-} etc.
  flask_user_data_script = replace(
    replace(
      replace(
        file("${local.user_data_path}/flask.sh"),
        "$${ghcr_username}", var.ghcr_username
      ),
      "$${cors_origins}", local.cors_origins
    ),
    "$${backend_image}", var.backend_image
  )
  react_user_data_script = replace(
    replace(
      file("${local.user_data_path}/react.sh"),
      "$${ghcr_username}", var.ghcr_username
    ),
    "$${frontend_image}", var.frontend_image
  )
}

module "networking" {
  source = "../../modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway         = var.single_nat_gateway
  enable_ssh_between_tiers   = var.enable_ssh_between_tiers
  tags                       = local.common_tags
}

module "security" {
  source = "../../modules/security"

  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.networking.vpc_id
  enable_ssh_between_tiers = var.enable_ssh_between_tiers
  tags                     = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  ghcr_pat                = var.ghcr_pat
  api_key                 = var.api_key
  enable_cloudwatch_agent = var.enable_observability
  tags                    = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id   = module.security.alb_sg_id
  flask_health_check_path = var.flask_health_check_path
  tags                  = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  project_name                    = var.project_name
  environment                     = var.environment
  private_subnet_ids              = module.networking.private_subnet_ids
  flask_security_group_id         = module.security.flask_sg_id
  react_security_group_id         = module.security.react_sg_id
  flask_instance_profile_name     = module.iam.flask_instance_profile_name
  react_instance_profile_name     = module.iam.react_instance_profile_name
  flask_target_group_arn          = module.alb.flask_target_group_arn
  react_target_group_arn          = module.alb.react_target_group_arn
  flask_user_data                 = base64encode(local.flask_user_data_script)
  react_user_data                 = base64encode(local.react_user_data_script)
  flask_instance_type             = var.flask_instance_type
  react_instance_type             = var.react_instance_type
  flask_asg_min                   = var.flask_asg_min
  flask_asg_desired               = var.flask_asg_desired
  flask_asg_max                   = var.flask_asg_max
  flask_health_check_grace_period = var.flask_health_check_grace_period
  react_asg_min                   = var.react_asg_min
  react_asg_desired               = var.react_asg_desired
  react_asg_max                   = var.react_asg_max
  react_health_check_grace_period = var.react_health_check_grace_period
  tags                            = local.common_tags
}

module "observability" {
  source = "../../modules/observability"

  project_name                  = var.project_name
  environment                   = var.environment
  enable_observability          = var.enable_observability
  log_retention_days            = var.log_retention_days
  alarm_notification_email      = var.alarm_notification_email
  alb_arn_suffix                = module.alb.alb_arn_suffix
  flask_target_group_arn_suffix = module.alb.flask_target_group_arn_suffix
  react_target_group_arn_suffix = module.alb.react_target_group_arn_suffix
  flask_asg_name                = module.compute.flask_asg_name
  react_asg_name                = module.compute.react_asg_name
  tags                          = local.common_tags
}
