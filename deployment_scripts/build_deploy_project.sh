#! /bin/sh

# change to the root repository directory:
cd "$(dirname "$(realpath "$0")")"/..

# load the CDS client functions
source ./modules/CDS/src/reusable_functions/shared_functions.sh
source ./modules/CDS/src/reusable_functions/client_functions.sh

# retrieve the ENV_NAME variable value from the first parameter or by prompting the user
set_env_var "$1" 

# load the custom CODE deployment function:
source ./deployment_scripts/functions/custom_deployment_functions.sh

echo "Deploy the containerized oracle development environment ($ENV_NAME)"

# build/deploy the CODE container
build_deploy_dev_environment

# notify the user that the container has finished executing
echo "The $ENV_NAME docker container has finished building and is running"
