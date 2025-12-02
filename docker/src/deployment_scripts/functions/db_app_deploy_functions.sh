#!/bin/bash


# Function to compare versions numerically, this function accepts two parameters ($1 and $2) in the format: [0-9]+(\.[0-9]+)+
# Returns 0 if $1 = $2
# Returns 1 if $1 > $2
# Returns 2 if $1 < $2
version_compare() {
	# Split versions into arrays by '.' so the individual major/minor/patch numbers can be compared
	IFS='.' read -ra VER1 <<< "$1"
	IFS='.' read -ra VER2 <<< "$2"

	# Iterate through the components of each specified version to compare them
	for ((i=0; i<${#VER1[@]} || i<${#VER2[@]}; i++)); do
		# Use 0 as default if a component is missing (e.g. 24.1 vs 24.1.0)
		# store the current component in the v1 and v2 variablesf for $1 and $2 respectively
		local v1=${VER1[i]:-0}
		local v2=${VER2[i]:-0}
		
		# if the v1 component is greater than the v2 component then $1 is greater
		if (( ${v1} > ${v2} )); then
			return 1 # $1 is greater
		elif (( ${v1} < ${v2} )); then	# if the v2 component is greater than the v1 component then $1 is not greater
			return 2 # $2 is greater
		fi
	done

	# If none of the v1 or v2 components were greater/less than the versions are equal
	return 0 # $1 and $2 are equivalent
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
		echo "ERROR: Invalid APEX version format: '$target_version'. Expected format: XX.X (e.g., 23.2)"
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
		echo ${apex_version}	# return the value of the query result, truncate to remove a trailing zero (e.g. 24.2.0 becomes 24.2)
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

# function to validate that all required environment variables are defined, if any of them are not defined the script will output an error and halt the calling script
validate_env_vars() {

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

# function to install or upgrade apex based on the current installed version and the TARGET_APEX_VERSION environment variable
install_or_upgrade_apex() {

	# Define paths for the dynamic download
	local APEX_ZIP_FILE_NAME="apex_${TARGET_APEX_VERSION}.zip"
	local APEX_ZIP_PATH="/tmp/${APEX_ZIP_FILE_NAME}"
	local APEX_DOWNLOAD_URL="https://download.oracle.com/otn_software/apex/${APEX_ZIP_FILE_NAME}"
	local APEX_STATIC_DIR="/apex-static" # This is the mount path for the shared apex static files volume

	echo "Target Apex version: ${TARGET_APEX_VERSION}"

	# Validate APEX version format (e.g., 23.2, 24.1), if it is invalid exit the function
	validate_apex_version_format "${TARGET_APEX_VERSION}"

	# validate if the specified TARGET_APEX_VERSION version actually exists on Oracle's site
	verify_apex_version_exists "${TARGET_APEX_VERSION}" "${APEX_DOWNLOAD_URL}"

	# retrieve the current version of Apex by querying the databae
	local CURRENT_APEX_VERSION=$(get_installed_apex_version)

	echo "Current Apex version: ${CURRENT_APEX_VERSION}"

	# compare the current and target versions of apex and store the return value in VERSION_STATUS
	version_compare "$TARGET_APEX_VERSION" "$CURRENT_APEX_VERSION" 
	local VERSION_STATUS=$?

	# initialize local variables to track if the Apex upgrade should be installed in the database (SKIP_DB_INSTALL) and if the static apex files should be updated (SKIP_FILE_INSTALL)
	local SKIP_DB_INSTALL=0
	local SKIP_FILE_INSTALL=0

	# check if the Apex installation should be upgraded or not
	if [ $VERSION_STATUS -eq 2 ]; then
		# downgrade attempt detected, the TARGET_APEX_VERSION is less than the CURRENT_APEX_VERSION
		echo "ERROR: Downgrade detected! Current APEX version is ${CURRENT_APEX_VERSION}, but target is ${TARGET_APEX_VERSION}."
		echo "Downgrading APEX via this automation is not supported. Exiting."
		exit 1

	elif [ $VERSION_STATUS -eq 0 ]; then
		# do not upgrade, TARGET_APEX_VERSION and CURRENT_APEX_VERSION are equivalent
		echo "APEX is already at the target version (${CURRENT_APEX_VERSION})."
		
		# Check if static files are also in place
		if [ -f "${APEX_STATIC_DIR}/apex_version.js" ]; then
			echo "Static files are in place. No upgrade needed."
			SKIP_FILE_INSTALL=1
		else
			echo "APEX DB is upgraded, but static files are missing."
			echo "Will attempt to download/unzip/copy static files..."
			# Set flag to skip DB install
			SKIP_DB_INSTALL=1
		fi

	else
		# upgrade the apex version, TARGET_APEX_VERSION is greater than the CURRENT_APEX_VERSION
		echo "APEX version mismatch. Found: '${CURRENT_APEX_VERSION}'"
		echo "Starting APEX upgrade to ${TARGET_APEX_VERSION}..."
		SKIP_DB_INSTALL=0
	fi

	# check if the static Apex files should be installed
	if [[ $SKIP_FILE_INSTALL -ne 1 ]]; then

		# the apex package does not dynamically download and install the apex installation package
		echo "Downloading ${APEX_DOWNLOAD_URL}..."
		curl -L -o ${APEX_ZIP_PATH} ${APEX_DOWNLOAD_URL}
		if [ $? -ne 0 ]; then
			echo "ERROR: Download of APEX zip file failed."
			exit 1
		fi

		echo "Apex upgrade package download complete."
		
		echo "Unzipping ${APEX_ZIP_PATH}..."
		unzip -q ${APEX_ZIP_PATH} -d /tmp
		if [ $? -ne 0 ]; then
			echo "ERROR: Failed to unzip APEX file."
			exit 1
		fi
		
		# change the current directory so the Apex installation can proceed normally with the relative paths
		cd /tmp/apex

		# initialize the local variables to support the parallel installation of Apex in the DB and the file system (docker volume)
		local DB_INSTALL_PID=0
		local DB_INSTALL_STATUS=0
		local FILE_COPY_STATUS=0

		# check if the Apex database installation should proceed
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
			echo "Skipping Apex database installation since the version is already the same"
		fi

		# copy the Apex static images to the shared docker volume in the foreground
		echo "Copying APEX static images to shared volume (in foreground)..."
		
		# Clear out any old static Apex files 
		rm -rf ${APEX_STATIC_DIR}/*

		# Move the contents of the images folder to the root of the volume
		mv /tmp/apex/images/* ${APEX_STATIC_DIR}/

		# store the results of the file move process in FILE_COPY_STATUS so the result can be checked
		local FILE_COPY_STATUS=$? 
		if [ $FILE_COPY_STATUS -eq 0 ]; then
			echo "Static files copied successfully."
			
			# update owner permissions on the docker volume to the oracle account so the static Apex files can be used by the ords container
			chown -R 54321:0 ${APEX_STATIC_DIR}/
		else
			echo "ERROR: Static file copy failed."
		fi

		# wait for background DB install to finish
		if [ $DB_INSTALL_PID -ne 0 ]; then
			echo "Waiting for APEX DB install (PID: $DB_INSTALL_PID) to finish..."
			wait $DB_INSTALL_PID
				local DB_INSTALL_STATUS=$?	# store the result of the Apex database installation in a new variable

			# check if the database installation 
			if [ $DB_INSTALL_STATUS -eq 0 ]; then
				echo "APEX database upgrade successful."
				
				# check if the target apex version is less than 23.2
				version_compare "${TARGET_APEX_VERSION}" "23.2"
				
				if [ $? -eq 2 ]; then 
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
				
				else
					# apex version is 23.2 or higher
					
					# define a PL/SQL block to unlock the apex admin using the APEX_INSTANCE_ADMIN.UNLOCK_USER procedure
					UNLOCK_BLOCK="
						BEGIN
							APEX_INSTANCE_ADMIN.UNLOCK_USER(
								p_workspace => 'INTERNAL',
								p_username	=> 'ADMIN',
								p_password	=> '${ORACLE_PWD}'
							);
							COMMIT;
						EXCEPTION WHEN OTHERS THEN
							 -- Fallback or ignore if user doesn't exist yet (should not happen here)
							 NULL;
						END;
					"
				
				fi
				
				# The APEX upgrade completed, unlock the APEX_PUBLIC_USER account and attempt to create the APEX instance admin account or if it already exists then reset the password to ${ORACLE_PWD}

				# run the sqlplus script using the SYS schema
				echo "Unlocking/Initializing/Configuring APEX accounts..."
				
				sqlplus -s -l ${SYS_CREDENTIALS} <<EOF
				WHENEVER SQLERROR EXIT SQL.SQLCODE
				ALTER SESSION SET CONTAINER = ${DBSERVICENAME};
				-- Use the same password for all internal accounts for simplicity
				ALTER USER APEX_PUBLIC_USER IDENTIFIED BY "${ORACLE_PWD}" ACCOUNT UNLOCK;
				SET SERVEROUTPUT ON
				
				-- Switch to the APEX schema to perform admin tasks
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
				# check the result of the sqlplus commands
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
		
		# Check the results of the background and foreground jobs 
		if [ $DB_INSTALL_STATUS -ne 0 ] || [ $FILE_COPY_STATUS -ne 0 ]; then
			echo "ERROR: One or more upgrade tasks failed. Halting."
			exit 1
		fi

		# remove the apex installation files
		echo "Cleaning up installer files..."
		rm -rf /tmp/apex ${APEX_ZIP_PATH}
	fi

}

