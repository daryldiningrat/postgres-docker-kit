COMPOSE := docker compose

.PHONY: up down restart pull ps logs psql shell backup extensions validate

up: ## start the stack and wait until healthy, then finish post-init setup
	$(COMPOSE) up -d --wait
	@./scripts/enable-extensions.sh

down: ## stop the stack (data volume is preserved)
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

pull: ## pull the newest image for the pinned tag
	$(COMPOSE) pull

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=100

psql: ## interactive psql as the superuser
	$(COMPOSE) exec postgres bash -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

shell:
	$(COMPOSE) exec postgres bash

backup:
	@./scripts/backup.sh

extensions:
	@./scripts/enable-extensions.sh

validate: ## check the compose file without starting anything
	$(COMPOSE) config --quiet && echo "compose config OK"
