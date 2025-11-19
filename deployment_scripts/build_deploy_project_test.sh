#! /bin/sh

# change to the directory of the currently running script
cd "$(dirname "$(realpath "$0")")"

# run the prepare docker project script
source ./prepare_docker_project.sh

# change to the docker directory:
cd ../docker

# build and execute the docker container for the development scenario
docker-compose -f docker-compose-test.yml up -d  --build

# notify the user that the container has finished executing
echo "The test docker container has finished building and is running"
