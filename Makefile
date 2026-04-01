.PHONY: up down logs backend-sh health flutter-run \
        lint-py test-py migrate seed db-reset

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
