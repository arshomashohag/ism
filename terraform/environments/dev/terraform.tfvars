aws_region   = "us-east-1"
environment  = "development"
project_name = "ims"

vpc_cidr = "10.0.0.0/16"

# RDS
db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
db_backup_retention_days = 7

# ECS
ecs_task_cpu      = 256
ecs_task_memory   = 512
ecs_desired_count = 1
image_tag         = "latest"
