#!/bin/sh

# function that deploys the containers for dev/test/prod environments
build_deploy_dev_environment ()
{
	# build the list of compose files:
	local COMPOSE_FILES=("--env-file" "./docker/.env")
	COMPOSE_FILES+=("-f" "docker/CODE-db-deploy.yml")

	if [ "$ENV_NAME" == "dev" ]; then
		# this is intended for the development environment (retain database and ords volumes)
		COMPOSE_FILES+=("-f" "docker/CODE-db-named-volumes.yml")
	fi

	COMPOSE_FILES+=("-f" "docker/custom-docker-compose.yml")

	# build and execute the docker container for the specified deployment environment:
	docker compose "${COMPOSE_FILES[@]}" up -d --build
}