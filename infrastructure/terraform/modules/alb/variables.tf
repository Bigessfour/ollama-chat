variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "flask_health_check_path" {
  type    = string
  default = "/api/ready"
}

variable "react_health_check_path" {
  type    = string
  default = "/"
}

variable "tags" {
  type    = map(string)
  default = {}
}
