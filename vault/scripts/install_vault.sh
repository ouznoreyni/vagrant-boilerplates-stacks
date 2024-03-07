#!/bin/bash

# Function to log informational messages
log_info() {
  echo "[INFO] $1"
}

# Append noreyni.local to hosts file
log_info "Appending noreyni.local to hosts file"
echo "127.0.0.0 noreyni.local" | sudo tee -a /etc/hosts > /dev/null

# Install required packages
log_info "Installing yum-utils"
sudo yum install -y yum-utils

# Add HashiCorp repository
log_info "Adding HashiCorp repository"
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

# Update system packages
log_info "Updating system packages"
sudo yum update -y

# Install openssl and Vault
log_info "Installing openssl and Vault"
sudo yum -y install openssl vault

# Generate certificates
log_info "Generating certificates"
sudo mkdir -p /opt/vault/{tls,data}
cd /opt/vault/tls
sudo openssl req -out tls.crt -new -keyout tls.key -newkey rsa:4096 -nodes -sha256 -x509 -subj "/O=HashiCorp/CN=Vault" -addext "subjectAltName = IP:127.0.0.1,DNS:noreyni.local" -days 3650

# Create Vault configuration file
log_info "Creating Vault configuration file"
echo "api_addr = \"https://127.0.0.1:8200\"" | sudo tee -a /etc/vault.d/vault.hcl > /dev/null
echo "cluster_addr = \"https://127.0.0.1:8201\"" | sudo tee -a /etc/vault.d/vault.hcl > /dev/null

# Set correct permissions for Vault files
log_info "Setting permissions for Vault files"
sudo chown -R vault:vault /opt/vault
sudo chmod 640 /etc/vault.d/vault.hcl

# Reload systemd configuration
log_info "Reloading systemd daemon"
sudo systemctl daemon-reload

# Enable and start Vault service
log_info "Enabling and starting Vault service"
sudo systemctl enable --now vault

service vault start

# make sure DNS record is present, else TLS certificate verification
# will fail

export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_CACERT="/opt/vault/tls/tls.crt"

# either visit https://<IP>:8200 and enter values as 5 as the number of keys and 3 keys needed to unseal or regenerate keys
# copy the root token & keys
#vault operator init -format=json
echo "$(vault operator init -format=json)" > /opt/vault/init.log


#vault operator init  > /opt/vault/init.log

log_info "init.log content"
sudo cat /opt/vault/init.log

log_info "finshed"