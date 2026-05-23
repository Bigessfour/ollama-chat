variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "ghcr_pat" {
  type        = string
  sensitive   = true
  description = "GitHub PAT with read:packages for GHCR (stored in SSM SecureString)."
}

variable "api_key" {
  type        = string
  sensitive   = true
  description = "Optional API key for Flask /api/chat (stored in SSM when non-empty)."
  default     = ""
}

variable "ssm_parameter_name" {
  type        = string
  description = "SSM parameter path for GHCR PAT."
  default     = "/ollama-chat/ghcr-pat"
}

variable "api_key_ssm_parameter_name" {
  type        = string
  description = "SSM parameter path for Flask API_KEY."
  default     = "/ollama-chat/api-key"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_cloudwatch_agent" {
  type        = bool
  description = "Attach CloudWatch Agent IAM policies to EC2 roles."
  default     = true
}
