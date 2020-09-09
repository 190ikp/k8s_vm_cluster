# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  load_balancer_fqdn = "k8s-lb"
  k8s_api_port = 6443

  """
  It is recommended that all nodes have
  - 2 CPUs or more
  - 2GB or more of RAM

  for further infomation: see https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
  """

  # master node settings
  num_master = 3
  master_node_cpu = 2
  master_node_mem = 2048

  # worker node settings
  num_worker = 3
  worker_node_cpu = 2
  worker_node_mem = 2048
  
  config.vm.box = "ubuntu/bionic64"

  config.vm.box_check_update = false
    
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--ostype", "Ubuntu_64", "--ioapic", "on"]
  end

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box 
  end

  # Use vagrant-hosts plugin for internal DNS
  if Vagrant.has_plugin?("vagrant-hosts")
    config.vm.provision :hosts, :sync_hosts => true
  end
  
  config.vm.define "lb" do |lb|
    lb.vm.provider "virtualbox" do |vb|
      vb.name = load_balancer_fqdn
      vb.cpus = 1
      vb.memory = 512
    end
    lb.vm.network "private_network", type: "dhcp", virtualbox__intnet: "k8s"
    lb.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
    lb.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.1"
    lb.vm.network "forwarded_port", guest: k8s_api_port, host: 6443, host_ip: "127.0.0.1"
    lb.vm.provision "shell" do |s|
      s.privileged = false
      s.env = {"API_SERVER_PORT" => k8s_api_port, "NUM_MASTER" => num_master}
      s.path = "node_init.sh"
      s.args = ["lb"]
    end
  end

  (1..num_master).each do |i|
    config.vm.define "master-#{i}" do |master|
      master.vm.provider "virtualbox" do |vb|
        vb.name = "master-#{i}"
        vb.cpus = master_node_cpu
        vb.memory = master_node_mem
      end

      master.vm.network "private_network", type: "dhcp", virtualbox__intnet: "k8s"
      master.vm.provision "shell" do |s|
        s.privileged = false
        s.env = {"CONTROL_PLANE_ENDPOINT" => load_balancer_fqdn, "API_SERVER_PORT" => k8s_api_port}
        s.path = "node_init.sh"
        s.args = ["master"]
      end
    end
  end

  (1..num_worker).each do |i|
    config.vm.define "worker-#{i}" do |worker|
      worker.vm.provider "virtualbox" do |vb|
        vb.name = "worker-#{i}"
        vb.cpus = worker_node_cpu
        vb.memory = worker_node_mem
      end

      worker.vm.network "private_network", type: "dhcp", virtualbox__intnet: "k8s"
      worker.vm.provision "shell" do |s|
        s.privileged = false
        s.env = {"CONTROL_PLANE_ENDPOINT" => load_balancer_fqdn, "API_SERVER_PORT" => k8s_api_port}
        s.path = "node_init.sh" 
        s.args = ["worker"]
      end
    end
  end
end
