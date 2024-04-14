#!/bin/bash
echo "control plane node .........................................."

IPADDR="192.168.56.60"
NODENAME="kubplan1"
POD_CIDR="192.168.0.0/16"

#  initialize the master node control plane configurations using the kubeadm command.
sudo kubeadm init --apiserver-advertise-address=$IPADDR  --apiserver-cert-extra-sans=$IPADDR  --pod-network-cidr=$POD_CIDR --node-name $NODENAME 

#Use the following commands from the output to create the kubeconfig in master so that you can use kubectl to interact with cluster API.
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config



#Install the Tigera Calico operator and custom resource definitions.
sudo kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
#Install Calico by creating the necessary custom resource. 
sudo kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

#Remove the taints on the control plane so that you can schedule pods on it.
#By default, apps won’t get scheduled on the master node.If you want to use the master node for scheduling apps,
# taint the master node.
sudo kubectl taint nodes --all node-role.kubernetes.io/control-plane-


# Execute kubeadm command and store the output in a text file
sudo kubeadm token create --print-join-command > /tmp/join-command.txt

sudo chmod 644  /tmp/join-command.txt
