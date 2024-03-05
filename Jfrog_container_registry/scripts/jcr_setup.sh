#!/bin/bash

# Set variables
JCR_VERSION="7.77.6"
JCR_TAR="jfrog-artifactory-jcr-${JCR_VERSION}-linux.tar.gz"
JCR_NAME="artifactory-jcr-${JCR_VERSION}"
JCR_HOME="/opt/jfrog"
DATABASE_URL="localhost:5432"
DATABASE_USERNAME="artifactory_jrc"
DATABASE_PASSWORD="noreyni"
USER="artifactory"
GROUP="artifactory"
SSL_DIR="/etc/ssl/private/"
SSL_CERT="$SSL_DIR/artifactory_jrc.crt"
SSL_KEY="$SSL_DIR/artifactory_jrc.key"
SERVER_IP="192.168.56.21"

# Function to detect the operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        # Modern Linux distributions use /etc/os-release
        source /etc/os-release
        OS=$ID
    elif [ -f /etc/lsb-release ]; then
        # Older distributions might have /etc/lsb-release
        source /etc/lsb-release
        OS=$DISTRIB_ID
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

# Function to install required packages on CentOS
install_centos() {
    sudo yum update -y
    sudo yum clean metadata
    sudo yum install -y java-17-openjdk nginx
}

# Function to install required packages on Ubuntu/Debian
install_debian() {
    sudo apt-get update -y
    sudo apt-get install -y openjdk-17-jdk nginx
}

# Function to create SSL directory
create_ssl_directory() {
    if [ ! -d "$SSL_DIR" ]; then
        echo "Creating SSL directory..."
        sudo mkdir -p "$SSL_DIR"
        sudo chown -R "$USER:$USER" "$SSL_DIR"
        sudo chmod 700 "$SSL_DIR"
        echo "SSL directory created."
    fi
}

# Function to generate self-signed SSL certificates
generate_ssl_certificates() {
    if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
        echo "Generating self-signed SSL certificates..."
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$SSL_KEY" -out "$SSL_CERT" -subj "/C=US/ST=Senegal/L=Dakar/O=Noreyni/OU=Noreyni/CN=$SERVER_IP"
        sudo chmod 600 "$SSL_KEY"
        echo "SSL certificates generated successfully."
    fi
}

# Function to configure Nginx on CentOS
configure_nginx_centos() {
    sudo tee /etc/nginx/conf.d/artifactory.conf <<EOF
server {
    listen 80;
    server_name $SERVER_IP;

    location / {
        proxy_pass http://127.0.0.1:8082/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name $SERVER_IP;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

    location / {
        proxy_pass http://127.0.0.1:8082/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    sudo nginx -t
    sudo systemctl restart nginx
}

# Function to configure Nginx on Ubuntu/Debian
configure_nginx_debian() {
    sudo tee /etc/nginx/sites-available/artifactory <<EOF
server {
    listen 80;
    server_name $SERVER_IP;

    location / {
        proxy_pass http://127.0.0.1:8082/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name $SERVER_IP;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

    location / {
        proxy_pass http://127.0.0.1:8082/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    sudo ln -s /etc/nginx/sites-available/artifactory /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
}

# Function to install Artifactory as a service
install_artifactory_jrc_service() {
    sudo $JFROG_HOME/$JCR_NAME/app/bin/installService.sh
    sleep 5
    # Set permissions for the artifactory user on JFROG_HOME
    sudo chown -R $USER:$GROUP "$JFROG_HOME"

    # Set ownership for specific directories (including /opt/jfrog/artifactory-oss-7.77.6/var)
    sudo chown -R $USER:$GROUP $JFROG_HOME/$JCR_NAME/var

    # Set permissions for the entire JFROG_HOME directory
    sudo chmod -R 755 "$JFROG_HOME"

    # Start Artifactory
    sudo systemctl start artifactory.service

}

# Main script
detect_os

case "$OS" in
    "centos" | "rhel")
        install_centos
        create_ssl_directory
        generate_ssl_certificates
        configure_nginx_centos
        ;;
    "debian" | "ubuntu")
        install_debian
        create_ssl_directory
        generate_ssl_certificates
        configure_nginx_debian
        ;;
    *)
        echo "Unsupported operating system."
        exit 1
        ;;
esac

# Create a JFrog Home directory and move the downloaded installer archive into that directory.
sudo mkdir -p "$JCR_HOME"
cd "$JCR_HOME"
sudo wget "https://releases.jfrog.io/artifactory/bintray-artifactory/org/artifactory/jcr/jfrog-artifactory-jcr/$JCR_VERSION/$JCR_TAR" -O "$JCR_TAR"
sudo tar -xzf "$JCR_TAR"
sudo rm -rf $JCR_HOME/$JCR_TAR

# Set the JFrog Home environment variable.
echo 'export JFROG_HOME="/opt/jfrog"' | sudo tee -a /etc/environment

# Customize the production configuration (optional) including database, Java Opts, and filestore.
#
# if [ -f "setup_postgresql.sh" ]; then
#         source "setup_postgresql.sh" "jcr"
# else
# coming

# Install Artifactory jrc service
install_artifactory_jrc_service

#restart service nginx
sudo systemctl restart nginx

echo "JFrog Container Registry has been successfully installed and configured with Nginx as a reverse proxy with SSL."
