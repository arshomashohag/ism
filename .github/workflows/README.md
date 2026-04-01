# GitHub Actions Workflows

## Workflows

### `ci.yml` — Continuous Integration
Runs on every push and PR to `main`/`develop`:
- Lints and tests the FastAPI backend (ruff + pytest)
- Analyzes and tests the Flutter frontend

### `deploy.yml` — Continuous Deployment
Runs on PR to `main` (plan only) and push to `main` (full deploy):

**On PR:**
1. `terraform plan` against dev environment, posted as PR comment

**On merge to main:**
1. Build Docker image → push to ECR (tagged with git SHA + `latest`)
2. Run Alembic migration as ECS Fargate task (wait for completion)
3. Force new ECS deployment → wait for service stability
4. Build Flutter web → sync to S3 → CloudFront cache invalidation

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN for OIDC auth (trust GitHub Actions) |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state |
| `TF_LOCK_TABLE` | DynamoDB table name for Terraform state locking |
| `ECR_REPOSITORY_NAME` | ECR repository name (e.g. `ims-dev-backend`) |
| `ECS_CLUSTER_NAME` | ECS cluster name (e.g. `ims-dev-cluster`) |
| `ECS_SERVICE_NAME` | ECS service name (e.g. `ims-dev-backend-svc`) |
| `MIGRATION_TASK_DEFINITION` | Migration task definition name (e.g. `ims-dev-migration`) |
| `ECS_PRIVATE_SUBNET_IDS` | Comma-separated private subnet IDs for ECS tasks |
| `ECS_TASK_SG_ID` | Security group ID for ECS tasks |
| `FRONTEND_BUCKET_NAME` | S3 bucket name for Flutter web build |
| `CLOUDFRONT_DISTRIBUTION_ID` | CloudFront distribution ID for cache invalidation |

## IAM Role Setup (OIDC)

Create an IAM role with the following trust policy for GitHub OIDC:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*"
      }
    }
  }]
}
```

Attach the following managed policies (scope down in production):
- `AmazonECS_FullAccess`
- `AmazonEC2ContainerRegistryPowerUser`
- `AmazonS3FullAccess`
- `CloudFrontFullAccess`
- `AmazonRDSReadOnlyAccess`

And inline policies for Terraform state S3/DynamoDB access.
