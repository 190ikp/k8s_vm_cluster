#!/usr/bin/env bash
set -euo pipefail


setup_packages() {
    
    sudo add-apt-repository universe
    sudo apt update
    sudo apt upgrade --yes

    sudo apt install --yes \
        build-essential \
        linux-headers-"$(uname -r)" \
        tmux

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
    # installed version is 18.09 for k8s support
    sudo apt install --yes \
        docker-ce=5:18.09.9~3-0~ubuntu-bionic \
        docker-ce-cli=5:18.09.9~3-0~ubuntu-bionic
    sudo apt-mark hold docker-ce docker-ce-cli

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
        kubelet=1.16
    sudo apt-mark hold \
        kubelet
    
}

all() {

    setup_packages
    setup_k8s

    echo 'All setup is finished.'
}

eval "$1"
