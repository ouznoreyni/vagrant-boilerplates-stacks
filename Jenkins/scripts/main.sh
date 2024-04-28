#!/bin/bash

#######################################
# Script to automate Jenkins and Nginx setup with SSL
#######################################

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to validate IP address
validate_ip_address() {
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if ! [[ "$1" =~ $ip_regex ]]; then
        echo -e "${RED}Error: Invalid IP address provided. Please provide a valid IP address.${NC}"
        exit 1
    fi
}

# Function to create SSL directory
create_ssl_directory() {
    local ssl_dir="/etc/ssl/private/"
    if [ ! -d "$ssl_dir" ]; then
        echo -e "${YELLOW}Creating SSL directory...${NC}"
        sudo mkdir -p "$ssl_dir"
        sudo chown -R "$USER:$USER" "$ssl_dir"
        sudo chmod 700 "$ssl_dir"
        echo -e "${GREEN}SSL directory created.${NC}"
    fi
}

# Function to generate a self-signed SSL certificate and private key
generate_ssl_certificates() {
    local ip_address="$1"
    local ssl_dir="/etc/ssl/private/"
    local ssl_certificate_path="${ssl_dir}jenkins.crt"
    local ssl_key_path="${ssl_dir}jenkins.key"
    local state="Senegal"
    local organization="Ouz Noreyni"
    local unit="Software Engineer"

    echo -e "${YELLOW}Generating self-signed SSL certificates...${NC}"

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_key_path" -out "$ssl_certificate_path" \
        -subj "/C=US/ST=$state/L=YourCity/O=$organization/OU=$unit/CN=$ip_address"

    sudo chmod 600 "$ssl_key_path"

    echo -e "${GREEN}SSL certificates generated successfully.${NC}"
}

# Function to install and configure Jenkins
install_configure_jenkins() {
    local package_manager=""
    local nginx_config_dir=""

    if [ -f /etc/redhat-release ]; then
        package_manager="yum"
        nginx_config_dir="/etc/nginx/conf.d"

        sudo wget -O /etc/yum.repos.d/jenkins.repo \
            https://pkg.jenkins.io/redhat-stable/jenkins.repo
        sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
        sudo $package_manager upgrade -y
        sudo $package_manager install -y fontconfig java-17-openjdk jenkins
        #sudo systemctl daemon-reload
    elif [ -f /etc/lsb-release ]; then
        package_manager="apt-get"
        nginx_config_dir="/etc/nginx/sites-available"
        sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
        https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
        sudo echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
        https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
        /etc/apt/sources.list.d/jenkins.list > /dev/null
        sudo rm -rf /var/lib/apt/lists/*
        sudo $package_manager update -y
        sudo $package_manager install -y fontconfig  openjdk-17-jre jenkins
    else
        echo -e "${RED}Unsupported operating system${NC}"
        exit 1
    fi

    # Configure Jenkins as a service
    sudo systemctl daemon-reload
    sudo systemctl enable jenkins
    sudo systemctl start jenkins

    echo -e "${GREEN}Jenkins installed and configured successfully.${NC}"
}

# Function to install and configure Nginx as a reverse proxy for Jenkins
install_configure_nginx() {
    local ip_address="$1"
    local ssl_dir="/etc/ssl/private/"
    local ssl_certificate_path="${ssl_dir}jenkins.crt"
    local ssl_key_path="${ssl_dir}jenkins.key"
    local package_manager=""
    local nginx_config_dir=""

    if [ -f /etc/redhat-release ]; then
        package_manager="yum"
        nginx_config_dir="/etc/nginx/conf.d"
    elif [ -f /etc/lsb-release ]; then
        package_manager="apt-get"
        nginx_config_dir="/etc/nginx/sites-available"
    else
        echo -e "${RED}Unsupported operating system${NC}"
        exit 1
    fi

    # Install Nginx
    sudo $package_manager install -y nginx

    # Configure Nginx as a reverse proxy for Jenkins
    sudo tee "${nginx_config_dir}/jenkins.conf" > /dev/null <<EOF
server {
    listen 80;
    server_name $ip_address;
    return 301 https://$ip_address\$request_uri;
}

server {
    listen 443 ssl;
    server_name $ip_address;

    ssl_certificate $ssl_certificate_path;
    ssl_certificate_key $ssl_key_path;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Enable and start Nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx

    # If HTTPS is enabled, redirect HTTP to HTTPS
    sudo tee -a "${nginx_config_dir}/jenkins.conf" > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}
EOF


   # Create symbolic link if nginx_config_dir exists (for non-Ubuntu systems)
    if [ -d "$nginx_config_dir" ] && [ ! -f /etc/redhat-release ]; then
        sudo ln -s "${nginx_config_dir}/jenkins.conf" /etc/nginx/sites-enabled/
    fi

    # Reload Nginx
    sudo systemctl reload nginx

    echo -e "${GREEN}Nginx installed and configured as a reverse proxy for Jenkins.${NC}"
}

# Main script execution
main() {
    local ip_address="$1"

    # Validate IP address
    validate_ip_address "$ip_address"

    # Create SSL directory
    create_ssl_directory

    # Generate SSL certificates
    generate_ssl_certificates "$ip_address"

    # Install and configure Jenkins
    install_configure_jenkins

    # Install and configure Nginx as a reverse proxy for Jenkins
    install_configure_nginx "$ip_address"

    # Log IP address
    echo -e "${GREEN}Access Jenkins via: https://$ip_address${NC}"

    # Output the content of initialAdminPassword
    echo -e "${YELLOW}Initial Admin Password:${NC} $(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"

    # Log successful configuration to IP server
    echo -e "${GREEN}Jenkins and Nginx have been successfully configured on the server with IP address $ip_address.${NC}"
}

# Check if IP address is provided as an argument
if [ -z "$1" ]; then
    echo -e "${RED}Error: IP address argument is missing.${NC}"
    echo "Usage: $0 <ip_address>"
    exit 1
fi

# Call the main function
main "$1"