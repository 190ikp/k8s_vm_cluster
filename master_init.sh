#!/usr/bin/env bash
set -euo pipefail

# # Turning swap off is required by kubeadm (https://github.com/kubernetes/kubeadm/issues/610)
sudo swapoff -a
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# see: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=master-1

# To make kubectl work for your non-root user
mkdir -p "$HOME/.kube"
sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

sudo kubectl apply -f /vagrant/conf/kube-flannel.yml

helm upgrade --install jupyterhub jupyterhub/jupyterhub --namespace kube-jupyterhub --version=0.8.2 --values conf/config.yml