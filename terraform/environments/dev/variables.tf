variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (development / staging / production)"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Project identifier used to prefix resource names"
  type        = string
  default     = "ims"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ── RDS ───────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_backup_retention_days" {
  description = "RDS automated backup retention in days"
  type        = number
  default     = 7
}

# ── ECS ───────────────────────────────────────────────────────

variable "ecs_task_cpu" {
  description = "ECS task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "ECS task memory in MiB"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS service tasks"
  type        = number
  default     = 1
}

variable "image_tag" {
  description = "Backend Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "ui_domain" {
  description = "Custom domain for the Flutter web app"
  type        = string
  default     = "imsdev.carewarebd.com"
}

variable "api_domain" {
  description = "Custom domain for the backend API"
  type        = string
  default     = "imsdevapi.carewarebd.com"
}
