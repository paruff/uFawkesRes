# shellcheck shell=sh

.PHONY: help init check-env up down logs status test-smoke test pr

## help: print this help message
help:
	@grep -E '^## [a-z]' Makefile | sed 's/^## //' | awk -F': ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

## init: create data directories with mode 755
init:
	@echo "Creating data directories (mode 755)..."
	install -d -m 755 data/postgres
	install -d -m 755 data/authelia
	@echo ""
	@echo "✅ data/ directories ready"

## check-env: validate required environment variables
check-env:
	./scripts/check-env.sh

## up: start the resource plane stack
up: check-env
	docker compose up -d

## down: stop all services
down:
	docker compose down

## logs: tail logs for all running services
logs:
	docker compose logs -f

## status: show running containers and health endpoints
status:
	docker compose ps
	@echo ""
	@echo "Health endpoints:"
	@curl -sf http://localhost:80/ping         > /dev/null && echo "  ✅ Traefik      :80" || echo "  ❌ Traefik      :80"
	@curl -sf http://localhost:9091/api/health > /dev/null && echo "  ✅ Authelia     :9091" || echo "  ❌ Authelia     :9091"

## test-smoke: run smoke tests against the running stack
test-smoke:
	./scripts/smoke-test.sh

## test: run all tests
test: test-smoke

# GitOps targets
pre-commit-setup: ## Install pre-commit hooks
	@pip install pre-commit
	@pre-commit install
	@echo "✅ Pre-commit hooks installed"

pre-commit-run: ## Run all pre-commit hooks
	@pre-commit run --all-files

## pr: stage, commit (with pre-commit), push, and create a PR
##   Usage: make pr MSG="fix(infra): add volume mounts"
##          make pr                                          # auto-generate message
pr:
	./scripts/pr-create.sh "$(MSG)"
