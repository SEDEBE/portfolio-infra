.DEFAULT_GOAL := help
API_DIR := ../expense-tracker-api

help:  ## Show the available commands
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

dev:  ## Run everything locally: API in Docker, app and landing with Vite
	./scripts/dev.sh

stop:  ## Stop the local API containers
	cd $(API_DIR) && docker compose down

superuser:  ## Create a Django admin user in the local API
	cd $(API_DIR) && docker compose exec api python manage.py createsuperuser

password:  ## Change a local admin password: make password EMAIL=you@example.com
	cd $(API_DIR) && docker compose exec api python manage.py changepassword $(EMAIL)

.PHONY: help dev stop superuser password
