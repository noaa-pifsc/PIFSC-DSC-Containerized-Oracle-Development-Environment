#!/bin/bash


# Helper function to compare versions numerically
# Returns 0 (true) if $1 > $2
version_gt() {

	echo "running version_gt($1, $2)"

    # Split versions into arrays by '.'
    IFS='.' read -ra VER1 <<< "$1"
    IFS='.' read -ra VER2 <<< "$2"

    # Iterate through the components of the version
    for ((i=0; i<${#VER1[@]} || i<${#VER2[@]}; i++)); do
        # Use 0 as default if a component is missing (e.g., 24.1 vs 24.1.0)
        local v1=${VER1[i]:-0}
        local v2=${VER2[i]:-0}

        if (( v1 > v2 )); then
            return 0 # True: $1 is greater
        elif (( v1 < v2 )); then
            return 1 # False: $1 is not greater
        fi
    done

    # If we get here, versions are equal
    return 1 # False: $1 is not strictly greater than $2
}

# Function to check if the database is initialized
check_database_initialized() {
	# Check if your custom schema (e.g., '${APP_SCHEMA_NAME}') exists
	echo "SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME = '${APP_SCHEMA_NAME}';" | sqlplus -s $SYS_CREDENTIALS | grep -q '1'
}

# function to validate the apex version using a regular expression
validate_apex_version_format() {
	local target_version="$1"
	# Validate APEX version format (Strictly X.X, e.g., 23.2, 24.1)
	# The regex ^[0-9]+\.[0-9]+$ ensures exactly one dot separating two integers.
	if [[ ! "$target_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
		echo "ERROR: Invalid APEX version format: '$version'. Expected format: XX.X (e.g., 23.2)"
		exit 1
	fi
}

# function to retrieve the currently installed apex version
get_installed_apex_version() {
	# Use 'whenever sqlerror exit failure' to catch DB errors.
	# Direct stderr to /dev/null to avoid capturing error text in the variable.
	# Query for the current apex version number, if APEX is not installed this query will fail with an ORA- error.
	local apex_version
	apex_version=$(sqlplus -s -l ${SYS_CREDENTIALS} <<EOF 2>/dev/null
		set heading off feedback off pagesize 0 verify off
		whenever sqlerror exit failure
		select version_no from apex_release;
		exit;
EOF
	)

	# Trim whitespace from sqlplus query output
	apex_version=$(echo $apex_version | xargs)

	# If the query failed with an ORA- error (e.g. table or view does not exist) or returned an empty result set then default the value of apex_version to 0.0
	if [ -z "$apex_version" ] || [[ "$apex_version" == *"ORA-"* ]]; then
		echo "0.0"	# the query was not successful or returned no value, default to 0.0
	else
		echo ${apex_version%.0}	# return the value of the query result, truncate to remove a trailing zero (e.g. 24.2.0 becomes 24.2)
	fi
}


# function to validate if the version actually exists on Oracle's site
# $1 is the target apex version
# $2 is the apex download URL that will be checked
function verify_apex_version_exists() {

	# Validate if the version actually exists on Oracle's site ---
	echo "Verifying existence of version ${1} on Oracle download site..."
	# Use curl -I (head request) to check headers only.
	# -f causes curl to fail on HTTP errors (like 404).
	# -s is silent mode.
	if ! curl --output /dev/null --silent --head --fail "${2}"; then
		echo "ERROR: APEX version ${1} does not exist at URL: ${2}"
		echo "Please check the version number and try again."
		exit 1
	else
		echo "The APEX version ${1} confirmed valid and available for download."
	fi
}


# consolidated function to determine what to do based on the TARGET_APEX_VERSION and apex_version
# Returns:
# 0 = Versions are EQUAL (Skip DB Install)
# 1 = Current < Target (Perform Upgrade)
# 2 = Current > Target (Error: Downgrade)
check_apex_version_status() {
    local current=$1
    local target=$2


	echo "running check_apex_version_status($1, $2)"

    # Normalize versions by removing trailing .0 for string comparison if needed
    # (Though get_installed_apex_version already does this for current)
    local norm_current=${current%.0}
    local norm_target=${target%.0}

    if [ "$norm_current" == "$norm_target" ]; then
        return 0 # Equal
    elif version_gt "$current" "$target"; then
        return 2 # Downgrade (Current > Target)
    else
        return 1 # Upgrade (Current < Target)
    fi
}



validate_env_vars() {
# --- Validations ---
if [ -z "${ORACLE_PWD}" ]; then
  echo "ERROR: ORACLE_PWD environment variable is not set. Halting."
  exit 1
fi
if [ -z "${DBHOST}" ]; then
  echo "ERROR: DBHOST environment variable is not set. Halting."
  exit 1
fi
if [ -z "${DBPORT}" ]; then
  echo "ERROR: DBPORT environment variable is not set. Halting."
  exit 1
fi
if [ -z "${DBSERVICENAME}" ]; then
  echo "ERROR: DBSERVICENAME environment variable is not set. Halting."
  exit 1
fi
if [ -z "${APP_SCHEMA_NAME}" ]; then
  echo "ERROR: APP_SCHEMA_NAME environment variable is not set. Halting."
  exit 1
fi

}

install_or_upgrade_apex() {

# === APEX UPGRADE LOGIC ===
echo "========================================="
echo "STEP 1: Checking APEX Version"
echo "========================================="
echo "Target version: ${TARGET_APEX_VERSION}"

# Define paths for the dynamic download
APEX_ZIP_FILE_NAME="apex_${TARGET_APEX_VERSION}.zip"
APEX_ZIP_PATH="/tmp/${APEX_ZIP_FILE_NAME}"
APEX_DOWNLOAD_URL="https://download.oracle.com/otn_software/apex/${APEX_ZIP_FILE_NAME}"
APEX_STATIC_DIR="/apex-static" # This is the mount path for the shared apex static files volume



# Validate APEX version format (e.g., 23.2, 24.1), if it is invalid exit the function
validate_apex_version_format "${TARGET_APEX_VERSION}"

# validate if the specified TARGET_APEX_VERSION version actually exists on Oracle's site
verify_apex_version_exists "${TARGET_APEX_VERSION}" "${APEX_DOWNLOAD_URL}"

echo "Checking database for APEX version..."
CURRENT_VERSION_CHECK=$(get_installed_apex_version)

echo "The current version of APEX is: ${CURRENT_VERSION_CHECK}"


# check the apex version status
check_apex_version_status "$CURRENT_VERSION_CHECK" "$TARGET_APEX_VERSION"
VERSION_STATUS=$?

echo "The value of VERSION_STATUS is: $VERSION_STATUS"

local SKIP_DB_INSTALL=0
local SKIP_LOGIC_BLOCK=0

    if [ $VERSION_STATUS -eq 2 ]; then
      # STATUS 2: DOWNGRADE DETECTED
	  echo "ERROR: Downgrade detected! Current APEX version is ${CURRENT_VERSION_CHECK}, but target is ${TARGET_APEX_VERSION}."
	  echo "Downgrading APEX via this automation is not supported. Exiting."
	  exit 1

    elif [ $VERSION_STATUS -eq 0 ]; then
      # STATUS 0: VERSIONS EQUAL
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
      # STATUS 1: UPGRADE NEEDED (Current < Target)
	  echo "APEX version mismatch. Found: '${CURRENT_VERSION_CHECK}'"
	  echo "Starting APEX upgrade to ${TARGET_APEX_VERSION}..."
	  SKIP_DB_INSTALL=0
    fi
    # --- END CONSOLIDATED LOGIC ---

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
	  local DB_INSTALL_PID=0
	  local DB_INSTALL_STATUS=0
	  local FILE_COPY_STATUS=0
	  
	  if [ $SKIP_DB_INSTALL -eq 0 ]; then
		echo "Starting APEX DB installer (in background)..."
		# Run the DB install in the background by adding '&'
		sqlplus -s -l ${SYS_CREDENTIALS} <<EOF &
		  WHENEVER SQLERROR EXIT SQL.SQLCODE
		  ALTER SESSION SET CONTAINER = ${DBSERVICENAME};
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
		  
		  
		  if version_gt "${TARGET_APEX_VERSION}" "23.1"; then
			# apex version is newer than 23.1
			
			# define a PL/SQL block to unlock the apex admin using the APEX_INSTANCE_ADMIN.UNLOCK_USER procedure
			UNLOCK_BLOCK="
				BEGIN
					APEX_INSTANCE_ADMIN.UNLOCK_USER(
						p_workspace => 'INTERNAL',
						p_username  => 'ADMIN',
						p_password  => '${ORACLE_PWD}'
					);
					COMMIT;
				EXCEPTION WHEN OTHERS THEN
					 -- Fallback or ignore if user doesn't exist yet (should not happen here)
					 NULL;
				END;
			"
		  
		  else
			# apex version is 23.1 or older

			# define a PL/SQL block to unlock the apex admin using the APEX_UTIL.RESET_PASSWORD procedure
			UNLOCK_BLOCK="
				BEGIN
					APEX_UTIL.set_security_group_id(10);
					APEX_UTIL.reset_password(
						p_user_name => 'ADMIN',
						p_old_password => NULL,
						p_new_password => '${ORACLE_PWD}',
						p_change_password_on_first_use => FALSE
					);
					COMMIT;
				EXCEPTION WHEN OTHERS THEN
					 NULL;
				END;
			"

		  
		  fi
		  
		  echo "The value of UNLOCK_BLOCK is: $UNLOCK_BLOCK"
		  
		  
		  # run this code only if the APEX upgrade just finished, unlock the APEX_PUBLIC_USER account
		  echo "Unlocking APEX accounts..."
		  sqlplus -s -l ${SYS_CREDENTIALS} <<EOF
			WHENEVER SQLERROR EXIT SQL.SQLCODE
			ALTER SESSION SET CONTAINER = ${DBSERVICENAME};
			-- Use the same password for all internal accounts for simplicity
			ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "${ORACLE_PWD}" ACCOUNT UNLOCK;
			SET SERVEROUTPUT ON
			
			-- Switch to the APEX schema to perform admin tasks (avoids ORA-20987)
			DECLARE
				v_apex_schema VARCHAR2(30);
			BEGIN
				SELECT schema INTO v_apex_schema FROM dba_registry WHERE comp_id = 'APEX';
				EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA = ' || dbms_assert.enquote_name(v_apex_schema);
			END;
			/

			-- Disable Strong Password Requirement (For Dev Environment)
			BEGIN
			APEX_INSTANCE_ADMIN.SET_PARAMETER('STRONG_SITE_ADMIN_PASSWORD', 'N');
			COMMIT;
			END;
			/

			-- Set the ADMIN password for the INTERNAL workspace (based on ORACLE_PWD variable defined in .env file)
			BEGIN
				DBMS_OUTPUT.PUT_LINE('Create the APEX admin user');
			
				APEX_UTIL.set_security_group_id(10);
				APEX_UTIL.create_user(
					p_user_name => 'ADMIN',
					p_email_address => 'admin@localhost',
					p_web_password=> '${ORACLE_PWD}',
					p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
					p_change_password_on_first_use => 'N' -- Ensure no forced change password
				);

				DBMS_OUTPUT.PUT_LINE('APEX admin user created successfully');

				COMMIT;
			EXCEPTION WHEN OTHERS THEN
				-- If apex admin user already exists, just reset the password (based on ORACLE_PWD variable defined in .env file)

				-- Run the appropriate unlock/reset block
				${UNLOCK_BLOCK}

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

}

