# Terraform — IMS Infrastructure

Terraform configuration for the IMS AWS infrastructure.
Full implementation is done in **Step 9**.

## Structure

```
terraform/
├── environments/
│   └── dev/          # Dev environment entry point
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars.example
└── modules/
    ├── networking/   # VPC, subnets, security groups
    ├── data/         # RDS PostgreSQL, ElastiCache
    ├── compute/      # ECS cluster, task definitions
    └── gateway/      # ALB, API Gateway, WAF
```

## Usage (Step 9+)

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

terraform init
terraform plan
terraform apply
```

## Prerequisites

- Terraform >= 1.7
- AWS CLI configured with appropriate credentials
- An S3 bucket for remote state (configured in Step 9)
