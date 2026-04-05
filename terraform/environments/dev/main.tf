terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ── Networking ────────────────────────────────────────────────

module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  az_count     = 2
}

# ── Data (RDS + S3 + Secrets Manager) ────────────────────────

module "data" {
  source = "../../modules/data"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  rds_sg_id          = module.networking.rds_sg_id

  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_backup_retention_days = var.db_backup_retention_days
}

# ── Gateway (ALB + CloudFront) ────────────────────────────────

module "gateway" {
  source = "../../modules/gateway"

  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.networking.vpc_id
  public_subnet_ids    = module.networking.public_subnet_ids
  alb_sg_id            = module.networking.alb_sg_id
  frontend_bucket_arn  = module.data.frontend_bucket_arn
  frontend_bucket_name = module.data.frontend_bucket_name
  ui_domain            = var.ui_domain
  api_domain           = var.api_domain
  ui_certificate_arn   = var.ui_certificate_arn
  api_certificate_arn  = var.api_certificate_arn
  vpn_cidr             = var.vpn_cidr
}

# ── Compute (ECS Fargate) ─────────────────────────────────────

module "compute" {
  source = "../../modules/compute"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  ecs_tasks_sg_id      = module.networking.ecs_tasks_sg_id
  alb_target_group_arn = module.gateway.alb_target_group_arn

  db_url_secret_arn          = module.data.db_url_secret_arn
  jwt_private_key_secret_arn = module.data.jwt_private_key_secret_arn
  jwt_public_key_secret_arn  = module.data.jwt_public_key_secret_arn

  task_cpu      = var.ecs_task_cpu
  task_memory   = var.ecs_task_memory
  desired_count = var.ecs_desired_count
  image_tag     = var.image_tag
}
