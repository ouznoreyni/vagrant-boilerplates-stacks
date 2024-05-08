#!/bin/bash

script_utils_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the utils functions
source $script_utils_dir/common_functions.sh

NEXUS_BASE_DIR=/opt/nexus
NEXUS_TMP_DIR=/tmp/nexus
NEXUS_USER=nexus
NEXUS_SERVICE_NAME=nexus
NEXUS_URL="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
OS=$(getOs)


#!/bin/bash
yum install java-1.8.0-openjdk.x86_64 wget -y   
mkdir -p "$NEXUS_BASE_DIR/"   
mkdir -p "$NEXUS_TMP_DIR/"                           
cd "$NEXUS_TMP_DIR/"
wget $NEXUS_URL -O nexus.tar.gz
sleep 10
EXTOUT=`tar xzvf nexus.tar.gz`
NEXUS_DIR=`echo $EXTOUT | cut -d '/' -f1`
sleep 5
rm -rf $NEXUS_TMP_DIR/nexus.tar.gz
cp -r $NEXUS_TMP_DIR/* $NEXUS_BASE_DIR/
sleep 5
useradd $NEXUS_USER
chown -R $NEXUS_USER.$NEXUS_USER $NEXUS_BASE_DIR 
cat <<EOT>> /etc/systemd/system/$NEXUS_SERVICE_NAME.service
[Unit]                                                                          
Description=nexus service                                                       
After=network.target                                                            
                                                                  
[Service]                                                                       
Type=forking                                                                    
LimitNOFILE=65536                                                               
ExecStart=$NEXUS_BASE_DIR/$NEXUS_DIR/bin/nexus start                                  
ExecStop=$NEXUS_BASE_DIR/$NEXUS_DIR/bin/nexus stop                                    
User=$NEXUS_USER                                                                      
Restart=on-abort                                                                
                                                                  
[Install]                                                                       
WantedBy=multi-user.target                                                      

EOT

echo 'run_as_user="$NEXUS_USER"' > $NEXUS_BASE_DIR/$NEXUS_DIR/bin/nexus.rc
systemctl daemon-reload
systemctl start $NEXUS_SERVICE_NAME
systemctl enable $NEXUS_SERVICE_NAME

# Open port 8081 on CentOS or Ubuntu using respective firewall commands
if [ "$OS" == "centos" ]; then
    firewall-cmd --zone=public --permanent --add-port=8081/tcp
    firewall-cmd --reload
elif [ "$OS" == "ubuntu" ]; then
    ufw allow 8081/tcp
fi

cat /opt/nexus/sonatype-work/nexus3/admin.password