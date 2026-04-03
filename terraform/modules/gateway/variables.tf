variable "project_name" {
  description = "Project identifier used to prefix resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "frontend_bucket_arn" {
  description = "S3 bucket ARN for Flutter web build"
  type        = string
}

variable "frontend_bucket_name" {
  description = "S3 bucket name for Flutter web build"
  type        = string
}

variable "container_port" {
  description = "Port the backend container listens on"
  type        = number
  default     = 8000
}

variable "ui_domain" {
  description = "Custom domain for the Flutter web app (e.g. imsdev.carewarebd.com)"
  type        = string
}

variable "api_domain" {
  description = "Custom domain for the backend API (e.g. imsdevapi.carewarebd.com)"
  type        = string
}

variable "ui_certificate_arn" {
  description = "ACM certificate ARN for the UI domain (must be in us-east-1 for CloudFront)"
  type        = string
}

variable "api_certificate_arn" {
  description = "ACM certificate ARN for the API domain (must be in the ALB region)"
  type        = string
}
