#!/bin/bash

# Function to log informational messages
log_info() {
  echo "[INFO] $1"
}

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
# sudo mkdir -p /etc/vault
cd /opt/vault/tls
sudo openssl req -out tls.crt -new -keyout tls.key -newkey rsa:4096 -nodes -sha256 -x509 -subj "/O=HashiCorp/CN=Vault" -addext "subjectAltName = IP:192.168.56.23,DNS:192.168.56.23" -days 3650

# Create Vault configuration file
log_info "Creating Vault configuration file"
# sudo tee /etc/vault/vault.hcl > /dev/null <<EOF
# ui = true
# api_addr = "http://127.0.0.1:8200"
# cluster_addr = "https://127.0.0.1:8201"

# storage "file" {
#   path = "/opt/vault/data"
# }

# listener "tcp" {
#   #address       = "[::]:8200"
#   address     = "127.0.0.1:8200"
#   tls_cert_file = "/opt/vault/tls/tls.crt"
#   tls_key_file  = "/opt/vault/tls/tls.key"
# }
# EOF

log_info "Appending api_addr and cluster_addr to Vault configuration file"
echo "api_addr = \"https:/192.168.56.23:8200\"" | sudo tee -a /etc/vault.d/vault.hcl > /dev/null
echo "cluster_addr = \"https:/192.168.56.23:8201\"" | sudo tee -a /etc/vault.d/vault.hcl > /dev/null

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

export VAULT_ADDR='https:/192.168.56.23:8200'
export VAULT_CACERT="/opt/vault/tls/tls.crt"

# either visit https://<IP>:8200 and enter values as 5 as number of keys and 3 keys needed to unseal or regenerate keys
# copy the root token & keys
vault operator init
