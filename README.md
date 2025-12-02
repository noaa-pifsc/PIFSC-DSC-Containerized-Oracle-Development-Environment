# PIFSC Containerized Oracle Developer Environment

## Overview
The PIFSC Containerized Oracle Developer Environment (CODE) project was developed to provide a containerized Oracle development environment for PIFSC software developers.  The project can be extended to automatically create/deploy database schemas and applications to allow data systems with dependencies to be developed and tested using the CODE.  This repository can be forked to customize CODE for a specific software project.  

## Resources
-   ### CODE Version Control Information
    -   URL: https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment
    -   Version: 1.1 (git tag: CODE_v1.1)
-   [CODE Demonstration Outline](./docs/demonstration_outline.md)
-   [CODE Repository Fork Diagram](./docs/CODE_fork_diagram.drawio.png)
    -   [CODE Repository Fork Diagram source code](./docs/CODE_fork_diagram.drawio)

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
-   ### Prepare the folder structure
    -   The [prepare_docker_project.sh](./deployment_scripts/prepare_docker_project.sh) bash script is automatically executed when the deployment script for either [runtime scenario](#runtime-scenario) is executed.  
    -   The script prepares the working copy of the repository by dynamically retrieving the DB/app files for all dependencies (if any) as well as the DB/app files for the given data system which will be used to build and run the CODE container
-   ### Build and Run the container 
    -   Choose a runtime scenario:
        -   [Development](#development): The [build_deploy_project_dev.sh](./deployment_scripts/build_deploy_project_dev.sh) bash script is intended for development purposes   
            -   This scenario retains the Oracle data in the database when the container starts by specifying a docker volume for the Oracle data folder so developers can pick up where they left off
        -   [Test](#test): The [build_deploy_project_test.sh](./deployment_scripts/build_deploy_project_test.sh) bash script is intended for testing purposes
            -   This scenario does not retain any Oracle data in the database so it can be used to deploy schemas and/or Apex applications to a blank database instance for a variety of test scenarios.    

## Customization Process
-   ### Implementation
    -   \*Note: this process will fork a given CODE repository and repurpose it as a project-specific CODE
    -   Fork the desired CODE repository (e.g. [CODE](#code-version-control-information)
    -   Update the name/description of the project to specify the data system that is implemented in CODE
    -   Clone the forked project to a working directory
    -   Update the forked project in the working directory
        -   Update the [README.md](./README.md) to reference all of the repositories that are used to build the image and deploy the container
        -   Update the [custom_prepare_docker_project.sh](./deployment_scripts/custom_prepare_docker_project.sh) bash script to retrieve DB/app files for all dependencies (if any) as well as the DB/app files for the given data system and place them in the appropriate subfolders in the [src folder](./docker/src)
        -   Update the [custom_project_config.sh](./deployment_scripts/sh_script_config/custom_project_config.sh) bash script to specify variables for the respository URL(s) needed to clone the container dependencies
        -   Update the [.env](./docker/.env) environment to specify the configuration values:
            -   ORACLE_PWD is the password for the SYS, SYSTEM database schema passwords, the Apex administrator password, the ORDS administrator password
            -   TARGET_APEX_VERSION is the version of Apex that will be installed
                -   \*Note: If the value is less than the currently installed version of APEX the db_app_deploy container will print an error message and exit the container.  
                -   \*Note: If the value is not a valid APEX version available on the Oracle download site the db_app_deploy container will print an error message and exit the container.  
            -   APP_SCHEMA_NAME is the database schema that will be used to check if the database schemas have been installed, this only applies to the [development runtime scenario](#development)
            -   DB_IMAGE is the path to the database image used to build the database contianer (db container)
            -   ORDS_IMAGE is the path to the ORDS image used to build the ORDS/Apex container (ords container)
        -   Update the [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh) bash script to execute a series of SQLPlus scripts in the correct order to create/deploy schemas, create Apex workspaces, and deploy Apex apps that were copied to the /src directory when the [prepare_docker_project.sh](./deployment_scripts/prepare_docker_project.sh) script is executed. This process can be customized for any Oracle data system.
            -   Update the [custom_container_config.sh](./docker/src/deployment_scripts/config/custom_container_config.sh) to specify the variables necessary to authenticate the corresponding SQLPlus scripts when the [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh) bash script is executed
        -   Create empty directories for any folders/files dynamically retrieved by [custom_prepare_docker_project.sh](./deployment_scripts/custom_prepare_docker_project.sh) (e.g. docker/src/DSC) and save .gitkeep files for them (e.g. docker/src/DSC/.gitkeep) so they can be added to version control
            -   Create a .gitignore file at the root of the repository to add entries for any empty directories that have content dynamically retrieved, for example a "DSC" folder:
            ```
            # Ignore all content in the DSC directory
            docker/src/DSC/*

            # Do not ignore the .gitkeep file for the DSC directory, so the directory itself is tracked.
            !docker/src/DSC/.gitkeep
            ```
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
            -   [custom_prepare_docker_project.sh](./deployment_scripts/custom_prepare_docker_project.sh)
            -   [custom_project_config.sh](./deployment_scripts/sh_script_config/custom_project_config.sh)
            -   [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh)
            -   [custom_container_config.sh](./docker/src/deployment_scripts/config/custom_container_config.sh)

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
    -   hostname: localhost:1521/XEPDB1
    -   username: SYSTEM or SYS AS SYSDBA
    -   password: ${ORACLE_PWD}
-   Apex server:
    -   hostname: http://localhost:8181/ords/apex
    -   workspace: internal
    -   username: ADMIN
    -   password: ${ORACLE_PWD}
-   ORDS server:
    -   hostname: http://localhost:8181/ords
