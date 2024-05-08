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
Info() {
    echo -e "${B}➜ INFO: $1$N"
}
export -f Info

# Function to print warning messages
warning() {
    echo -e "${Y} ☑ $1$N "
}
export -f warning

# Function to print success messages
success() {
    echo -e "${G} susccess: ✓ $1$N"
}
export -f success

# Function to print error messages
error() {
    echo -e "${R}✗ $1$N"
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

# Function to install Java
install_java() {
    local java_version="$1"  # Java version to install

    Info "Installing Java $java_version..."

    os=$(getOs)
    case "$os" in
        centos)

            # Enable EPEL repository and  Install Java
            sudo yum install -y epel-release java-$java_version-openjdk
            ;;
        ubuntu)

            # Update package lists and Install Java
            sudo apt-get install -y update  openjdk-$java_version-jdk
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
    Info "Installing PostgreSQL..."
    if [ "$OS" == "centos" ]; then
        sudo yum install -y postgresql-server
        sudo postgresql-setup initdb
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
        success "PostgreSQL installed successfully!"
    elif [ "$OS" == "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
        success "PostgreSQL installed successfully!"
    else
        error "Unsupported operating system."
    fi
}

# Function to install a specific version of PostgreSQL
install_postgresql_version() {
    local pg_version="$1"  # Desired PostgreSQL version

    Info "Installing PostgreSQL version $pg_version..."
    # Get the operating system
    OS=$(getOs)
    if [ "$OS" == "centos" ]; then
        # Enable PostgreSQL repository
        sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

        # Install the specified PostgreSQL version
        sudo yum install -y postgresql$pg_version-server

        # Initialize the database, start, and enable the service
        sudo /usr/pgsql-$pg_version/bin/postgresql-$pg_version-setup initdb
        sudo systemctl start postgresql-$pg_version
        sudo systemctl enable postgresql-$pg_version
        success "PostgreSQL version $pg_version installed successfully!"
    elif [ "$OS" == "ubuntu" ]; then
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

# Function to setup PostgreSQL user and database
setup_postgresql_user_and_db() {
    local db_user="$1"      # PostgreSQL username
    local db_password="$2"  # PostgreSQL user password
    local db_name="$3"      # PostgreSQL database name
    local pg_version="$4"   # PostgreSQL version (optional)

    # Install PostgreSQL or a specific version
    if [ -z "$pg_version" ]; then
        install_postgresql
    else
        install_postgresql_version "$pg_version"
    fi

    Info "Creating PostgreSQL user and database..."

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