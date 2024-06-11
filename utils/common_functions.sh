#!/bin/bash

## Colors
# Define color codes for better visual representation of outputs
## Colors
R="\e[31m"
B="\e[34m"
Y="\e[33m"
G="\e[32m"
BU="\e[1;4m"
BD="\e[1m"
BLU="\e[1;34m"
U="\e[4m"
IU="\e[7m"
LU="\e[2m"
N="\e[0m"
### Print Functions

# Function to print informational messages
info() {
    echo -e "${B}ℹ  info: $1$N "
}
export -f info

# Function to print warning messages
warning() {
    echo -e "${Y}⚠  Warning: $1$N "
}
export -f warning

# Function to print success messages
success() {
    echo -e "${G}✔  Susccess: $1$N"
}

export -f success

# Define the success function
successWithUrlLink() {
    echo -e "${G}✔  Susccess: $1: \e]8;;$2\a$2\e]8;;\a$N"
}
export -f successWithUrlLink

# Function to print error messages
error() {
    echo -e "${R}✗  Error: $1$N"
}

export -f error

# Function to get the operating system
getOs() {
    if [ -f /etc/redhat-release ]; then
        echo "centos"
    elif [ -f /etc/lsb-release ]; then
        echo "ubuntu"
    else
        error "Unsupported operating system"
        exit 1
    fi
}

export -f getOs

# Function to update the operating system
update_os() {
    local os=$(getOs)
    if [ "$os" = "ubuntu" ]; then
        sudo apt-get update -y
        #    sudo apt-get upgrade -y
    elif [ "$os" = "centos" ]; then
        sudo yum update -y
        #    sudo yum upgrade -y
    else
        echo "Unsupported operating system"
        exit 1
    fi
}
export -f update_os

# Function to detect the package manager and Nginx config directory
detect_package_manager() {
    local os=$(getOs)
    local package_manager=""
    local nginx_config_dir=""

    case "$os" in
    centos)
        package_manager="yum"
        nginx_config_dir="/etc/nginx/conf.d"
        ;;
    ubuntu)
        package_manager="apt-get"
        nginx_config_dir="/etc/nginx/sites-available"
        ;;
    *)
        error "Unsupported operating system"
        exit 1
        ;;
    esac

    echo "$package_manager" "$nginx_config_dir"
}
export -f detect_package_manager

# Function to detect the package manager and Nginx config directory
detect_package_manager() {
    local package_manager=""
    local nginx_config_dir=""

    if [ -f /etc/redhat-release ]; then
        package_manager="yum"
        nginx_config_dir="/etc/nginx/conf.d"
    elif [ -f /etc/lsb-release ]; then
        package_manager="apt-get"
        nginx_config_dir="/etc/nginx/sites-available"
    else
        error "Unsupported operating system"
        exit 1
    fi

    echo "$package_manager" "$nginx_config_dir"
}
export -f detect_package_manager

# Function to validate non-empty string
validate_non_empty() {
    local value="$1"
    local name="$2"
    if [ -z "$value" ]; then
        error "Value for $name is required and cannot be empty."
        exit 1
    fi
}
export -f validate_non_empty

# Function to validate IP address
validate_ip_address() {
    local ip_address="$1"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if ! [[ "$ip_address" =~ $ip_regex ]]; then
        error "Invalid IP address provided. Please provide a valid IP address."
        exit 1
    fi
}
export -f validate_ip_address

# Function to install Java
install_java() {
    local java_version="$1" # Java version to install

    info "Installing Java $java_version..."

    os=$(getOs)
    case "$os" in
    centos)

        # Enable EPEL repository and  Install Java
        sudo yum install -y epel-release java-$java_version-openjdk
        ;;
    ubuntu)

        # Update package lists and Install Java
        sudo apt-get install -y openjdk-$java_version-jdk
        ;;
    *)
        error "Unsupported operating system."
        return 1
        ;;
    esac

    if [ $? -eq 0 ]; then
        success "Java $java_version installed successfully!"
    else
        error "Failed to install Java $java_version."
    fi
}

export -f install_java

### Database functions
# Function to install PostgreSQL based on the OS
install_postgresql() {
    info "Installing PostgreSQL..."
    local os=$(getOs)

    if [ "$os" == "centos" ]; then
        sudo yum install -y postgresql-server
        sudo postgresql-setup initdb
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
        success "PostgreSQL installed successfully!"
    elif [ "$os" == "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
        success "PostgreSQL installed successfully!"
    else
        error "Unsupported operating system."
    fi
}

# Function to install a specific version of PostgreSQL
install_postgresql_version() {
    local pg_version="$1" # Desired PostgreSQL version

    info "Installing PostgreSQL version $pg_version..."
    # Get the operating system
    os=$(getOs)
    if [ "$os" == "centos" ]; then
        # Enable PostgreSQL repository
        sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

        # Install the specified PostgreSQL version
        sudo yum install -y postgresql$pg_version-server

        # Initialize the database, start, and enable the service
        sudo /usr/pgsql-$pg_version/bin/postgresql-$pg_version-setup initdb
        sudo systemctl start postgresql-$pg_version
        sudo systemctl enable postgresql-$pg_version
        success "PostgreSQL version $pg_version installed successfully!"
    elif [ "$os" == "ubuntu" ]; then
        # Add PostgreSQL repository
        sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

        # Update package lists and install the specified PostgreSQL version
        sudo apt-get update
        sudo apt-get install -y postgresql-$pg_version
        success "PostgreSQL version $pg_version installed successfully!"
    else
        error "Unsupported operating system."
    fi
}

# Function to execute SQL commands in PostgreSQL
execute_psql_commands() {
    # Execute the provided SQL command as the 'postgres' user
    sudo -u postgres psql -c "$1"
}

# Function to configure md5 authentication for PostgreSQL
configure_postgres_md5_authentication() {
    local pg_version="$1" # PostgreSQL version

    info "Configuring md5 authentication for PostgreSQL version $pg_version..."

    # Get the location of pg_hba.conf
    #PG_HBA_CONF=$(execute_psql_commands "SHOW hba_file;")
    PG_HBA_CONF=$(sudo -u postgres psql -t -c "SHOW hba_file;" | xargs)

    # Check if PG_HBA_CONF is empty
    if [ -z "$PG_HBA_CONF" ]; then
        error "Failed to retrieve the location of pg_hba.conf."
        return 1
    fi

    # Backup the original file
    local backup_path="${PG_HBA_CONF}.bak"
    cp "$PG_HBA_CONF" "$backup_path"

    # Replace trust, peer, or ident with md5 in pg_hba.conf
    #sudo sed -i 's/\(trust\|peer\|ident\)/md5/g' "$PG_HBA_CONF"
    sudo sed -i 's/peer/trust/g; s/ident/md5/g' $PG_HBA_CONF

    # Restart PostgreSQL
    if [ -n "$pg_version" ]; then
        sudo systemctl restart postgresql-$pg_version
    else
        sudo systemctl restart postgresql
    fi

    success "md5 authentication configured successfully for PostgreSQL version $pg_version!"
}

export -f configure_postgres_md5_authentication

# Function to setup PostgreSQL user and database
setup_postgresql_user_and_db() {
    local db_user="$1"     # PostgreSQL username
    local db_password="$2" # PostgreSQL user password
    local db_name="$3"     # PostgreSQL database name
    local pg_version="$4"  # PostgreSQL version (optional)

    # Install PostgreSQL or a specific version
    if [ -z "$pg_version" ]; then
        install_postgresql
    else
        install_postgresql_version "$pg_version"
    fi

    info "Creating PostgreSQL user and database..."

    # Create the PostgreSQL user
    execute_psql_commands "CREATE USER $db_user WITH PASSWORD '$db_password';"
    success "User $db_user created successfully."

    # Create the PostgreSQL database and grant ownership to the user
    execute_psql_commands "CREATE DATABASE $db_name WITH OWNER=$db_user ENCODING='UTF8';"
    success "Database $db_name created successfully and ownership granted to $db_user."

    # Grant all privileges on the database to the user
    execute_psql_commands "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;"
    success "All privileges granted to $db_user on $db_name."
}
export -f setup_postgresql_user_and_db

# Function to create SSL directory
create_ssl_directory() {
    local ssl_dir="$1"
    local user="$2"
    local group="$2"

    validate_non_empty "$ssl_dir" "SSL Directory"
    validate_non_empty "$user" "User"
    validate_non_empty "$group" "Group"

    if [ ! -d "$ssl_dir" ]; then
        info "Creating SSL directory..."
        sudo mkdir -p "$ssl_dir"
        sudo chown -R "$user:$group" "$ssl_dir"
        sudo chmod 700 "$ssl_dir"
        success "SSL directory created."
    else
        info "SSL directory already exists."
    fi
}
export -f create_ssl_directory

# Function to generate a self-signed SSL certificate and private key
generate_ssl_certificates() {
    local ip_address="$1"
    local ssl_dir="$2"
    local ssl_certificate_path="$3"
    local ssl_key_path="$4"
    local state="$5"
    local organization="$6"
    local unit="$7"

    validate_ip_address "$ip_address"
    validate_non_empty "$ssl_dir" "SSL Directory"
    validate_non_empty "$ssl_certificate_path" "SSL Certificate Path"
    validate_non_empty "$ssl_key_path" "SSL Key Path"
    validate_non_empty "$state" "State"
    validate_non_empty "$organization" "Organization"
    validate_non_empty "$unit" "Organizational Unit"

    info "Generating self-signed SSL certificates..."

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$ssl_key_path" -out "$ssl_certificate_path" \
        -subj "/C=US/ST=$state/L=YourCity/O=$organization/OU=$unit/CN=$ip_address"

    sudo chmod 600 "$ssl_key_path"

    success "SSL certificates generated successfully."
}
export -f generate_ssl_certificates

# Function to install Nginx
install_nginx() {
    local package_manager="$1"
    sudo $package_manager install -y nginx
    success "Nginx installed successfully."
}
export -f install_nginx

# Function to configure Nginx as a reverse proxy
configure_nginx() {
    local ip_address="$1"
    local ssl_certificate_path="$2"
    local ssl_key_path="$3"
    local service_config_file="$4"
    local proxy_pass_url="$5"
    local nginx_config_dir="$6"

    validate_non_empty "$nginx_config_dir" "Nginx Configuration Directory"

    # Create Nginx configuration
    sudo tee "${nginx_config_dir}/${service_config_file}" >/dev/null <<EOF
# If HTTPS is enabled, redirect HTTP to HTTPS 
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
        proxy_pass $proxy_pass_url; 
        proxy_set_header Host \$host; 
        proxy_set_header X-Real-IP \$remote_addr; 
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; 
        proxy_set_header X-Forwarded-Proto \$scheme; 
    } 
} 
EOF

    # Create symbolic link if necessary
    if [ -d "$nginx_config_dir" ] && [ ! -f /etc/redhat-release ]; then
        sudo ln -s "${nginx_config_dir}/${service_config_file}" /etc/nginx/sites-enabled/
    fi

    # Enable and start Nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx

    success "Nginx configured as a reverse proxy successfully."
}
export -f configure_nginx

# Function to install and configure Nginx as a reverse proxy
setup_nginx_installation_configuration() {
    info "start installing and configuring nginx"
    local ip_address="$1"
    local ssl_dir="$2"
    local ssl_certificate_path="$3"
    local ssl_key_path="$4"
    local service_config_file="$5"
    local proxy_pass_url="$6"

    validate_ip_address "$ip_address"
    validate_non_empty "$ssl_dir" "SSL Directory"
    validate_non_empty "$ssl_certificate_path" "SSL Certificate Path"
    validate_non_empty "$ssl_key_path" "SSL Key Path"
    validate_non_empty "$service_config_file" "Service Configuration File"
    validate_non_empty "$proxy_pass_url" "Proxy Pass URL"

    # Detect package manager and Nginx configuration directory
    read -r package_manager nginx_config_dir < <(detect_package_manager)

    # Install Nginx
    install_nginx "$package_manager"

    # Configure Nginx
    configure_nginx "$ip_address" "$ssl_certificate_path" "$ssl_key_path" "$service_config_file" "$proxy_pass_url" "$nginx_config_dir"
}
export -f setup_nginx_installation_configuration

# Function to create a systemd service unit file
create_systemd_service() {
    local service_name="$1"
    local description="$2"
    local exec_start="$3"
    local exec_stop="$4"
    local user="${5:-root}"           # Default to root if user not provided
    local group="${6:-root}"          # Default to root if group not provided
    local limit_nofile="${7:-131072}" # Default to 131072 if not provided
    local limit_nproc="${8:-8192}"    # Default to 8192 if not provided

    # Validate non-empty values
    validate_non_empty "$service_name" "service name"
    validate_non_empty "$description" "description"
    validate_non_empty "$exec_start" "start command"
    validate_non_empty "$exec_stop" "stop command"

    local systemd_dir=""
    if [ -d "/etc/systemd/system" ]; then
        systemd_dir="/etc/systemd/system"
    elif [ -d "/usr/lib/systemd/system" ]; then
        systemd_dir="/usr/lib/systemd/system"
    else
        error "Unable to locate systemd directory."
        exit 1
    fi

    cat <<EOT >"$systemd_dir/$service_name.service"
[Unit]
Description=$description
After=syslog.target network.target

[Service]
Type=forking

ExecStart=$exec_start
ExecStop=$exec_stop

User=$user
Group=$group
Restart=always

LimitNOFILE=$limit_nofile
LimitNPROC=$limit_nproc

[Install]
WantedBy=multi-user.target
EOT

    success "Systemd service unit file created at $systemd_dir/$service_name.service"
}

export -f create_systemd_service
