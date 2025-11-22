
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
	@echo "  make destroy                              # Detener los containers y borrar los volúmenes (borra la BBDD)"
	@echo "  make run                                  # Ejecutar el proyecto [para desarrollar]"
	@echo "  make down                                 # Detener los containers"
	@echo "  make shell                                # Acceder al contenedor"
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

destroy:
	docker compose down --volumes

down:
	docker compose down

run:
	rm -f ./app/tmp/pids/server.pid
	docker compose run -v $(PWD)/app:/app --service-ports cp_server

migrate:
	docker compose run --rm cp_server bundle exec rails db:migrate

shell:
	docker compose run -v $(PWD)/app:/app --service-ports cp_server bash
