variable "aws_region" {
  type        = string
  description = "AWS region for all resources."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources."
  default     = "ollama-chat"
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use one NAT gateway (lower cost) vs one per AZ (HA)."
  default     = true
}

variable "enable_ssh_between_tiers" {
  type        = bool
  description = "Allow SSH from React SG to Flask SG. Prefer SSM Session Manager (default false)."
  default     = false
}

variable "ghcr_username" {
  type        = string
  description = "GitHub username/org for GHCR image pulls (not a secret)."
  default     = "bigessfour"
}

variable "backend_image" {
  type        = string
  description = "Backend container image reference."
  default     = "ghcr.io/bigessfour/ollama-chat-backend:latest"
}

variable "frontend_image" {
  type        = string
  description = "Frontend container image reference."
  default     = "ghcr.io/bigessfour/ollama-chat-frontend:latest"
}

variable "ghcr_pat" {
  type        = string
  sensitive   = true
  description = "GitHub PAT with read:packages (and write:packages for CI) stored in SSM."
}

variable "api_key" {
  type        = string
  sensitive   = true
  description = "Optional API key for Flask /api/chat (stored in SSM when set)."
  default     = ""
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

variable "additional_tags" {
  type        = map(string)
  description = "Extra tags merged into all resources."
  default     = {}
}

variable "enable_observability" {
  type        = bool
  description = "Create CloudWatch log groups, alarms, and IAM for the CloudWatch agent."
  default     = true
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "alarm_notification_email" {
  type        = string
  description = "Optional email subscribed to the SNS alarm topic (requires confirmation)."
  default     = ""
}
