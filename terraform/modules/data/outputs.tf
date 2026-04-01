output "db_address" {
  description = "RDS instance endpoint address"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_url_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the DB URL"
  value       = aws_secretsmanager_secret.db_url.arn
}

output "jwt_private_key_secret_arn" {
  description = "ARN of the Secrets Manager secret for JWT private key"
  value       = aws_secretsmanager_secret.jwt_private_key.arn
}

output "jwt_public_key_secret_arn" {
  description = "ARN of the Secrets Manager secret for JWT public key"
  value       = aws_secretsmanager_secret.jwt_public_key.arn
}

output "frontend_bucket_name" {
  description = "S3 bucket name for Flutter web build"
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_bucket_arn" {
  description = "S3 bucket ARN for Flutter web build"
  value       = aws_s3_bucket.frontend.arn
}
