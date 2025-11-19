# PIFSC Oracle Developer Environment

## Overview
The PIFSC Oracle Developer Environment (ODE) project was developed to provide a containerized Oracle development environment for PIFSC software developers.  The project can be extended to automatically create/deploy database schemas and applications to allow data systems with dependencies to be developed and tested using the ODE.  This repository can be forked to customize ODE for a specific software project.  

## Resources
-   ### ODE Version Control Information
    -   URL: https://picgitlab.nmfs.local/oracle-developer-environment/pifsc-oracle-developer-environment
    -   Version: 1.0 (git tag: ODE_v1.0)
-   [ODE Demonstration Outline](./docs/demonstration_outline.md)
-   [ODE Repository Fork Diagram](./docs/ODE_fork_diagram.drawio.png)
    -   [ODE Repository Fork Diagram source code](./docs/ODE_fork_diagram.drawio)

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
-   The ODE repository is intended to be forked for specific data systems
-   The [ODE Repository Fork Diagram](./docs/ODE_fork_diagram.drawio.png) shows the different example and actual forked repositories that could be part of the suite of ODE repositories for different data systems
    -   The implemented repositories are shown in blue:
        -   [ODE](https://picgitlab.nmfs.local/oracle-developer-environment/pifsc-oracle-developer-environment)
            -   The ODE is the first repository shown at the top of the diagram and serves as the basis for all forked repositories for specific data systems
        -   [DSC ODE](https://picgitlab.nmfs.local/oracle-developer-environment/dsc-pifsc-oracle-developer-environment)
        -   [Centralized Authorization System (CAS) ODE](https://picgitlab.nmfs.local/oracle-developer-environment/cas-pifsc-oracle-developer-environment)
    -   The examples or repositories that have not been implemented yet are shown in orange  
![ODE Repository Fork Diagram](./docs/ODE_fork_diagram.drawio.png)

## Runtime Scenarios
There are two different runtime scenarios implemented in this project:
-   Both scenarios implement a docker volume for the Apex static files (apex-static-vol) that are used in the Apex upgrade process
-   Both scenarios mount the [ords-config](./docker/ords-config) folder to implement the custom apex configuration file [settings.xml](./docker/ords-config/global/settings.xml) to define the ords configuration to allow Apex to use the static files properly.  If there is additional custom ORDS configuration this file can be updated in the repository to set the configuration
-   ### Development:
    -   This scenario retains the database across container restarts, this is intended for database and application development purposes
    -   This scenario implements a docker volume for the database files (db-vol) to retain the database data across container restarts
-   ### Test:
    -   This scenario does not retain the database across container restarts, this is intended to test the deployment process of schemas and applications

## Customization Process
-   \*Note: this process will fork the ODE parent repository and repurpose it as a project-specific ODE
-   Fork the [project](#ode-version-control-information)
    -   Update the name/description of the project to specify the data system that is implemented in ODE
-   Clone the forked project to a working directory
-   Update the forked project in the working directory
    -   Update the [documentation](./README.md) to reference all of the repositories that are used to build the image and deploy the container
    -   Update the [custom_prepare_docker_project.sh](./deployment_scripts/custom_prepare_docker_project.sh) bash script to retrieve DB/app files for all dependencies (if any) as well as the DB/app files for the given data system and place them in the appropriate subfolders in the [src folder](./docker/src)
    -   Update the [custom_project_config.sh](./deployment_scripts/sh_script_config/custom_project_config.sh) bash script to specify the respository URL(s) needed to clone the container dependencies
    -   Update the [.env](./docker/.env) environment to specify the configuration values:
        -   ORACLE_PWD is the password for the SYS, SYSTEM database schema passwords, the Apex administrator password, the ORDS administrator password
        -   TARGET_APEX_VERSION is the version of Apex that will be installed
        -   APP_SCHEMA_NAME is the database schema that will be used to check if the database schemas have been installed, this only applies to the development [runtime scenario](#runtime-scenarios)
        -   DB_IMAGE is the path to the database image used to build the database contianer (db container)
        -   ORDS_IMAGE is the path to the ORDS image used to build the ORDS/Apex container (ords container)
    -   Update the [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh) bash script to execute a series of SQLPlus scripts in the correct order to create/deploy schemas, create Apex workspaces, and deploy Apex apps that were copied to the /src directory when the [prepare_docker_project.sh](./deployment_scripts/prepare_docker_project.sh) script is executed. This process can be customized for any Oracle data system.
        -   Update the [container_config.sh](./docker/src/deployment_scripts/config/custom_container_config.sh) to specify the variables necessary to authenticate the corresponding SQLPlus scripts when the [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh) bash script is executed

-   ### Implementation Examples
    -   Single database with no dependencies: [DSC ODE project](https://picgitlab.nmfs.local/oracle-developer-environment/dsc-pifsc-oracle-developer-environment)
    -   Database and Apex app with a single database dependency: [Centralized Authorization System (CAS) ODE project](https://picgitlab.nmfs.local/oracle-developer-environment/cas-pifsc-oracle-developer-environment)
    -   Database and Apex app with two levels of database dependencies and an application dependency: [PARR Tools ODE project](https://picgitlab.nmfs.local/oracle-developer-environment/parr-tools-pifsc-oracle-developer-environment)

## Deployment Process
-   ### Prepare the folder structure
    -   Run the [prepare_docker_project.sh](./deployment_scripts/prepare_docker_project.sh) bash script to prepare a folder by retrieving the DB/app files for all dependencies (if any) as well as the DB/app files for the given data system which will be used to build and run the ODE container
-   ### Build and run the container
    -   Navigate to the prepared folder (e.g. /c/docker/pifsc-oracle-developer-environment/docker) to build and run the container
    -   #### Choose a runtime scenario:
        -   [Development](#development): The [build_deploy_project_dev.sh](./deployment_scripts/build_deploy_project_dev.sh) bash script is intended for development purposes   
            -   This scenario retains the Oracle data in the database when the container starts by specifying a docker volume for the Oracle data folder so developers can pick up where they left off
        -   [Test](#test): The [build_deploy_project_test.sh](./deployment_scripts/build_deploy_project_test.sh) bash script is intended for testing purposes
            -   This scenario does not retain any Oracle data in the database so it can be used to deploy schemas and/or Apex applications to a blank database instance for a variety of test scenarios.    

## Container Architecture
-   The db container is built from an official Oracle database image (defined by DB_IMAGE in [.env](./docker/.env)) maintained in the Oracle container registry
-   The ords container is built from an official Oracle ORDS image (defined by ORDS_IMAGE in [.env](./docker/.env)) maintained in the Oracle container registry and contains both ORDS and Apex capabilities
    -   This container waits until the db container is running and the service is healthy
-   The db_ords_deploy container is built from a custom dockerfile that uses an official Oracle InstantClient image with some custom libraries installed and copies the source code from the [src folder][./docker/src].  
    -   This container waits until the db container is running and the service is healthy and Apex has been installed on the database container
    -   This container runs the [run_db_app_deployment.sh](./docker/src/run_db_app_deployment.sh) bash script to deploy all database schemas, Apex workspaces, and Apex apps
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
