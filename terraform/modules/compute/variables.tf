variable "project_name" {
  description = "Project identifier used to prefix resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for ECS networking"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_tasks_sg_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "alb_target_group_arn" {
  description = "ALB target group ARN for ECS service"
  type        = string
}

variable "db_url_secret_arn" {
  description = "ARN of the DB URL secret in Secrets Manager"
  type        = string
}

variable "jwt_private_key_secret_arn" {
  description = "ARN of the JWT private key secret in Secrets Manager"
  type        = string
}

variable "jwt_public_key_secret_arn" {
  description = "ARN of the JWT public key secret in Secrets Manager"
  type        = string
}

variable "task_cpu" {
  description = "ECS task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "ECS task memory in MiB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of ECS service tasks"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port the backend container listens on"
  type        = number
  default     = 8000
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
