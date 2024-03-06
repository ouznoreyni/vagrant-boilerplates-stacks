#!/bin/bash

# Set variables
SONAR_VERSION="10.4.1.88267"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_NAME="sonarqube-${SONAR_VERSION}"
SONAR_HOME="/opt/sonarqube"
DATABASE_NAME="sonarqube"
DATABASE_URL="jdbc:postgresql://localhost/${DATABASE_NAME}"
DATABASE_USERNAME="sonarqube"
DATABASE_PASSWORD="noreyni"
USER="sonarqube"
GROUP="sonarqube"
SSL_DIR="/etc/ssl/private/"
SSL_CERT="$SSL_DIR/sonarqube.crt"
SSL_KEY="$SSL_DIR/sonarqube.key"
SERVER_IP="192.168.56.22"


cp /etc/sysctl.conf /root/sysctl.conf_backup
cat <<EOT> /etc/sysctl.conf
vm.max_map_count=524288
fs.file-max=131072
ulimit -n 131072
ulimit -u 8192
EOT
cp /etc/security/limits.conf /root/sec_limit.conf_backup
cat <<EOT> /etc/security/limits.conf
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
EOT



# Install required packages
sudo yum update -y
sudo yum clean metadata
sudo yum install -y java-17-openjdk nginx zip

# Download and unzip SonarQube
sudo mkdir -p "$SONAR_HOME"
cd "$SONAR_HOME"
sudo wget "https://binaries.sonarsource.com/Distribution/sonarqube/$SONAR_ZIP" -O "$SONAR_ZIP"
sudo unzip -o $SONAR_ZIP -d $SONAR_HOME
sudo rm -rf $SONAR_ZIP

# Create sonarqube group and user
sudo groupadd $GROUP
sudo useradd -r -d $SONAR_HOME -g $GROUP $USER

# Change ownership of SonarQube directory
sudo chown -R $USER:$GROUP $SONAR_HOME

# Set permissions for the entire SONAR_HOME directory
sudo chmod -R 755 "$SONAR_HOME"

#backup existing conf
cp $SONAR_HOME/$SONAR_NAME/conf/sonar.properties $SONAR_HOME/sonar.properties_backup
cat <<EOT> $SONAR_HOME/$SONAR_NAME/conf/sonar.properties
sonar.jdbc.username=$DATABASE_USERNAME
sonar.jdbc.password=$DATABASE_PASSWORD
sonar.jdbc.url=$DATABASE_URL 
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT


#setup postgres
# Get the absolute path to the script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$script_dir/install_postgresql.sh" 
sleep 2
create_postgresql_db_user $DATABASE_NAME $DATABASE_USERNAME $DATABASE_PASSWORD
echo "************************** create_postgresql_db_user finished **************************"
sleep 5
cat <<EOT> /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=$SONAR_HOME/$SONAR_NAME/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_HOME/$SONAR_NAME/bin/linux-x86-64/sonar.sh stop

User=$USER
Group=$GROUP
Restart=always

LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOT


# Function to create SSL directory
echo "Creating SSL directory..."
sudo mkdir -p "$SSL_DIR"
sudo chown -R "$USER:$USER" "$SSL_DIR"
sudo chmod 700 "$SSL_DIR"
echo "SSL directory created."

# Function to generate self-signed SSL certificates
echo "Generating self-signed SSL certificates..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$SSL_KEY" -out "$SSL_CERT" -subj "/C=US/ST=Senegal/L=Dakar/O=Noreyni/OU=Noreyni/CN=$SERVER_IP"
sudo chmod 600 "$SSL_KEY"
echo "SSL certificates generated successfully."

# Function to configure Nginx on CentOS
sudo tee /etc/nginx/conf.d/sonarqube.conf <<EOF
server {
    listen 80;
    server_name $SERVER_IP;

    location / {
        proxy_pass http://127.0.0.1:9000/;
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
        proxy_pass http://127.0.0.1:9000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo nginx -t
systemctl daemon-reload
systemctl enable sonarqube.service
systemctl start sonarqube.service
sudo systemctl restart nginx