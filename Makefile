
all:
	@echo ""
	@echo "   cp_server  [DEVELOPMENT]"
	@echo " -------------------------------------------------------------------------"
	@echo ""
	@echo "  make                                      # Esta ayuda"
	@echo "  make build                                # Construir las imágenes para desarrollo"
	@echo "  make build-nc                             # Construir las imágenes para desarrollo sin el caché"
	@echo "  make build-web                            # Construir solo la imagen web"
	@echo "  make build-sidekiq                        # Construir solo la imagen sidekiq"
	@echo "  make up                                   # Ejecutar el proyecto en background"
	@echo "  make run                                  # Ejecutar el proyecto [para desarrollar]"
	@echo "  make stop                                 # Detener los containers"
	@echo "  make shell                                # Acceder al contenedor"
	@echo "  make migrate                              # Ejecutar migraciones de base de datos"
	@echo ""
	@echo "  CONTEST MANAGEMENT:"
	@echo "  make contest-new NUM=3 [PROBLEMS=3]       # Crear nuevo contest con templates"
	@echo "  make contests-create                      # Importar contests desde contests/"
	@echo "  make contests-update                      # Actualizar contests existentes"
	@echo "  make contests-destroy                     # Borrar todos los contests"
	@echo ""

# Esto sólo construye para desarrollo
# DOCKER_BUILD_FLAGS can be set to add flags like --no-cache
DOCKER_BUILD_FLAGS ?=

# Common build arguments
BUILD_ARGS = --build-arg BUNDLE_PATH="/usr/local/bin/bundle" \
		--build-arg BUNDLE_WITHOUT="" \
		--build-arg RAILS_ENV="development" \
		--build-arg RAILS_MASTER_KEY="config/master.key"

# Sidekiq-specific build arguments (uses /app workdir)
SIDEKIQ_BUILD_ARGS = $(BUILD_ARGS) \
		--build-arg WORKDIR_PATH="/app" \
		--build-arg BUNDLE_DEPLOYMENT="0"

build-sidekiq:
	docker compose build $(DOCKER_BUILD_FLAGS) $(SIDEKIQ_BUILD_ARGS) sidekiq

build-web:
	docker compose build $(DOCKER_BUILD_FLAGS) $(BUILD_ARGS) cp_server

build: build-sidekiq build-web

build-nc: DOCKER_BUILD_FLAGS=--no-cache
build-nc: build

stop:
	docker compose stop

run:
	rm -f ./app/tmp/pids/server.pid
	docker compose run --rm -v $(PWD)/app:/app --service-ports cp_server

up:
	docker compose up -d --remove-orphans

migrate:
	docker compose run --rm cp_server bundle exec rails db:migrate

shell:
	docker compose run --rm -v $(PWD)/app:/app --service-ports cp_server bash

contest-new:
	@./create_contest.sh $(NUM) $(PROBLEMS)

contests-create:
	docker compose run --rm cp_server bundle exec rake contests:create

contests-update:
	docker compose run --rm cp_server bundle exec rake contests:create:force

contests-destroy:
	docker compose run --rm cp_server bundle exec rake contests:destroy

