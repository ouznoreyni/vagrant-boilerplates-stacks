#!/bin/bash

# Main script

# Check if an argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [docker]"
    exit 1
fi

# Get the absolute path to the script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set the child folder
child_folder="$script_dir/scripts"

# Check if the child folder exists
if [ ! -d "$child_folder" ]; then
    echo "Folder '$child_folder' not found."
    exit 1
fi

# Source the appropriate script based on the argument
if [ "$1" == "docker" ]; then
    echo "Sonarqube Docker setup is coming soon"
else
    sonarqube_setup_script="$child_folder/install_sonarqube.sh"
    
    if [ -f "$sonarqube_setup_script" ]; then
        source "$sonarqube_setup_script"
    else
        echo "Sonarqube setup script not found: $sonarqube_setup_script"
        exit 1
    fi
fi

