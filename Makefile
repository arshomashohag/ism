.PHONY: up down logs backend-sh health flutter-run \
        lint-py test-py migrate seed db-reset \
        tf-init tf-plan tf-apply tf-destroy tf-output

up:
	docker compose up --build -d

down:
	docker compose down

restart:
	make down
	make up

logs:
	docker compose logs -f backend

backend-sh:
	docker compose exec backend bash

health:
	curl -s http://localhost:8000/health | python3 -m json.tool

flutter-run:
	cd frontend && flutter run -d chrome

lint-py:
	cd backend && ruff check app/

test-py:
	cd backend && pytest tests/ -v

migrate:
	docker compose exec backend alembic upgrade head

seed:
	docker compose exec backend python -m scripts.seed

db-reset:
	docker compose exec backend alembic downgrade base
	docker compose exec backend alembic upgrade head
	docker compose exec backend python -m scripts.seed

# ── Terraform (dev) ───────────────────────────────────────────
# Usage:
#   AWS_PROFILE=<your-profile> make tf-init  STATE_BUCKET=<bucket> LOCK_TABLE=<table>
#   AWS_PROFILE=<your-profile> make tf-plan
#   AWS_PROFILE=<your-profile> make tf-apply
#
TF_DIR      := terraform/environments/dev
AWS_PROFILE ?= devadmin
STATE_BUCKET ?= ims-development-terraform-state
LOCK_TABLE  ?= ims-development-terraform-locks
TF_REGION   ?= us-east-1

tf-init:
	cd $(TF_DIR) && \
	  cp -n backend.tf.example backend.tf 2>/dev/null || true && \
	  AWS_PROFILE=$(AWS_PROFILE) terraform init \
	    -backend-config="bucket=$(STATE_BUCKET)" \
	    -backend-config="key=dev/terraform.tfstate" \
	    -backend-config="region=$(TF_REGION)" \
	    -backend-config="dynamodb_table=$(LOCK_TABLE)" \
	    -backend-config="encrypt=true" \
	    -reconfigure

tf-plan:
	cd $(TF_DIR) && \
	  cp -n terraform.tfvars.example terraform.tfvars 2>/dev/null || true && \
	  AWS_PROFILE=$(AWS_PROFILE) terraform plan -var-file=terraform.tfvars -out=.tfplan

tf-apply: tf-plan
	cd $(TF_DIR) && \
	  AWS_PROFILE=$(AWS_PROFILE) terraform apply .tfplan

tf-destroy:
	cd $(TF_DIR) && \
	  AWS_PROFILE=$(AWS_PROFILE) terraform destroy -var-file=terraform.tfvars

tf-output:
	cd $(TF_DIR) && \
	  AWS_PROFILE=$(AWS_PROFILE) terraform output
