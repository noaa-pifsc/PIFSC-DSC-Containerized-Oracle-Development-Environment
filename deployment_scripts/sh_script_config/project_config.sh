#! /bin/sh

# define the git urls for the Oracle Development Environment dependencies:

# define the SYS credentials for use in deployment scripts based on environment variables:
SYS_CREDENTIALS="SYS/${ORACLE_PWD}@${DBHOST}:${DBPORT}/${DBSERVICENAME} as SYSDBA"

# DSC repository URL:
dsc_git_url="git@picgitlab.nmfs.local:centralized-data-tools/pifsc-dsc.git"

# define DSC schema credentials
DB_DSC_USER="DSC"
DB_DSC_PASSWORD="[CONTAINER_PW]"

# define DSC connection string
DSC_CREDENTIALS="$DB_DSC_USER/$DB_DSC_PASSWORD@${DBHOST}:${DBPORT}/${DBSERVICENAME}"
