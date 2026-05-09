provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "urlshort-portfolio"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "Dhyey Solanki"
      Repository  = "https://github.com/Dhyey25/urlshort-aws-platform"
    }
  }
}

module "network" {
  source = "../../modules/network"

  project     = "urlshort"
  environment = var.environment
  vpc_cidr    = "10.0.0.0/16"
  app_port    = 3000
}

module "data" {
  source = "../../modules/data"

  project     = "urlshort"
  environment = var.environment

  private_subnet_ids      = module.network.private_subnet_ids
  rds_security_group_id   = module.network.rds_security_group_id
  redis_security_group_id = module.network.redis_security_group_id

  db_instance_class     = "db.t4g.micro"
  multi_az              = false
  deletion_protection   = false
  backup_retention_days = 7

  redis_node_type = "cache.t4g.micro"
  redis_num_nodes = 1
}

module "compute" {
  source = "../../modules/compute"

  project     = "urlshort"
  environment = var.environment
  region      = var.region

  vpc_id                      = module.network.vpc_id
  public_subnet_ids           = module.network.public_subnet_ids
  private_subnet_ids          = module.network.private_subnet_ids
  alb_security_group_id       = module.network.alb_security_group_id
  ecs_tasks_security_group_id = module.network.ecs_tasks_security_group_id

  rds_address                  = module.data.rds_address
  rds_port                     = module.data.rds_port
  database_name                = module.data.database_name
  redis_endpoint               = module.data.redis_primary_endpoint
  redis_port                   = module.data.redis_port
  rds_credentials_secret_arn   = module.data.rds_credentials_secret_arn
  redis_credentials_secret_arn = module.data.redis_credentials_secret_arn
  app_secrets_arn              = module.data.app_secrets_arn

  app_port       = 3000
  task_cpu       = 256
  task_memory    = 512
  desired_count  = 1
  image_tag      = "initial"
  default_domain = "localhost" # update when you have a real domain
}
