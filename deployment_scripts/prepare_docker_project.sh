#! /bin/sh

echo "running container preparation script"

# create a temporary directory to load the files into from the root folder of the repository
mkdir ../tmp

# This is where the project dependencies are cloned and added to the development container's file system so they are available when the docker container is built and executed
echo "clone the project dependencies"

# ***************Insert code to include project dependencies *************** #



echo "remove all temporary files"
rm -rf ../tmp

echo "the docker project files are now ready for configuration and image building/running"
