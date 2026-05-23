variable "project_name" {
  type        = string
  description = "Project name used for resource naming and tags."
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. dev)."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets (one per AZ)."
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets (one per AZ)."
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use a single NAT gateway in the first public subnet (cost savings)."
  default     = true
}

variable "enable_ssh_between_tiers" {
  type        = bool
  description = "Allow SSH (TCP 22) from private subnet CIDRs for React-to-Flask debugging."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
  default     = {}
}
