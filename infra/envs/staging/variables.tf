variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "staging"

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be staging or prod."
  }
}
