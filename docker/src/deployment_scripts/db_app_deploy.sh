#!/bin/bash

# change to the directory of the currently running script
CURRENT_DIR="$(dirname "$(realpath "$0")")"
cd ${CURRENT_DIR}

# load the custom container configuration file (to define custom credentials)
source ./config/custom_container_config.sh

# load the db_app_deploy.sh function definitions:
source ./functions/db_app_deploy_functions.sh

# validate all required environment variables:
validate_env_vars

# define the SYS credentials for use in deployment scripts based on environment variables:
SYS_CREDENTIALS="SYS/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} as SYSDBA"

echo "Running the custom database/apex deployment process"

# define a query to check if APEX is installed
APEX_QUERY="SELECT COUNT(*) FROM DBA_REGISTRY WHERE COMP_ID = 'APEX' AND STATUS = 'VALID';"

# Reads the target apex version from the environment variable set in docker-compose.yml
# Defaults to 24.2 if not set
TARGET_APEX_VERSION=${TARGET_APEX_VERSION:-"23.2"}

# Wait until the database is available
echo "Waiting for Oracle Database to be ready..."
until echo "exit" | sqlplus -s $SYS_CREDENTIALS > /dev/null; do
	echo "Database not ready, waiting 5 seconds..."
	sleep 5
done
echo "Database is ready!"

# install or upgrade the apex container installation:
install_or_upgrade_apex