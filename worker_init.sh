#!/usr/bin/env bash
set -euo pipefail

# export CONTROL_PLANE_ENDPOINT=$1
# export API_SERVER_PORT=$2
export TOKEN
export HASH
TOKEN=$(sed -n 1p /vagrant/token.list)
HASH=$(sed -n 2p /vagrant/token.list)

sudo apt install --yes ufw
sudo ufw --force reset
# see: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#check-required-ports
sudo ufw allow 10250/tcp
sudo ufw allow 30000:32767/tcp
sudo ufw --force enable

sudo swapoff -a
sudo systemctl daemon-reload
sudo systemctl restart kubelet

sudo kubeadm join "$CONTROL_PLANE_ENDPOINT:$API_SERVER_PORT" \
  --token "$TOKEN" \
  --discovery-token-ca-cert-hash sha256:"$HASH"