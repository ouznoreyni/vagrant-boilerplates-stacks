#!/bin/bash

log_info() {
  echo "[INFO] $1"
}

log_info "Installing yum-utils"
sudo yum install -y yum-utils

log_info "Adding HashiCorp repository"
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

log_info "Updating system packages"
sudo yum update -y

log_info "Installing openssl and Vault"
sudo yum -y install openssl vault

log_info "Generating certificates"
sudo mkdir -p /opt/vault/{tls,data}
cd /opt/vault/tls
sudo openssl req -out tls.crt -new -keyout tls.key -newkey rsa:4096 -nodes -sha256 -x509 -subj "/O=HashiCorp/CN=Vault" -addext "subjectAltName = IP:192.168.56.23" -days 3650

log_info "Creating Vault configuration file"
sudo tee /etc/vault/vault.hcl > /dev/null <<EOF
ui = true

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/tls.crt"
  tls_key_file  = "/opt/vault/tls/tls.key"
}
EOF

log_info "Setting correct permissions"
sudo chown vault: /opt/vault/tls/*

log_info "Starting Vault service"
sudo systemctl start vault

log_info "Setting up environment variables"
export VAULT_ADDR='https://192.168.56.23:8200'
export VAULT_CACERT="/opt/vault/tls/tls.crt"

log_info "Initializing Vault"
vault operator init

log_info "Unsealing Vault"
vault operator unseal --ca-cert=/opt/vault/tls/tls.crt

log_info "Logging into Vault"
vault login

log_info "Refer to production hardening guide: https://learn.hashicorp.com/tutorials/vault/production-hardening"
