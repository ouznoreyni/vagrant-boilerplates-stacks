#!/bin/bash

# Check the operating system
if [ -f /etc/redhat-release ]; then
    OS="centos"
elif [ -f /etc/lsb-release ]; then
    OS="ubuntu"
else
    echo "Unsupported operating system"
    exit 1
fi

# Function to install PostgreSQL based on the OS
install_postgresql() {
    if [ "$OS" == "centos" ]; then
        sudo yum install -y postgresql-server
        sudo postgresql-setup initdb
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
    elif [ "$OS" == "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
    fi
}

# Function to execute SQL commands in PostgreSQL
execute_psql_commands() {
    sudo -u postgres psql -c "$1"
}

# Function to create a PostgreSQL user and database
create_postgresql_db_user() {
    local db_user="$1"
    local db_password="$2"
    local db_name="$3"

    execute_psql_commands "CREATE USER $db_user WITH PASSWORD '$db_password';"
    execute_psql_commands "CREATE DATABASE $db_name WITH OWNER=$db_user ENCODING='UTF8';"
    execute_psql_commands "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;"
}

# Install PostgreSQL based on the detected OS
install_postgresql

# Check the argument provided when sourcing the script
if [ "$1" == "artifactory" ]; then
    create_postgresql_db_user "artifactory" "password" "artifactory"
    echo "Artifactory database setup completed successfully."
elif [ "$1" == "jcr" ]; then
    create_postgresql_db_user "jcr" "password" "jcr"
    echo "JCR database setup completed successfully."
else
    echo "Invalid argument. Usage: $0 [artifactory|jcr]"
    exit 1
fi
