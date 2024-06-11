#!/bin/bash
#######################################
# Script to automate Sonarqube,  Nginx setup with SSL
#######################################

# Source the utility functions
script_utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the utils functions
source $script_utils_dir/common_functions.sh

# Set variables
IP_ADDRESS="$1"
SONAR_VERSION="10.4.1.88267"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_FOLDER_NAME="sonarqube-${SONAR_VERSION}"
SONAR_HOME="/opt/sonarqube"
DATABASE_NAME="sonarqube"
#DATABASE_URL="jdbc:postgresql://localhost:5432/${DATABASE_NAME}""
SONAR_DATABASE_URL="jdbc:postgresql://localhost/${DATABASE_NAME}"
DATABASE_USERNAME="sonarqube"
DATABASE_PASSWORD="noreyni"
SONAR_USER="sonar"
SONAR_GROUP="sonar"
SSL_DIR="/etc/ssl/private"
SSL_CERTIFICATE_PATH="$SSL_DIR/sonarqube.crt"
SSL_KEY_PATH="$SSL_DIR/sonarqube.key"
STATE="Senegal"
ORGANIZATION="Noreyni"
UNIT="Software &Devops Engineer"
SERVICE_CONFIG_FILE="sonarqube.conf"
PROXY_PASS_URL="http://127.0.0.1:9000/"
SONAR_PORT="9000"
OS=$(getOs)

# Function to install required packages based on the operating system
install_packages() {
    if [ "$OS" == "centos" ]; then
        sudo yum install -y epel-release unzip
        success "unzip installed successfully!"
    elif [ "$OS" == "ubuntu" ]; then
        sudo apt-get install -y unzip
        success "unzip installed successfully!"
    else
        error "Unsupported operating system."
    fi

    install_java "17"
    setup_postgresql_user_and_db  $DATABASE_USERNAME $DATABASE_PASSWORD $DATABASE_NAME
}

# Function to configure sysctl and limits settings
configure_kernel_system_changes() {
    local sysctl_backup="/root/sysctl.conf_backup"
    local limits_backup="/root/sec_limit.conf_backup"

    # Backup and modify sysctl.conf
    sudo cp /etc/sysctl.conf "$sysctl_backup" && info "Backup of sysctl.conf created at $sysctl_backup"

    sudo bash -c 'cat <<EOT> /etc/sysctl.conf
vm.max_map_count=524288
fs.file-max=131072
#ulimit -n 131072
#ulimit -u 8192
EOT'
    success "sysctl.conf updated"

    # Backup and modify limits.conf
    sudo cp /etc/security/limits.conf "$limits_backup" && info "Backup of limits.conf created at $limits_backup"

    sudo bash -c 'cat <<EOT> /etc/security/limits.conf
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
EOT'
    success "limits.conf updated"

    #Reload system level changes without server boot
    sudo sysctl -p
    success "System level changes reloaded"

}

# Function to download and install SonarQube
download_sonarqube() {
    info "Downlaoding sonarque..."
    sudo mkdir -p "$SONAR_HOME"
    cd "$SONAR_HOME"
    sudo wget "https://binaries.sonarsource.com/Distribution/sonarqube/$SONAR_ZIP" -O "$SONAR_ZIP"
    sudo unzip -o $SONAR_ZIP -d $SONAR_HOME
    sudo rm -rf $SONAR_ZIP
}

# Function to set permissions for SonarQube
set_sonar_permissions() {
    sudo groupadd $SONAR_GROUP
    sudo useradd -M -c "SonarQube - User" -d "$SONAR_HOME/$SONAR_FOLDER_NAME" -g $SONAR_GROUP $SONAR_USER
    sudo chown -R $SONAR_USER:$SONAR_GROUP "$SONAR_HOME/$SONAR_FOLDER_NAME"
    success "Permissions set for SonarQube"
}

# Function to configure SonarQube
configure_sonarqube() {
    sudo cp "$SONAR_HOME/$SONAR_FOLDER_NAME/conf/sonar.properties" /root/sonar.properties_backup
    sudo tee "$SONAR_HOME/$SONAR_FOLDER_NAME/conf/sonar.properties" > /dev/null <<EOT
sonar.jdbc.username=$DATABASE_NAME
sonar.jdbc.password=$DATABASE_PASSWORD
sonar.jdbc.url=$SONAR_DATABASE_URL
sonar.web.host=0.0.0.0
sonar.web.port=$SONAR_PORT
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT
    success "SonarQube configuration updated"
}

# Function to restart SonarQube and Nginx services
restart_services() {
    info "Restarting SonarQube service..."
    sleep 3
    systemctl daemon-reload
    sudo systemctl restart sonarqube

    info "Restarting Nginx service..."
    sudo systemctl restart nginx
    success "Services restarted successfully!"
}

# Enable firewall and allow access to SonarQube port
enable_firewall() {
    if [ "$OS" == "centos" ]; then
        sudo firewall-cmd --zone=public --add-port=$SONAR_PORT/tcp --permanent
        sudo firewall-cmd --reload
        success "Firewall enabled and SonarQube port opened."
    elif [ "$OS" == "ubuntu" ]; then
        sudo ufw allow $SONAR_PORT/tcp
        sudo ufw reload
        success "Firewall enabled and SonarQube port opened."
    else
        error "Unsupported operating system."
    fi
}


#*************************  Execute functions in order **************************
configure_kernel_system_changes
update_os
install_packages
configure_postgres_md5_authentication
download_sonarqube
set_sonar_permissions
configure_sonarqube
create_systemd_service "sonarqube" "SonarQube service" "$SONAR_HOME/$SONAR_FOLDER_NAME/bin/linux-x86-64/sonar.sh start" "$SONAR_HOME/$SONAR_FOLDER_NAME/bin/linux-x86-64/sonar.sh stop" "$SONAR_USER" "$SONAR_GROUP"
create_ssl_directory "$SSL_DIR" "$USER" "$GROUP"
generate_ssl_certificates "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$STATE" "$ORGANIZATION" "$UNIT"
setup_nginx_installation_configuration "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$SERVICE_CONFIG_FILE" "$PROXY_PASS_URL"
restart_services
#enable_firewall
# Log message to access SonarQube via IP
success "the Username is: admin and the Password: admin"
successWithUrlLink "ASonarQube can be accessed at " "https://$IP_ADDRESS"
