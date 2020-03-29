#!/usr/bin/env bash
set -euo pipefail

sudo apt install --yes kubeadm

# # Turning swap off is required by kubeadm (https://github.com/kubernetes/kubeadm/issues/610)
# sudo swapoff -a
# sudo systemctl daemon-reload
# sudo systemctl restart kubelet

# To make kubectl work for your non-root user
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
