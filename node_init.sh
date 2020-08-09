#!/usr/bin/env bash
set -euo pipefail


setup_packages() {

  sudo add-apt-repository universe
  sudo apt update
  sudo debconf-set-selections <<< 'libssl1.1:amd64 libraries/restart-without-asking boolean true'
  sudo apt upgrade --yes

  sudo apt install --yes \
    build-essential \
    linux-headers-"$(uname -r)"
}

setup_docker() {

  sudo apt install --yes \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  sudo apt update
  sudo apt install --yes \
    docker-ce \
    docker-ce-cli \
    containerd.io
  sudo apt-mark hold \
    docker-ce \
    docker-ce-cli \
    containerd.io
}

setup_k8s() {

  setup_docker

  # default cgroup driver is cgroups is cgroupfs, but recommended driver is systemd.
  # follow the guide at https://kubernetes.io/docs/setup/cri/ (too complex)
  # echo 'plugins.cri.systemd_cgroup = true' |
  #     sudo tee -a /etc/containerd/config.toml

  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' |
    sudo tee -a /etc/apt/sources.list.d/kubernetes.list

  sudo apt update
  sudo apt install --yes \
    kubelet kubeadm kubectl
  sudo apt-mark hold \
    kubelet kubeadm kubectl
}

master(){
  setup_packages
  setup_k8s

  sudo apt install --yes ufw
  sudo ufw --force reset
  # for vagrant ssh
  sudo ufw allow 22/tcp
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
}


worker(){
  setup_packages
  setup_k8s

  export TOKEN
  export HASH
  TOKEN=$(sed -n 1p /vagrant/token.list)
  HASH=$(sed -n 2p /vagrant/token.list)

  sudo apt install --yes ufw
  sudo ufw --force reset
  # for vagrant ssh
  sudo ufw allow 22/tcp
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
}

eval "$1"
