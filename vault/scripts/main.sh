#!/bin/bash
#!/bin/bash

script_utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the utils functions
source $script_utils_dir/common_functions.sh

# Set variables
IP_ADDRESS="$1"
VAULT_HOME="/opt/vault"
VAULT_USER="vault"
VAULT_GROUP="vault"
VAULT_SERVICE_NAME="vault"
SERVICE_CONFIG_FILE="vault.conf"
PROXY_PASS_URL="https://127.0.0.1:8200/"
VAULT_PORT="8200"
OS=$(getOs)

intial_setup() {
    # Append noreyni.local to hosts file
    info "Appending noreyni.local to hosts file"
    echo "127.0.0.0 noreyni.local" | sudo tee -a /etc/hosts >/dev/null
}

# Function to install vault on the operating system
install_vault() {
    if [ "$OS" == "centos" ]; then
        sudo yum install -y yum-utils openssl
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        sudo yum -y install vault
        success "vault installed successfully!"
    elif [ "$OS" == "ubuntu" ]; then
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install vault
        success "vault installed successfully!"
    else
        error "Unsupported operating system."
        exit 1
    fi
}

# setup openssl for Vault
setup_openssl() {
    info "Generating certificates"
    sudo mkdir -p $VAULT_HOME/{tls,data}
    cd $VAULT_HOME/tls
    sudo openssl req -out tls.crt -new -keyout tls.key -newkey rsa:4096 -nodes -sha256 -x509 -subj "/O=HashiCorp/CN=Vault" -addext "subjectAltName = IP:127.0.0.1,DNS:noreyni.local" -days 3650
}

create_vault_config() {
    info "Creating Vault configuration file"
    echo "api_addr = \"https://127.0.0.1:8200\"" | sudo tee -a /etc/vault.d/vault.hcl >/dev/null
    echo "cluster_addr = \"https://127.0.0.1:8201\"" | sudo tee -a /etc/vault.d/vault.hcl >/dev/null

    info "Setting permissions for Vault files"
    sudo chmod 640 /etc/vault.d/vault.hcl
}

reload_and_start_vault_service() {
    info "Reloading systemd daemon"
    sudo systemctl daemon-reload

    info "Enabling and starting Vault service"
    sudo systemctl enable --now vault
    service vault start
    # make sure DNS record is present, else TLS certificate verification will fail
    export VAULT_ADDR='https://127.0.0.1:8200'
    export VAULT_CACERT="$VAULT_HOME/tls/tls.crt"

}

vault_init() {

    sudo mkdir -p $VAULT_HOME
    sudo chown -R $VAULT_USER:$VAULT_GROUP $VAULT_HOME

    # either visit https://<IP>:8200 and enter values as 5 as the number of keys and 3 keys needed to unseal or regenerate keys
    # copy the root token & keys
    #vault operator init -format=json
    echo "$(vault operator init -format=json)" >$VAULT_HOME/init.log

    init "init.log content"
    sudo cat $VAULT_HOME/init.log

}

#*************************  Execute functions in order **************************
update_os
intial_setup
install_vault
setup_openssl
create_vault_config
reload_and_start_vault_service
setup_nginx_installation_configuration "$IP_ADDRESS" "$SSL_DIR" "$SSL_CERTIFICATE_PATH" "$SSL_KEY_PATH" "$SERVICE_CONFIG_FILE" "$PROXY_PASS_URL"
vault_init
