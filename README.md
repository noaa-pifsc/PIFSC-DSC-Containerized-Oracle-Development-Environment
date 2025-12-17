# PIFSC Containerized Oracle Developer Environment

## Overview
The PIFSC Containerized Oracle Developer Environment (CODE) project was developed to provide a containerized Oracle development environment for PIFSC software developers.  The project can be extended to automatically create/deploy database schemas and applications to allow data systems with dependencies to be developed and tested using the CODE.  This repository can be forked to customize CODE for a specific software project.  

## Resources
-   ### CODE Version Control Information
    -   URL: https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment
    -   Version: 1.2 (git tag: CODE_v1.2)
-   [CODE Demonstration Outline](./docs/demonstration_outline.md)
-   [CODE Repository Fork Diagram](./docs/CODE_fork_diagram.drawio.png)
    -   [CODE Repository Fork Diagram source code](./docs/CODE_fork_diagram.drawio)

## Dependencies
\* Note: all dependencies are implemented as git submodules in the [modules](./modules) folder
-   ### Container Deployment Scripts (CDS) Version Control Information
    -   Version Control Information:
        -   URL: <git@picgitlab.nmfs.local:centralized-data-tools/pifsc-container-deployment-scripts.git>
        -   Database: 1.1 (Git tag: pifsc_container_deployment_scripts_v1.1)

# Prerequisites
-   Docker 
-   Create an account or login to the [Oracle Image Registry](https://container-registry.oracle.com)
    -   Generate an auth token
        -   Click on your username and choose "Auth Token"
        -   Click "Generate Secret Key"
        -   Click "Copy Secret Key"
            -   Save this key somewhere secure, you will need it to login to the container registry via docker
    -   (Windows X instructions) Then, in a command(cmd) window, Log into Oracle Registry with your secret Auth Token
    ```
    docker login container-registry.oracle.com
    ```
    -   To sign in with a different user account, just use logout command:
    ```
    docker logout container-registry.oracle.com
    ```

## Repository Fork Diagram
-   The CODE repository is intended to be forked for specific data systems
-   The [CODE Repository Fork Diagram](./docs/CODE_fork_diagram.drawio.png) shows the different example and actual forked repositories that could be part of the suite of CODE repositories for different data systems
    -   The implemented repositories are shown in blue:
        -   [CODE](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment)
            -   The CODE is the first repository shown at the top of the diagram and serves as the basis for all forked repositories for specific data systems
        -   [DSC CODE](https://github.com/noaa-pifsc/PIFSC-DSC-Containerized-Oracle-Development-Environment)
        -   [Centralized Authorization System (CAS) CODE](https://github.com/noaa-pifsc/PIFSC-CAS-Containerized-Oracle-Development-Environment)
    -   The examples or repositories that have not been implemented yet are shown in orange  
![CODE Repository Fork Diagram](./docs/CODE_fork_diagram.drawio.png)

## Runtime Scenarios
There are two different runtime scenarios implemented in this project:
-   Both scenarios implement a docker volume for the Apex static files (apex-static-vol) that are used in the Apex upgrade process
-   Both scenarios mount the [ords-config](./docker/ords-config) folder to implement the custom apex configuration file [settings.xml](./docker/ords-config/global/settings.xml) to define the ords configuration to allow Apex to use the static files properly.  If there is additional custom ORDS configuration this file can be updated in the repository to set the configuration
-   ### Development:
    -   This scenario retains the database across container restarts, this is intended for database and application development purposes
    -   This scenario implements a docker volume for the database files (db-vol) to retain the database data across container restarts
    -   \*Note: If the [.env](./docker/.env) file is updated to increase the value of the TARGET_APEX_VERSION environment variable and the containers are restarted then the Apex upgrade will be performed and the admin Apex account will have its password reset to the ORACLE_PWD environment variable
        -   \*Note: The TARGET_APEX_VERSION variable can only be increased once an apex container is upgraded, it can't be used to downgrade an existing Apex version.  If a downgrade is required the database volume (db-vol) needs to be deleted and then the container must be run again.  
-   ### Test:
    -   This scenario does not retain the database across container restarts, this is intended to test the deployment process of schemas and applications

## Automated Deployment Process
-   ### Prepare the project
    -   Recursively clone the [CODE repository](#code-version-control-information) to a working directory
-   ### Build and Run the container 
    -   Execute the [build_deploy_project.sh](./deployment_scripts/build_deploy_project.sh) bash script with an environment name parameter (dev, test, prod) or if you don't specify an environment name the script will prompt you
    -   Scenarios:
        -   [Development](#development) will be implemented with an environment name value of "dev"
        -   [Test](#test) will be implemented with an environment name value of "test" or "prod" 

## Customization Process
-   ### Implementation
    -   \*Note: this process will fork a given CODE repository and repurpose it as a project-specific CODE
    -   Fork the desired CODE repository (e.g. [CODE](#code-version-control-information)
    -   Update the name/description of the project to specify the data system that is implemented in CODE
    -   Clone the forked project recursively to a working directory
    -   Update the forked project in the working directory
        -   Update the [README.md](./README.md) to reference all of the repositories that are used to build the image and deploy the container
        -   Update the [.env](./docker/.env) environment to specify the configuration values:
            -   ORACLE_PWD is the password for the SYS, SYSTEM database schema passwords, the Apex administrator password, the ORDS administrator password
            -   TARGET_APEX_VERSION is the version of Apex that will be installed
                -   \*Note: If the value is less than the currently installed version of APEX the db_app_deploy container will print an error message and exit the container.  
                -   \*Note: If the value is not a valid APEX version available on the Oracle download site the db_app_deploy container will print an error message and exit the container.  
                -   \*Note: If the given project does not need APEX at all then delete TARGET_APEX_VERSION and it will not be installed (this saves time and resources)
            -   APP_SCHEMA_NAME is the database schema that will be used to check if the database schemas have been installed, this only applies to the [development runtime scenario](#development)
            -   DB_IMAGE is the path to the database image used to build the database contianer (db container)
            -   ORDS_IMAGE is the path to the ORDS image used to build the ORDS/Apex container (ords container)
        -   add git submodules in a designated folder (e.g. modules) for any git repository dependencies that the given project has
        -   Update [custom-docker-compose.yml](./docker/custom-docker-compose.yml) to define volumes to mount the corresponding submodule repository folders necessary to deploy the database(s)/apex application(s) 
        -   Update the [custom_deployment_functions.sh](./deployment_scripts/functions/custom_deployment_functions.sh) script to implement any custom docker compose commands to deploy the customized containers
            -   \*Note: if the project does not need ORDS or Apex the [CODE-ords.yml](./docker/CODE-ords.yml) can be omitted from the list of docker compose configuration file parameters to exclude the ords docker container
        -   Update the [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh) bash script to execute a series of SQLPlus scripts in the correct order to create/deploy schemas, create Apex workspaces, and deploy Apex apps that were mounted by [custom-docker-compose.yml](./docker/custom-docker-compose.yml).
            -   Update the [custom_container_config.sh](./docker/src/deployment_scripts/config/custom_container_config.sh) to specify the variables necessary to authenticate the corresponding SQLPlus scripts when the [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh) bash script is executed
-   ### Implementation Examples
    -   Single database with no dependencies: [DSC CODE project](https://github.com/noaa-pifsc/PIFSC-DSC-Containerized-Oracle-Development-Environment)
    -   Database and Apex app with a single database dependency: [Centralized Authorization System (CAS) CODE project](https://github.com/noaa-pifsc/PIFSC-CAS-Containerized-Oracle-Development-Environment)
    -   Database and Apex app with two levels of database dependencies and an application dependency: [PARR Tools CODE project](https://github.com/noaa-pifsc/PIFSC-PARR-Tools-Containerized-Oracle-Development-Environment)
-   ### Upstream Updates
    -   Most upstream file updates can be accepted without changes, except for the following files that should be merged (to integrate any appropriate upstream updates) or rejected (Keep HEAD revision) based on their function:
        -   Merge:
            -   [README.md](./README.md) to reference any changes in the upstream README.md that are relevant
            -   [.env](./docker/.env) to retain the APP_SCHEMA_NAME or any other project-specific information (e.g. TARGET_APEX_VERSION)
        -   Reject:
            -   [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh)
            -   [custom_container_config.sh](./docker/src/deployment_scripts/config/custom_container_config.sh)
            -   [custom-docker-compose.yml](./docker/custom-docker-compose.yml)
            -   [custom_deployment_functions.sh](./deployment_scripts/functions/custom_deployment_functions.sh)

## Container Architecture
-   The db container is built from an official Oracle database image (defined by DB_IMAGE in [.env](./docker/.env)) maintained in the Oracle container registry
-   The ords container is built from an official Oracle ORDS image (defined by ORDS_IMAGE in [.env](./docker/.env)) maintained in the Oracle container registry and contains both ORDS and Apex capabilities
    -   This container waits until the db container is running and the service is healthy
-   The db_ords_deploy container is built from a custom dockerfile that uses an official Oracle InstantClient image with some custom libraries installed and copies the source code from the [src folder][./docker/src].  
    -   This container waits until the db container is running and the service is healthy and Apex has been installed on the database container
    -   This container runs the [db_app_deploy.sh](./docker/src/deployment_scripts/db_app_deploy.sh) bash script to deploy all database schemas, Apex workspaces, and Apex apps
    -   Once the db_ords_deploy container finishes deploying the database schemas/apps the container will shut down.  

## Connection Information
For the following connections refer to the [.env](./docker/.env) configuration file for the corresponding values
-   Database connections:
    -   hostname: localhost:1521/${DBSERVICENAME}
    -   username: SYSTEM or SYS AS SYSDBA
    -   password: ${ORACLE_PWD}
-   Apex server:
    -   hostname: http://localhost:8181/ords/apex
    -   workspace: internal
    -   username: ADMIN
    -   password: ${ORACLE_PWD}
-   ORDS server:
    -   hostname: http://localhost:8181/ords
