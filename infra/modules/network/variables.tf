variable "project" {
  type        = string
  description = "Project name, used in resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name (staging, prod)"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "app_port" {
  type        = number
  default     = 3000
  description = "Application listening port"
}
