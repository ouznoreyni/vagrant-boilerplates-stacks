#!/bin/bash

script_utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the utils functions
source $script_utils_dir/common_functions.sh

# Set variables
IP_ADDRESS="$1"
NEXUS_HOME="/opt/nexus"
NEXUS_TAR_NAME="nexus.tar.gz"
NEXUS_USER="nexus"
NEXUS_GROUP="nexus"
NEXUS_SERVICE_NAME="nexus"
NEXUS_URL="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
SSL_DIR="/etc/ssl/private"
SSL_CERTIFICATE_PATH="$SSL_DIR/nexus.crt"
SSL_KEY_PATH="$SSL_DIR/nexus.key"
STATE="Senegal"
ORGANIZATION="Noreyni"
UNIT="Software &Devops Engineer"
SERVICE_CONFIG_FILE="NEXUS.conf"
PROXY_PASS_URL="http://127.0.0.1:8081/"
NEXUS_PORT="8081"
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

    install_java "11"
    #setup_postgresql_user_and_db  $DATABASE_USERNAME $DATABASE_PASSWORD $DATABASE_NAME
}

# Function t and install Nexus
download_nexus() {
    info "Downlaoding nexus..."
    sudo mkdir -p "$NEXUS_HOME"
    cd "$NEXUS_HOME"
    wget $NEXUS_URL -O $NEXUS_TAR_NAME
    sleep 10
    # Extract Nexus directly into $NEXUS_HOME(/opt/nexus/)
    EXTOUT=$(tar xzvf $NEXUS_TAR_NAME)
    NEXUS_DIR=$(echo $EXTOUT | cut -d '/' -f1)
    sleep 5

    # Clean up
    sudo rm -rf $NEXUS_TAR_NAME
}

# Function to set permissions for nexus
set_sonar_permissions() {
    info "setting permission nexus..."
    sleep 5
    useradd $NEXUS_USER
    chown -R $NEXUS_USER.$NEXUS_GROUP $NEXUS_HOME
    success "Permissions set for Nexus"
}

# Function to comment out the specified line in nexus.vmoptions
comment_line_in_vmoptions() {
    file="$NEXUS_HOME/$NEXUS_DIR/bin/nexus.vmoptions"
    line_to_comment="-Djava.endorsed.dirs=lib/endorsed"

    # Check if the file exists
    if [ ! -f "$file" ]; then
        error "Error: File $file not found."
        # exit 1
    fi

    # Check if the line is already commented
    if grep -q "^$line_to_comment" "$file"; then
        warning "Line is already commented."
    fi

    # Comment out the line
    sed -i "s|^$line_to_comment|# $line_to_comment|" "$file"
    success "Line commented successfully."
}

## Function to setup firewall rules and SELinux permissions
configure_firewall_and_selinux() {
    if [ "$OS" == "centos" ]; then
        # Open ports 80, 443, and the Nexus port
        sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
        sudo firewall-cmd --zone=public --add-port=443/tcp --permanent

        # Reload firewall
        sudo firewall-cmd --reload

        # Enable SELinux to allow the Nexus port
        sudo setsebool -P httpd_can_network_connect on

        success "Firewall enabled, ports 80, 443 opened, and SELinux configured."
    elif [ "$OS" == "ubuntu" ]; then
        # Open ports 80, 443, and the Nexus port
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp

        # Reload firewall
        sudo ufw reload

        success "Firewall enabled, ports 80 and 443 opened."
    else
        error "Unsupported operating system."
    fi
}

# Function to restart SonarQube and Nginx services
restart_services() {
    info "Starting|Restarting nexus services..."
    echo "run_as_user=$NEXUS_USER" >$NEXUS_HOME/$NEXUS_DIR/bin/nexus.rc
    sleep 5
    sudo systemctl daemon-reload
    sudo systemctl start nexus
    sudo systemctl enable nexus
    info "Restarting Nginx service..."
    sudo systemctl start nginx
    sudo systemctl enable nginx
    success "Services restarted successfully!"
}

# Function to wait for the Nexus admin.password file
wait_for_admin_password() {
    info "Waiting for Nexus to generate the admin.password file..."
    local timeout=60  # 60 seconds timeout
    local interval=10 # Check every 10 seconds
    local elapsed=0
    local password_file="$NEXUS_HOME/sonatype-work/nexus3/admin.password"
    FILE_FOUND=false

    while [ ! -f "$password_file" ]; do
        sleep $interval
        elapsed=$((elapsed + interval))
        if [ $elapsed -ge $timeout ]; then
            # warning "admin.password file not found within 60 seconds."
            break
        fi
    done

    if [ -f "$password_file" ]; then
        FILE_FOUND=true
        success "admin.password file generated."
    else
        warning "admin.password file not found after waiting 30 seconds."
    fi
}

#*************************  Execute functions in order **************************
update_os
install_packages
download_nexus
set_sonar_permissions
create_systemd_service "nexus" "nexus service" "$NEXUS_HOME/$NEXUS_DIR/bin/nexus start" "$NEXUS_HOME/$NEXUS_DIR/bin/nexus stop" "$NEXUS_USER" "$NEXUS_GROUP"
create_ssl_directory "$SSL_DIR" "$NEXUS_USER" "$NEXUS_GROUP"
generate_ssl_certificates "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$STATE" "$ORGANIZATION" "$UNIT"
setup_nginx_installation_configuration "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$SERVICE_CONFIG_FILE" "$PROXY_PASS_URL"
comment_line_in_vmoptions
configure_firewall_and_selinux
restart_services
sleep 10

info "wating to get the admin password max 60 secondes"
wait_for_admin_password

# Log message to access Nexus via IP
successWithUrlLink "Nexus can be accessed at " "https://$IP_ADDRESS"

# Check if the file was found and handle the success message
if [ "$FILE_FOUND" = true ]; then
    PASSWORD=$(cat "$NEXUS_HOME/sonatype-work/nexus3/admin.password")
    success "username: admin, password: $PASSWORD"
else
    info "the admin password is  at : /opt/nexus/sonatype-work/nexus3/admin.password"

fi
