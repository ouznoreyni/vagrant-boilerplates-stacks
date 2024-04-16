#!/bin/bash

# Retrieve the master node IP from the argument
CONTROL_PLANE_IP="$1"

# Variables
SERVER_USER="vagrant"  # Replace with your server username
SERVER_HOST="$CONTROL_PLANE_IP"  # Set SERVER_HOST to CONTROL_PLANE_IP
SERVER_PORT=22  # Replace with your server's SSH port if different from the default (22)
SERVER_PASSWORD="vagrant"  # Replace with your server password

# Define the remote join command file path and local file path
REMOTE_JOIN_COMMAND_FILE_PATH="/tmp/join-command.txt"
LOCAL_JOIN_COMMAND_FILE_PATH="/home/vagrant/join-command.txt"
VAGRANT_PWD="vagrant"

# Function to log and exit on error
function handle_error {
    echo "Error: $1"
    exit 1
}

# Step 1: Generate an RSA key pair (skip if already exists)
KEY_FILE="$HOME/.ssh/id_rsa"
if [ ! -f "$KEY_FILE" ]; then
    ssh-keygen -t rsa -b 2048 -f "$KEY_FILE" -N '' || handle_error "Failed to generate RSA key pair."
fi

 sudo yum install -y sshpass
# Step 2: Copy public key to the server's authorized keys file
PUB_KEY_FILE="${KEY_FILE}.pub"

# Use sshpass to provide the password to ssh-copy-id
echo "Setting up passwordless SSH access to control plane node..."
sshpass -p "$SERVER_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no -i "$PUB_KEY_FILE" -p $SERVER_PORT "$SERVER_USER@$SERVER_HOST" || handle_error "Failed to set up passwordless SSH."

echo "Passwordless SSH setup complete for $SERVER_USER@$SERVER_HOST."

# Step 3: Fetch the join command file from the control plane node
echo "Fetching join command file from control plane node..."
sshpass -p "$VAGRANT_PWD" scp -o StrictHostKeyChecking=no vagrant@"$CONTROL_PLANE_IP":"$REMOTE_JOIN_COMMAND_FILE_PATH" "$LOCAL_JOIN_COMMAND_FILE_PATH" || handle_error "Failed to fetch join command file from control plane node."

# Step 4: Read the join command from the local file
join_command=$(cat "$LOCAL_JOIN_COMMAND_FILE_PATH")

# Step 5: Execute the join command
echo "Executing join command to join the Kubernetes cluster..."
$join_command || handle_error "Failed to join the Kubernetes cluster."

echo "Worker node successfully joined the Kubernetes cluster."
