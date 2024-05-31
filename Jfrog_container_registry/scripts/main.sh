#!/bin/bash
#######################################
# Script to automate Jfrog Artifactory,  Nginx setup with SSL
#######################################

# Source the utility functions
script_utils_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the utils functions
source $script_utils_dir/common_functions.sh

# Set variables
IP_ADDRESS="$1"
JCR_VERSION="7.77.6"
JCR_TAR="jfrog-artifactory-jcr-${JCR_VERSION}-linux.tar.gz"
JCR_NAME="artifactory-jcr-${JCR_VERSION}"
JCR_HOME="/opt/jfrog"
DATABASE_URL="localhost:5432"
DATABASE_USERNAME="artifactory_jrc"
DATABASE_PASSWORD="noreyni"

SSL_DIR="/etc/nginx/ssl"
SSL_CERTIFICATE_PATH="$SSL_DIR/artifactory_jrc.crt"
SSL_KEY_PATH="$SSL_DIR/artifactory_jrc.key"
STATE="Senegal"
ORGANIZATION="Noreyni"
UNIT="Software &Devops Engineer"
SERVICE_CONFIG_FILE="artifactory_jrc.conf"
PROXY_PASS_URL="http://127.0.0.1:8082/"
USER="artifactory"
GROUP="artifactory"


# Function to setup Artifactory as a service
setup_artifactory_jrc_service() {
    sudo $JCR_HOME/$JCR_NAME/app/bin/installService.sh
    sleep 5
    # Set permissions for the artifactory user on JCR_HOME
    sudo chown -R $USER:$GROUP "$JCR_HOME"

    # Set ownership for specific directories (including /opt/jfrog/artifactory-jcr-7.77.6/var)
    sudo chown -R $USER:$GROUP $JCR_HOME/$JCR_NAME/var

    # Set permissions for the entire JCR_HOME directory
    sudo chmod -R 755 "$JCR_HOME"

    # Start Artifactory
    sudo systemctl start artifactory.service

}

setup_jfrog_home() {
    # Create a JFrog Home directory and move the downloaded installer archive into that directory.
    sudo mkdir -p "$JCR_HOME"
    cd "$JCR_HOME"
    sudo wget "https://releases.jfrog.io/artifactory/bintray-artifactory/org/artifactory/jcr/jfrog-artifactory-jcr/$JCR_VERSION/$JCR_TAR" -O "$JCR_TAR"
    sudo tar -xzf "$JCR_TAR"
    sudo rm -rf $JCR_HOME/$JCR_TAR

    # Set the JFrog Home environment variable.
    echo 'export JFROG_HOME="/opt/jfrog"' | sudo tee -a /etc/environment
}

# update the operating system
update_os

OS=$(getOs)

# Install net-tools if the OS is Ubuntu
if [ "$os" = "ubuntu" ]; then
    echo "Detected Ubuntu. Installing net-tools..."
    sudo apt-get install -y net-tools
    if ! command -v netstat &> /dev/null; then
        echo "Failed to install net-tools. Please check the installation steps." >&2
        exit 1
    fi
fi

# Run Java installation
install_java "17"

# Create a JFrog Home directory and move the downloaded installer archive into that directory.
setup_jfrog_home


# Setup Artifactory service
setup_artifactory_jrc_service
sleep 1

# Run the SSL directory creation:
create_ssl_directory "$SSL_DIR" "$USER" "$GROUP"

# Run the SSL certificate generation
generate_ssl_certificates "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$STATE" "$ORGANIZATION" "$UNIT"

# Run the Nginx installation and configuration
setup_nginx_installation_configuration "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$SERVICE_CONFIG_FILE" "$PROXY_PASS_URL"


sudo systemctl daemon-reload


sudo systemctl restart artifactory
success "JFrog Container Repository has been successfully installed and configured with Nginx as a reverse proxy with SSL."
# Log IP address
success "the Username is: admin and the Password: password"
successWithUrlLink "Access Jfrog Container Repository via" "https://$IP_ADDRESS"
sudo systemctl status artifactory.service
sudo journalctl -xeu artifactory.service