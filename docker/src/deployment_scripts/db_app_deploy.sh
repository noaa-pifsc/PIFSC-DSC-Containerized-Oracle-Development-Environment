#!/bin/bash

# change to the directory of the currently running script
CURRENT_DIR="$(dirname "$(realpath "$0")")"
cd ${CURRENT_DIR}

# load the custom container configuration file (to define custom credentials)
source ./config/custom_container_config.sh

# define the SYS credentials for use in deployment scripts based on environment variables:
SYS_CREDENTIALS="SYS/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} as SYSDBA"

echo "Running the custom database/apex deployment process"

# --- Validations ---
if [ -z "${ORACLE_PWD}" ]; then
  echo "ERROR: ORACLE_PWD environment variable is not set. Halting."
  exit 1
fi
if [ -z "${DBHOST}" ]; then
  echo "ERROR: DBHOST environment variable is not set. Halting."
  exit 1
fi
if [ -z "${APP_SCHEMA_NAME}" ]; then
  echo "ERROR: APP_SCHEMA_NAME environment variable is not set. Halting."
  exit 1
fi

# define a query to check if APEX is installed
APEX_QUERY="SELECT COUNT(*) FROM DBA_REGISTRY WHERE COMP_ID = 'APEX' AND STATUS = 'VALID';"

echo "The value of APEX_QUERY is: $APEX_QUERY"

# === APEX UPGRADE CONFIGURATION ===
# Reads the version from the environment variable set in docker-compose.yml
# Defaults to 24.2 if not set
TARGET_APEX_VERSION=${TARGET_APEX_VERSION:-"24.2"}

# Define paths for the dynamic download
APEX_ZIP_FILE_NAME="apex_${TARGET_APEX_VERSION}.zip"
APEX_ZIP_PATH="/tmp/${APEX_ZIP_FILE_NAME}"
APEX_DOWNLOAD_URL="https://download.oracle.com/otn_software/apex/${APEX_ZIP_FILE_NAME}"
APEX_STATIC_DIR="/apex-static" # This is the mount path for our shared volume
# === END APEX UPGRADE CONFIGURATION ===

# Function to check if the database is initialized
check_database_initialized() {
	# Check if your custom schema (e.g., '${APP_SCHEMA_NAME}') exists
	echo "SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME = '${APP_SCHEMA_NAME}';" | sqlplus -s $SYS_CREDENTIALS | grep -q '1'
}

# Wait until the database is available
echo "Waiting for Oracle Database to be ready..."
until echo "exit" | sqlplus -s $SYS_CREDENTIALS > /dev/null; do
	echo "Database not ready, waiting 5 seconds..."
	sleep 5
done
echo "Database is ready!"

# === APEX UPGRADE LOGIC ===
echo "========================================="
echo "STEP 1: Checking APEX Version"
echo "========================================="
echo "Target version: ${TARGET_APEX_VERSION}"

echo "Checking database for APEX version..."
CURRENT_VERSION_CHECK=$(sqlplus -s -l ${SYS_CREDENTIALS} <<EOF
  set heading off feedback off pagesize 0
  select version_no from apex_release;
  exit;
EOF
)
CURRENT_VERSION_CHECK=$(echo $CURRENT_VERSION_CHECK | xargs)

if echo "${CURRENT_VERSION_CHECK}" | grep -q "${TARGET_APEX_VERSION}"; then
  echo "APEX is already at the target version (${CURRENT_VERSION_CHECK})."
  
  # --- NEW CHECK ---
  # Check if static files are also in place
  if [ -f "${APEX_STATIC_DIR}/apex_version.js" ]; then
	echo "Static files are in place. No upgrade needed."
	SKIP_LOGIC_BLOCK=1
  else
	echo "APEX DB is upgraded, but static files are missing."
	echo "Will attempt to download/unzip/copy static files..."
	# Set flag to skip DB install
	SKIP_DB_INSTALL=1
  fi
  # --- END NEW CHECK ---
else
  echo "APEX version mismatch. Found: '${CURRENT_VERSION_CHECK}'"
  echo "Starting APEX upgrade to ${TARGET_APEX_VERSION}..."
  SKIP_DB_INSTALL=0
fi

# This block now runs if an upgrade is needed OR if static files are missing
if [[ $SKIP_LOGIC_BLOCK -ne 1 ]]; then

  # --- DYNAMIC DOWNLOAD ---
  if [ ! -f "${APEX_ZIP_PATH}" ]; then
	echo "Downloading ${APEX_DOWNLOAD_URL}..."
	curl -L -o ${APEX_ZIP_PATH} ${APEX_DOWNLOAD_URL}
	if [ $? -ne 0 ]; then
	  echo "ERROR: Download of APEX zip file failed."
	  exit 1
	fi
	echo "Download complete."
  else
	echo "APEX zip file already found at ${APEX_ZIP_PATH}."
  fi
  
  echo "Unzipping ${APEX_ZIP_PATH}..."
  unzip -q ${APEX_ZIP_PATH} -d /tmp
  if [ $? -ne 0 ]; then
	echo "ERROR: Failed to unzip APEX file."
	exit 1
  fi
  cd /tmp/apex
  # --- END DYNAMIC DOWNLOAD ---
  
  # --- PARALLEL EXECUTION START ---
  DB_INSTALL_PID=0
  DB_INSTALL_STATUS=0
  FILE_COPY_STATUS=0
  
  if [ $SKIP_DB_INSTALL -eq 0 ]; then
	echo "Starting APEX DB installer (in background)..."
	# Run the DB install in the background by adding '&'
	sqlplus -s -l ${SYS_CREDENTIALS} <<EOF &
	  WHENEVER SQLERROR EXIT SQL.SQLCODE
	  ALTER SESSION SET CONTAINER = XEPDB1;
	  @apexins.sql SYSAUX SYSAUX TEMP /i/
	  exit;
EOF
	DB_INSTALL_PID=$! # Save the Process ID of the background job
  else
	echo "Skipping database install as version is already correct."
  fi

  # --- COPY TO SHARED VOLUME (Runs in foreground) ---
  echo "Copying APEX static images to shared volume (in foreground)..."
  
  # Clear out any old 'images' folder and move the new one in.
  rm -rf ${APEX_STATIC_DIR}/*
  # Move the contents of the images folder to the root of the volume and update owner permissions on the volume to the oracle account
  mv /tmp/apex/images/* ${APEX_STATIC_DIR}/
  chown -R 54321:0 ${APEX_STATIC_DIR}/
  FILE_COPY_STATUS=$? 
  if [ $FILE_COPY_STATUS -eq 0 ]; then
  	echo "Static files copied successfully."
  else
	echo "ERROR: Static file copy failed."
  fi
  # --- END COPY ---

  # --- Wait for background DB install to finish ---
  if [ $DB_INSTALL_PID -ne 0 ]; then
	echo "Waiting for APEX DB install (PID: $DB_INSTALL_PID) to finish..."
	wait $DB_INSTALL_PID
	DB_INSTALL_STATUS=$?
	if [ $DB_INSTALL_STATUS -eq 0 ]; then
	  echo "APEX database upgrade successful."
	  
	  # run this code only if the APEX upgrade just finished, unlock the APEX_PUBLIC_USER account
	  echo "Unlocking APEX accounts..."
	  sqlplus -s -l ${SYS_CREDENTIALS} <<EOF
		WHENEVER SQLERROR EXIT SQL.SQLCODE
		ALTER SESSION SET CONTAINER = XEPDB1;
		-- Use the same password for all internal accounts for simplicity
		ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "${ORACLE_PWD}" ACCOUNT UNLOCK;
		
		-- Disable Strong Password Requirement (For Dev Environment)
		BEGIN
		APEX_INSTANCE_ADMIN.SET_PARAMETER('STRONG_SITE_ADMIN_PASSWORD', 'N');
		COMMIT;
		END;
		/

		-- Set the ADMIN password for the INTERNAL workspace (based on ORACLE_PWD variable defined in .env file)
		BEGIN
			APEX_UTIL.set_security_group_id(10);
			APEX_UTIL.create_user(
				p_user_name => 'ADMIN',
				p_email_address => 'admin@localhost',
				p_web_password=> '${ORACLE_PWD}',
				p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
				p_change_password_on_first_use => 'N' -- Ensure no forced change password
			);
			COMMIT;
		EXCEPTION WHEN OTHERS THEN
			-- If apex admin user already exists, just reset the password (based on ORACLE_PWD variable defined in .env file)
			APEX_UTIL.reset_password(
				p_user_name => 'ADMIN',
				p_old_password => NULL,
				p_new_password => '${ORACLE_PWD}',
				p_change_password_on_first_use => FALSE -- Ensure no forced change password
			);
			COMMIT;
		END;
		/
		exit;
EOF
	  if [ $? -eq 0 ]; then
		echo "APEX setup completed successfully."
	  else
		echo "ERROR: APEX setup failed."
		exit 1
	  fi
	  
	else
	  echo "ERROR: Background APEX database upgrade failed."
	fi
  fi
  
  # --- Final check for all parallel jobs ---
  if [ $DB_INSTALL_STATUS -ne 0 ] || [ $FILE_COPY_STATUS -ne 0 ]; then
	echo "ERROR: One or more upgrade tasks failed. Halting."
	exit 1
  fi
  # --- PARALLEL EXECUTION END ---

  echo "Cleaning up installer files..."
  rm -rf /tmp/apex ${APEX_ZIP_PATH}
fi
# === END APEX UPGRADE LOGIC ===

# Loop until APEX is in a VALID state
echo "Waiting for APEX to be in a VALID state..."
until echo "$APEX_QUERY" | sqlplus -S $SYS_CREDENTIALS <<EOF | grep -P -o '^\s*(1)\s*$'
SET HEADING OFF
$APEX_QUERY
EXIT;
EOF
do
	echo "APEX not in a VALID state, waiting 5 seconds..."
	sleep 5
done
echo "APEX is installed and ready!"

echo "Checking if the database has been initialized (schema: ${APP_SCHEMA_NAME})..."
# Check if the database is initialized by querying DBA_USERS
if ! check_database_initialized; then
	echo "Database is not initialized, run the custom database and/or application deployment scripts"

	# run the custom database and/or application deployment scripts:
	source ${CURRENT_DIR}/custom_db_app_deploy.sh

else
	echo "Database already initialized. Skipping deployment script."
fi

echo "All deployment steps complete."