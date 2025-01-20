
all:
	@echo ""
	@echo "   cp_server  [DEVELOPMENT]"
	@echo " -------------------------------------------------------------------------"
	@echo ""
	@echo "  make                                      # Esta ayuda"
	@echo "  make build                                # Construir las imágenes para desarrollo"
	@echo "  make destroy                              # Detener los containers y borrar los volúmenes (borra la BBDD)"
	@echo "  make run                                  # Ejecutar el proyecto [para desarrollar]"
	@echo "  make down                                 # Detener los containers"
	@echo "  make shell                                # Acceder al contenedor"
	@echo ""

# Esto sólo construye para desarrollo
build:
	docker compose build --no-cache \
		--build-arg BUNDLE_PATH="/usr/local/bin/bundle" \
		--build-arg BUNDLE_WITHOUT="" \
		--build-arg RAILS_ENV="development" \
		cp_server

destroy:
	docker compose down --volumes

down:
	docker compose down

run:
	rm -f ./app/tmp/pids/server.pid
	docker compose run --service-ports cp_server

shell:
	docker compose run --service-ports cp_server bash
