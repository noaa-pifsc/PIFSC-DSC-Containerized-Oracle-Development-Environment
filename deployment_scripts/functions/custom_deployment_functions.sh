#!/bin/sh

# function that deploys the containers for dev/test/prod environments
build_deploy_dev_environment ()
{
	# build the list of compose files:
	
	# include the docker environment variables
	local COMPOSE_FILES=("--env-file" "./docker/.env")
	
	# include the db and db-ords-deploy services
	COMPOSE_FILES+=("-f" "docker/CODE-db-deploy.yml")

	# check if this is intended for a dev environment (retain database and ords volumes across container restarts) 
	if [ "$ENV_NAME" == "dev" ]; then
		# add in the named volume for the db service
		COMPOSE_FILES+=("-f" "docker/CODE-db-named-volume.yml")
	fi

	# add custom docker compose to integrate additional services and/or map project-specific resources for the db-ords-deploy service to automatically deploy
	COMPOSE_FILES+=("-f" "docker/custom-docker-compose.yml")

	# build and execute the docker container for the specified deployment environment:
	docker compose "${COMPOSE_FILES[@]}" up -d --build
}