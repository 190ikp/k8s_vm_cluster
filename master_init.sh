#!/usr/bin/env bash
set -euo pipefail

# export CONTROL_PLANE_ENDPOINT=$1
# export API_SERVER_PORT=$2

sudo apt install --yes ufw
sudo ufw --force reset
# see: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#check-required-ports
sudo ufw allow "$API_SERVER_PORT"/tcp
sudo ufw allow 2379:2380/tcp
sudo ufw allow 10250:10252/tcp
sudo ufw --force enable

# Turning swap off is required by kubeadm. 
# see: https://github.com/kubernetes/kubeadm/issues/610
sudo swapoff -a
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# see: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node
# We use flannel 
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint="$CONTROL_PLANE_ENDPOINT"

sudo kubeadm token create |
  sudo tee /vagrant/token.list

openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |
  openssl rsa -pubin -outform der 2>/dev/null |
  openssl dgst -sha256 -hex |
  sed 's/^.* //' |
  sudo tee -a /vagrant/token.list

# To make kubectl work for your non-root user.
mkdir -p "$HOME/.kube"
sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# helm upgrade --install jupyterhub jupyterhub/jupyterhub --namespace kube-jupyterhub --version=0.8.2 --values conf/config.yml
