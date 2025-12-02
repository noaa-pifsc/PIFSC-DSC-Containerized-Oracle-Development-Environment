#! /bin/sh

echo "running container preparation script"

# clean out the tmp folder (if it exists) and then recreate the tmp folder to dynamically load the files into 
rm -rf ../tmp
mkdir ../tmp

# This is where the project dependencies are cloned and added to the development container's file system so they are available when the docker container is built and executed
echo "clone the project dependencies"

# execute the custom prepare docker script that clones any dependencies and populates them in the corresponding /src folders
source ./custom_prepare_docker_project.sh


echo "remove all temporary files"
rm -rf ../tmp

echo "the docker project files are now ready for configuration and image building/running"
