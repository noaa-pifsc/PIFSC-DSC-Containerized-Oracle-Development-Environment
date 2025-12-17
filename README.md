# PIFSC DSC Containerized Oracle Developer Environment

## Overview
The PIFSC DSC Containerized Oracle Developer Environment (DCODE) project was developed to provide a custom containerized Oracle development environment (CODE) for the DSC.  This repository can be forked to extend the existing functionality to any data systems that depend on the DSC for both development and testing purposes.  

## Resources
-   ### DCODE Version Control Information
    -   URL: https://github.com/noaa-pifsc/PIFSC-DSC-Containerized-Oracle-Development-Environment
    -   Version: 1.2 (git tag: DSC_CODE_v1.2)
    -   Upstream repository:
        -   CODE Version Control Information:
            -   URL: https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment
            -   Version: 1.2 (git tag: CODE_v1.2)

## Dependencies
\* Note: all dependencies are implemented as git submodules in the [modules](./modules) folder
-   ### DSC Version Control Information
    -   Version Control Information:
        -   URL: <git@picgitlab.nmfs.local:centralized-data-tools/pifsc-dsc.git>
        -   Database: 1.1 (Git tag: dsc_db_v1.1)
-   ### Container Deployment Scripts (CDS) Version Control Information
    -   Version Control Information:
        -   URL: <git@picgitlab.nmfs.local:centralized-data-tools/pifsc-container-deployment-scripts.git>
        -   Database: 1.1 (Git tag: pifsc_container_deployment_scripts_v1.1)

## Prerequisites
-   See the CODE [Prerequisites](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment?tab=readme-ov-file#prerequisites) for details

## Repository Fork Diagram
-   See the CODE [Repository Fork Diagram](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment?tab=readme-ov-file#repository-fork-diagram) for details

## Runtime Scenarios
-   See the CODE [Runtime Scenarios](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment?tab=readme-ov-file#runtime-scenarios) for details

## Automated Deployment Process
-   ### Prepare the folder structure
    -   Recursively clone the [DCODE repository](#dcode-version-control-information) to a working directory
-   ### Build and Run the Containers 
    -   See the CODE [Build and Run the Containers](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment?tab=readme-ov-file#build-and-run-the-containers) for details
    -   #### DSC Database Deployment
        -   [create_docker_schemas.sql](https://picgitlab.nmfs.local/centralized-data-tools/pifsc-dsc/-/blob/main/SQL/dev_container_setup/create_docker_schemas.sql?ref_type=heads) is executed by the SYS schema to create the DSC schema and grant the necessary privileges
        -   [deploy_dev_container.sql](https://picgitlab.nmfs.local/centralized-data-tools/pifsc-dsc/-/blob/main/SQL/automated_deployments/deploy_dev_container.sql?ref_type=heads) is executed with the DSC schema to deploy the objects to the DSC schema

## Customization Process
-   ### Implementation
    -   \*Note: this process will fork the DCODE parent repository and repurpose it as a project-specific CODE
    -   Fork [this repository](#dcode-version-control-information)
    -   See the CODE [Implementation](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment?tab=readme-ov-file#implementation) for details 
-   ### Implementation Examples
    -   Database and APEX app with a single database dependency: [Centralized Authorization System (CAS) CODE project](https://github.com/noaa-pifsc/PIFSC-DSC-Containerized-Oracle-Development-Environment)
    -   Database and docker web app with a single database dependency: [PIFSC Resource Inventory (PRI) CODE project](https://github.com/noaa-pifsc/PIFSC-PRI-Containerized-Oracle-Development-Environment)
-   ### Upstream Updates
    -   See the CODE [Upstream Updates](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment?tab=readme-ov-file#upstream-updates) for details

## Container Architecture
-   See the CODE [container architecture documentation](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment?tab=readme-ov-file/-/blob/main/README.md?ref_type=heads#container-architecture) for details
-   ### DCODE Customizations:
    -   [docker/.env](./docker/.env) was updated to define an appropriate APP_SCHEMA_NAME value
    -   [custom_deployment_functions.sh](./deployment_scripts/functions/custom_deployment_functions.sh) was updated to remove the [CODE-ords.yml](./docker/CODE-ords.yml) configuration file
    -   [custom-docker-compose.yml](./docker/custom-docker-compose.yml) was updated to implement file-based secrets, PRI and CODE-specific mounted volume overrides 
    -   [custom_db_app_deploy.sh](./docker/src/deployment_scripts/custom_db_app_deploy.sh) was updated to deploy the DSC database
    -   [custom_container_config.sh](./docker/src/deployment_scripts/config/custom_container_config.sh) was updated to define DB credentials and mounted volume file paths for the PRI SQL scripts

## Connection Information
-   See the CODE [connection information documentation](https://github.com/noaa-pifsc/PIFSC-Containerized-Oracle-Development-Environment?tab=readme-ov-file/-/blob/main/README.md?ref_type=heads#connection-information) for details
-   ### DSC Database Connection Information
    -   Connection information can be found in [create_docker_schemas.sql](https://picgitlab.nmfs.local/centralized-data-tools/pifsc-dsc/-/blob/main/SQL/dev_container_setup/create_docker_schemas.sql?ref_type=heads)