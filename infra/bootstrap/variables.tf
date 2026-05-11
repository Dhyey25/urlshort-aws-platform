variable "region" {
  type    = string
  default = "us-east-1"
}

variable "profile" {
  type    = string
  default = "portfolio"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state. Suggest: urlshort-tfstate-<your-initials>-<random>"
}

variable "lock_table_name" {
  type    = string
  default = "urlshort-tflock"
}
