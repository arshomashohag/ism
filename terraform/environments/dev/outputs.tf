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

output "ecr_repository_name" {
  description = "ECR repository name (GitHub secret: ECR_REPOSITORY_NAME)"
  value       = module.compute.ecr_repository_name
}

output "migration_task_definition_name" {
  description = "Migration task definition name (GitHub secret: MIGRATION_TASK_DEFINITION)"
  value       = split("/", split(":", module.compute.migration_task_definition_arn)[5])[1]
}

output "private_subnet_ids" {
  description = "Comma-separated private subnet IDs (GitHub secret: ECS_PRIVATE_SUBNET_IDS)"
  value       = join(",", module.networking.private_subnet_ids)
}

output "ecs_task_sg_id" {
  description = "ECS tasks security group ID (GitHub secret: ECS_TASK_SG_ID)"
  value       = module.networking.ecs_tasks_sg_id
}
