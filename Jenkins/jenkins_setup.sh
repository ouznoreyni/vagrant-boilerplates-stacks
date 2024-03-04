#!/bin/bash

# Function to create SSL directory if not exist
create_ssl_directory() {
    SSL_DIR="/etc/ssl/private/"
    if [ ! -d "$SSL_DIR" ]; then
        echo "Creating SSL directory..."
        sudo mkdir -p "$SSL_DIR"
        sudo chown -R "$USER:$USER" "$SSL_DIR"
        sudo chmod 700 "$SSL_DIR"
        echo "SSL directory created."
    fi
}

# Function to generate a self-signed SSL certificate and private key
generate_ssl_certificates() {
    echo "Generating self-signed SSL certificates..."

    SSL_CERT="/etc/ssl/private/jenkins.crt"
    SSL_KEY="/etc/ssl/private/jenkins.key"

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$SSL_KEY" -out "$SSL_CERT" -subj "/C=US/ST=YourState/L=YourCity/O=YourOrganization/OU=YourUnit/CN=192.168.56.10"

    sudo chmod 600 "$SSL_KEY"

    echo "SSL certificates generated successfully."
}

# Check and create SSL directory
create_ssl_directory

# Generate SSL certificates
generate_ssl_certificates

# Check the OS type
if [ -f /etc/redhat-release ]; then
    OS="centos"
    PACKAGE_MANAGER="yum"
    NGINX_CONFIG_DIR="/etc/nginx/conf.d"
    NGINX_SERVICE="nginx"
    NGINX_CONF_FILE="${NGINX_CONFIG_DIR}/jenkins.conf"
    JENKINS_SERVICE="jenkins"
elif [ -f /etc/lsb-release ]; then
    OS="debian"
    PACKAGE_MANAGER="apt-get"
    NGINX_CONFIG_DIR="/etc/nginx/sites-available"
    NGINX_SERVICE="nginx"
    NGINX_CONF_FILE="${NGINX_CONFIG_DIR}/jenkins"
    JENKINS_SERVICE="jenkins"
else
    echo "Unsupported operating system"
    exit 1
fi

# Install Jenkins based on the OS type
if [ "$OS" == "centos" ]; then
    sudo wget -O /etc/yum.repos.d/jenkins.repo \
        https://pkg.jenkins.io/redhat-stable/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    sudo $PACKAGE_MANAGER upgrade -y
    sudo $PACKAGE_MANAGER install -y fontconfig java-17-openjdk jenkins
    sudo systemctl daemon-reload
elif [ "$OS" == "debian" ]; then
    sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
        https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
        | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo $PACKAGE_MANAGER update
    sudo $PACKAGE_MANAGER install -y fontconfig openjdk-17-jre jenkins
fi

# Install Nginx
sudo $PACKAGE_MANAGER install -y nginx

# Configure Jenkins as a service
sudo systemctl enable $JENKINS_SERVICE
sudo systemctl start $JENKINS_SERVICE

# Configure Nginx as a reverse proxy for Jenkins
sudo tee $NGINX_CONF_FILE > /dev/null <<EOF
server {
    listen 80;
    server_name 192.168.56.10;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name 192.168.56.10;

    ssl_certificate /etc/ssl/private/jenkins.crt;
    ssl_certificate_key /etc/ssl/private/jenkins.key;

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
sudo systemctl enable $NGINX_SERVICE
sudo systemctl start $NGINX_SERVICE

# If HTTPS is enabled, redirect HTTP to HTTPS
sudo tee -a $NGINX_CONF_FILE > /dev/null <<EOF
server {
    listen 80;
    server_name 192.168.56.10;
    return 301 https://\$host\$request_uri;
}
EOF

# Reload Nginx
sudo systemctl reload $NGINX_SERVICE

echo "Jenkins and Nginx have been configured successfully."
