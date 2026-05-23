variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "enable_ssh_between_tiers" {
  type        = bool
  description = "Allow SSH from React tier to Flask tier. Prefer SSM Session Manager (default false)."
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
