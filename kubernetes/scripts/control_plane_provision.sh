#!/bin/bash
echo "control plane node .........................................."

IPADDR="192.168.56.60"
NODENAME="kubplan1"
POD_CIDR="10.244.0.0/16"

#  initialize the master node control plane configurations using the kubeadm command.
sudo kubeadm init --apiserver-advertise-address=$IPADDR  --apiserver-cert-extra-sans=$IPADDR  --pod-network-cidr=$POD_CIDR --node-name $NODENAME 

#Use the following commands from the output to create the kubeconfig in master so that you can use kubectl to interact with cluster API.
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Execute kubeadm command and store the output in a text file
sudo kubeadm token create --print-join-command > /tmp/join-command.txt

sudo chmod 644  /tmp/join-command.txt
