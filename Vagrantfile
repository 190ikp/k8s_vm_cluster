# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # load balancer settings
  num_lb = 1
  lb_cpu = 1
  lb_mem = 512
  k8s_api_port = 6443
  domain = ".local"
  load_balancer_fqdn = "lb" + domain

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
      vb.name = "lb"
      vb.cpus = lb_cpu
      vb.memory = lb_mem
    end

    lb.vm.hostname = load_balancer_fqdn
    lb.vm.network "private_network", ip: "10.0.0.2", netmask: "255.255.0.0", virtualbox__intnet: true
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

      master.vm.hostname = "master-#{i}" + domain
      master.vm.network "private_network", ip: "10.0.10.#{i+1}", netmask: "255.255.0.0", virtualbox__intnet: true
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

      worker.vm.hostname = "worker-#{i}" + domain
      worker.vm.network "private_network", ip: "10.0.20.#{i+1}", netmask: "255.255.0.0", virtualbox__intnet: true
      worker.vm.provision "shell" do |s|
        s.privileged = false
        s.env = {"CONTROL_PLANE_ENDPOINT" => "master-1.local", "API_SERVER_PORT" => k8s_api_port}
        s.path = "node_init.sh" 
        s.args = ["worker"]
      end
    end
  end
end
