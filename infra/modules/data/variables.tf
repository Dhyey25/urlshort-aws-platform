variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs from the network module"
}

variable "rds_security_group_id" {
  type = string
}

variable "redis_security_group_id" {
  type = string
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "database_name" {
  type    = string
  default = "kutt"
}

variable "rds_master_username" {
  type    = string
  default = "kutt_admin"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "redis_num_nodes" {
  type    = number
  default = 1
}
