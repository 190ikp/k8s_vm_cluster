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
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
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

  if [ "$(hostname)" = "master-1" ]; then
    # see: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint="$CONTROL_PLANE_ENDPOINT" --upload-certs

    # To make kubectl work for your non-root user.
    mkdir -p "$HOME/.kube"
    sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
    sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

    # create pod network by flannel
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

    # make token list file
    sudo kubeadm init phase upload-certs --upload-certs |
      sudo tee /vagrant/token.list
    openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt |
      openssl rsa -pubin -outform der 2>/dev/null |
      openssl dgst -sha256 -hex |
      sed 's/^.* //' |
      sudo tee -a /vagrant/token.list
    sudo kubeadm alpha certs certificate-key |
      sudo tee -a /vagrant/token.list
  else
    export TOKENs
    export HASH
    export CERT_KEY
    TOKEN=$(sed -n 1p /vagrant/token.list)
    HASH=$(sed -n 2p /vagrant/token.list)
    CERT_KEY=$(sed -n 3p /vagrant/token.list)

    sudo kubeadm join "$CONTROL_PLANE_ENDPOINT:$API_SERVER_PORT" \
      --token "$TOKEN" \
      --discovery-token-ca-cert-hash sha256:"$HASH" \
      --control-plane \
      --certificate-key "$CERT_KEY"
  fi
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

lb() {
  setup_packages

  # You can choose HAProxy version out of:
  #   1.7, 1.8, 2.0, 2.1, 2.2
  export HAPROXY_VERSION=2.2
  export APISERVER_DEST_PORT=$API_SERVER_PORT
  export APISERVER_SRC_PORT=$API_SERVER_PORT

  # Setting up HAProxy
  sudo apt install --yes software-properties-common
  sudo add-apt-repository ppa:vbernat/haproxy-$HAPROXY_VERSION
  sudo apt update
  sudo apt install --yes haproxy=$HAPROXY_VERSION.\*
  sudo systemctl enable haproxy
  
  envsubst \$APISERVER_DEST_PORT < /vagrant/config/lb/haproxy.cfg |
    sudo dd of=/etc/haproxy/haproxy.cfg
  for id in $(seq 1 "$NUM_MASTER"); do
    echo "        server master-$id master-$id:$APISERVER_SRC_PORT check" |
      sudo tee -a /etc/haproxy/haproxy.cfg
  done

  # Before setting up master nodes, you should not start haproxy process.
  # sudo systemctl start haproxy
}

eval "$1"
