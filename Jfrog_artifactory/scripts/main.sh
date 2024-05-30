#!/bin/bash

#######################################
# Script to automate Jfrog Artifactory,  Nginx setup with SSL
#######################################

# Source the utility functions
script_utils_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the utils functions
source $script_utils_dir/common_functions.sh

# Variables for Jenkins setup
IP_ADDRESS="$1"
ARTIFACTORY_VERSION="7.77.6"
ARTIFACTORY_TAR="jfrog-artifactory-oss-${ARTIFACTORY_VERSION}-linux.tar.gz"
ARTIFACTORY_NAME="artifactory-oss-${ARTIFACTORY_VERSION}"
JFROG_HOME="/opt/jfrog"
DATABASE_URL="localhost:5432"
DATABASE_USERNAME="artifactory"
DATABASE_PASSWORD="noreyni"
# SERVICE_FILE="/etc/systemd/system/artifactory.service"
SSL_DIR="/etc/nginx/ssl"
SSL_CERTIFICATE_PATH="$SSL_DIR/artifactory.crt"
SSL_KEY_PATH="$SSL_DIR/artifactory.key"
STATE="Senegal"
ORGANIZATION="Noreyni"
UNIT="Software &Devops Engineer"
SERVICE_CONFIG_FILE="artifactory.conf"
# PROXY_PASS_URL="http://127.0.0.1:8081/artifactory/"
PROXY_PASS_URL="http://127.0.0.1:8082/"
USER="artifactory"
GROUP="artifactory"


setup_jfrog_home() {
    Info "Setting up JFrog Home..."

    sudo mkdir -p "$JFROG_HOME"
    cd "$JFROG_HOME"
    sudo wget "https://releases.jfrog.io/artifactory/bintray-artifactory/org/artifactory/oss/jfrog-artifactory-oss/$ARTIFACTORY_VERSION/$ARTIFACTORY_TAR" -O "$ARTIFACTORY_TAR"
    sudo tar -xzf "$ARTIFACTORY_TAR"
    sudo rm -rf "$JFROG_HOME/$ARTIFACTORY_TAR"

    echo "export JFROG_HOME=\"$JFROG_HOME\"" | sudo tee -a /etc/environment

    success "JFrog Home set up successfully."
}

# Function to setup Artifactory as a service
setup_artifactory_service() {
    sudo $JFROG_HOME/$ARTIFACTORY_NAME/app/bin/installService.sh
    sleep 5
    # Set permissions for the artifactory user on JFROG_HOME
    sudo chown -R $USER:$GROUP "$JFROG_HOME"

    # Set ownership for specific directories (including /opt/jfrog/artifactory-oss-7.77.6/var)
    sudo chown -R $USER:$GROUP $JFROG_HOME/$ARTIFACTORY_NAME/var

    # Set permissions for the entire JFROG_HOME directory
    sudo chmod -R 755 "$JFROG_HOME"

    # Start Artifactory
    sudo systemctl enable artifactory.service
    sudo systemctl start artifactory.service

}


OS=$(getOs)

# update the operating system
update_os

# Run Java installation
install_java "17"

# Create a JFrog Home directory and move the downloaded installer archive into that directory.
setup_jfrog_home

# Setup Artifactory service
setup_artifactory_service
sleep 1

# Run the SSL directory creation:
create_ssl_directory "$SSL_DIR" "$USER" "$GROUP"

# Run the SSL certificate generation
generate_ssl_certificates "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$STATE" "$ORGANIZATION" "$UNIT"

# Run the Nginx installation and configuration
setup_nginx_installation_configuration "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$SERVICE_CONFIG_FILE" "$PROXY_PASS_URL"

sudo systemctl daemon-reload


sudo systemctl restart artifactory
success "JFrog Artifactory has been successfully installed and configured with Nginx as a reverse proxy with SSL."
# Log IP address
success "the Username is: admin and the Password: password"
successWithUrlLink "Access Jfrog Artifactory via" "https://$IP_ADDRESS"