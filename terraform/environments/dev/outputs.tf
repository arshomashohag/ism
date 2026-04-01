output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (API endpoint)"
  value       = module.gateway.alb_dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront domain for the Flutter web app"
  value       = module.gateway.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.gateway.cloudfront_distribution_id
}

output "ecr_repository_url" {
  description = "ECR repository URL for the backend Docker image"
  value       = module.compute.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.compute.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.compute.ecs_service_name
}

output "migration_task_definition_arn" {
  description = "ARN of the Alembic migration ECS task definition"
  value       = module.compute.migration_task_definition_arn
}

output "frontend_bucket_name" {
  description = "S3 bucket for Flutter web build uploads"
  value       = module.data.frontend_bucket_name
}

output "db_address" {
  description = "RDS endpoint address"
  value       = module.data.db_address
  sensitive   = true
}
