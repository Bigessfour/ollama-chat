variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_observability" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "alarm_notification_email" {
  type        = string
  description = "Optional email for SNS alarm notifications."
  default     = ""
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix for ApplicationELB metrics."
}

variable "flask_target_group_arn_suffix" {
  type = string
}

variable "react_target_group_arn_suffix" {
  type = string
}

variable "flask_asg_name" {
  type = string
}

variable "react_asg_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
