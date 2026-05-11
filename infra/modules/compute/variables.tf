variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "alb_security_group_id" { type = string }
variable "ecs_tasks_security_group_id" { type = string }
variable "rds_address" { type = string }
variable "rds_port" { type = number }
variable "database_name" { type = string }
variable "redis_endpoint" { type = string }
variable "redis_port" { type = number }
variable "rds_credentials_secret_arn" { type = string }
variable "redis_credentials_secret_arn" { type = string }
variable "app_secrets_arn" { type = string }

variable "app_port" {
  type    = number
  default = 3000
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "image_tag" {
  type    = string
  default = "initial"
}

variable "default_domain" {
  type = string
}
