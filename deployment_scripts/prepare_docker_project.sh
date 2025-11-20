#! /bin/sh

echo "running container preparation script"


# clean out the tmp folder and then recreate the tmp folder to dynamically load the files into 
rm -rf ../tmp
mkdir ../tmp

# remove any existing project repository source files:
rm -rf ../docker/src/DSC/*

# This is where the project dependencies are cloned and added to the development container's file system so they are available when the docker container is built and executed
echo "clone the project dependencies"

	echo "clone the DSC project's dependencies"

	git clone $dsc_git_url ../tmp/pifsc-dsc

	echo "copy the docker files from the repository to the docker subfolder"

	# copy the docker files from the repository to the docker/src subfolder
	cp -r ../tmp/pifsc-dsc/SQL ../docker/src/DSC/SQL

	echo "The DSC project's dependencies have been added to the $project_directory"

echo "remove all temporary files"
rm -rf ../tmp

echo "the docker project files are now ready for configuration and image building/running"
