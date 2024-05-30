#!/bin/bash

#######################################
# Script to automate Jenkins and Nginx setup with SSL
#######################################
# Source the utility functions
script_utils_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the utils functions
source $script_utils_dir/common_functions.sh

# Verify that the functions are sourced correctly
declare -F create_ssl_directory
declare -F generate_ssl_certificates
declare -F setup_nginx_installation_configuration

# Variables for Jenkins setup
IP_ADDRESS="$1"
SSL_DIR="/etc/nginx/ssl"
SSL_CERTIFICATE_PATH="$SSL_DIR/jenkins.crt"
SSL_KEY_PATH="$SSL_DIR/jenkins.key"
STATE="Senegal"
ORGANIZATION="Noreyni"
UNIT="Software &Devops Engineer"
SERVICE_CONFIG_FILE="jenkins.conf"
PROXY_PASS_URL="http://localhost:8080"
USER="vagrant"
GROUP="vagrant"

# Function to install and configure Jenkins
install_configure_jenkins() {
    local package_manager=""
    local nginx_config_dir=""

    if [ "$(getOs)" == "centos" ]; then
        package_manager="yum"
        nginx_config_dir="/etc/nginx/conf.d"

        sudo wget -O /etc/yum.repos.d/jenkins.repo \
            https://pkg.jenkins.io/redhat-stable/jenkins.repo
        sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
        update_os
        sudo $package_manager install -y fontconfig java-17-openjdk jenkins
    elif [ "$(getOs)" == "ubuntu" ]; then
        package_manager="apt-get"
        nginx_config_dir="/etc/nginx/sites-available"
        sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
            https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
        echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
        sudo rm -rf /var/lib/apt/lists/*
        update_os
        sudo $package_manager install -y fontconfig openjdk-17-jre jenkins
    else
        error "Unsupported operating system"
        exit 1
    fi
    sudo systemctl enable jenkins
    sudo systemctl start jenkins

    success "Jenkins installed and configured successfully."
}

# update the operating system
update_os

# Run the SSL directory creation:
create_ssl_directory "$SSL_DIR" "$USER" "$GROUP"

# Run the SSL certificate generation
generate_ssl_certificates "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$STATE" "$ORGANIZATION" "$UNIT"

# Run the Nginx installation and configuration
setup_nginx_installation_configuration "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$SERVICE_CONFIG_FILE" "$PROXY_PASS_URL"
sleep 2

# Run the Jenkins installation and configuration
install_configure_jenkins

# Log successful configuration to IP server
success "Jenkins and Nginx have been successfully configured on the server with IP address $IP_ADDRESS."

# Output the content of initialAdminPassword
warning "Initial Admin Password: $(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"

warning "copy the admin password and use it to continue jenkins installation"

# Log IP address
successWithUrlLink "Access Jenkins via" "https://$IP_ADDRESS"