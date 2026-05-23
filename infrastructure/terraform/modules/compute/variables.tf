variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "flask_security_group_id" {
  type = string
}

variable "react_security_group_id" {
  type = string
}

variable "flask_instance_profile_name" {
  type        = string
  description = "IAM instance profile for Flask/Ollama tier."
}

variable "react_instance_profile_name" {
  type        = string
  description = "IAM instance profile for React/nginx tier."
}

variable "flask_target_group_arn" {
  type = string
}

variable "react_target_group_arn" {
  type = string
}

variable "flask_user_data" {
  type        = string
  description = "Base64-encoded user data for Flask launch template."
}

variable "react_user_data" {
  type        = string
  description = "Base64-encoded user data for React launch template."
}

variable "flask_instance_type" {
  type    = string
  default = "t3.large"
}

variable "react_instance_type" {
  type    = string
  default = "t3.small"
}

variable "flask_asg_min" {
  type    = number
  default = 2
}

variable "flask_asg_desired" {
  type    = number
  default = 2
}

variable "flask_asg_max" {
  type    = number
  default = 4
}

variable "flask_health_check_grace_period" {
  type    = number
  default = 600
}

variable "react_asg_min" {
  type    = number
  default = 2
}

variable "react_asg_desired" {
  type    = number
  default = 2
}

variable "react_asg_max" {
  type    = number
  default = 4
}

variable "react_health_check_grace_period" {
  type    = number
  default = 300
}

variable "tags" {
  type    = map(string)
  default = {}
}
