#!/bin/sh

echo "running the custom database and/or application deployment scripts"

# run each of the sqlplus scripts to deploy the schemas, objects for each schema, applications, etc.
	echo "Create the DSC schemas"

	# change the directory so the script can run without alterations
	cd /usr/src/DSC/SQL

	# create the DSC schema(s)
sqlplus -s /nolog <<EOF
@dev_container_setup/create_docker_schemas.sql
$SYS_CREDENTIALS
EOF


	echo "Create the DSC objects"

	# change the directory to the DSC SQL folder to allow the scripts to run unaltered:
sqlplus -s /nolog <<EOF
@automated_deployments/deploy_dev_container.sql
$DSC_CREDENTIALS
EOF

	echo "the DSC objects were created"


	echo "SQL scripts executed successfully!"

echo "custom deployment scripts have completed successfully"
