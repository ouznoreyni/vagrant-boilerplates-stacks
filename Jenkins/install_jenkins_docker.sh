#!/bin/bash

# Function to check if a command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Docker Compose if not installed
if ! command_exists docker-compose; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "Docker Compose installed successfully."
fi

# Function to install Docker on CentOS
install_docker_centos() {
    echo "Installing Docker on CentOS..."
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo -y
    sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    sudo systemctl start docker
    echo "Docker installed successfully."
}

# Function to install Docker on Debian/Ubuntu
install_docker_debian_ubuntu() {
    echo "Installing Docker on Debian/Ubuntu..."
    sudo apt-get update
    sudo apt-get install ca-certificates curl -y
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    echo "Docker installed successfully."
}

# Function to create SSL directory if not exist
create_ssl_directory() {
    SSL_DIR="./ssl/"
    if [ ! -d "$SSL_DIR" ]; then
        echo "Creating SSL directory..."
        mkdir -p "$SSL_DIR"
        echo "SSL directory created."
    fi
}

# Function to generate a self-signed SSL certificate and private key
generate_ssl_certificates() {
    echo "Generating self-signed SSL certificates..."

    SSL_CERT="./ssl/jenkins.crt"
    SSL_KEY="./ssl/jenkins.key"

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$SSL_KEY" -out "$SSL_CERT" -subj "/C=US/ST=YourState/L=YourCity/O=YourOrganization/OU=YourUnit/CN=192.168.56.10"

    echo "SSL certificates generated successfully."
}

# Check if Docker is installed
if ! command_exists docker; then
    if [ -f /etc/redhat-release ]; then
        install_docker_centos
    elif [ -f /etc/debian_version ]; then
        install_docker_debian_ubuntu
    else
        echo "Unsupported operating system"
        exit 1
    fi
fi

# Check and create SSL directory
create_ssl_directory

# Generate SSL certificates
generate_ssl_certificates

# Create Docker volumes for Jenkins and Portainer
docker volume create jenkins_home
docker volume create portainer_data

# Docker-compose file
cat <<EOL > docker-compose.yml
version: '3'
services:
  jenkins:
    image: jenkins/jenkins:lts
    ports:
      - "8080:8080"
    volumes:
      - jenkins_home:/var/jenkins_home
    networks:
      - jenkins_network
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./ssl:/etc/ssl/private
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - jenkins
      - portainer
    networks:
      - jenkins_network
  portainer:
    image: portainer/portainer-ce:latest
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - jenkins_network

networks:
  jenkins_network:
    driver: bridge

volumes:
  jenkins_home:
  portainer_data:
EOL

# Nginx configuration
cat <<EOL > nginx.conf
server {
    listen 80;
    #server_name 192.168.56.10;
    # Redirect HTTP to HTTPS
    server_name _;
    return 301 https://$server_name$request_uri;
    # location / {
    #     proxy_pass http://jenkins:8080;
    #     proxy_set_header Host \$host;
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    #     proxy_set_header X-Forwarded-Proto \$scheme;
    # }

    # location /portainer/ {
    #     rewrite ^/portainer(/.*)$ \$1 break;
    #     proxy_pass http://portainer:9000;
    #     proxy_set_header Host \$host;
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    #     proxy_set_header X-Forwarded-Proto \$scheme;
    # }
}

server {
    listen 443 ssl;
    server_name 192.168.56.10;

    ssl_certificate /etc/ssl/private/jenkins.crt;
    ssl_certificate_key /etc/ssl/private/jenkins.key;

    location / {
        proxy_pass http://jenkins:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /portainer/ {
        rewrite ^/portainer(/.*)$ \$1 break;
        proxy_pass http://portainer:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Add the vagrant user to the docker group
sudo usermod -aG docker vagrant

# Log out and log back in to apply group changes
# Alternatively, you can restart the VM
# This step may vary based on your specific system

# Ensure docker-compose is in the sudo user's PATH
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Check if Jenkins is already running
if ! docker ps -a --format '{{.Names}}' | grep -q '^jenkins$'; then
    # If not running, start Jenkins, Nginx, and Portainer
    echo "Starting Jenkins, Nginx, and Portainer..."
    docker-compose up -d
    echo "Jenkins, Nginx, and Portainer started successfully."
else
    echo "Jenkins is already running."
fi
