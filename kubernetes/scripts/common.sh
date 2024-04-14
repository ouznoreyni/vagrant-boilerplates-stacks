#!/bin/bash

# Parse argument to determine which ports to open
is_control_plane="$1"

#1 disable swap
sudo swapoff -a
# Comment out swap entry in /etc/fstab
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 2 Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config


#3 install containerd
sudo yum update -y
sudo yum install -y yum-utils
sudo yum config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin -y
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl start docker
sudo systemctl enable docker


#4 Install and configure prerequisites
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
# Apply sysctl params without reboot
echo "sudo sysctl --system"
sudo sysctl --system

echo "end sudo sysctl --system"

#5  node ports should be opened
# Check if firewalld service is running, start it if not
if ! sudo systemctl is-active --quiet firewalld; then
    sudo systemctl start firewalld
fi
# Enable firewall-cmd
sudo systemctl enable firewalld >/dev/null 2>&1

if [ "$is_control_plane" = true ]; then
    sudo firewall-cmd --permanent --add-port={6443,2379,2380,10250,10251,10252,10257,10259,179}/tcp
else
    sudo firewall-cmd --permanent --add-port={179,10250,30000-32767}/tcp
fi
sudo firewall-cmd --permanent --add-port=4789/udp
sudo firewall-cmd --reload

#6 Add the Kubernetes yum repository
# This overwrites any existing configuration in /etc/yum.repos.d/kubernetes.repo
sudo cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

#6 (Optional) Enable the kubelet service before running kubeadm
sudo systemctl enable --now kubelet


echo "common setup done ......................"