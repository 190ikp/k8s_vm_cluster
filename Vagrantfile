# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  domain = ".local"
  control_plane_endpoint = "master-1" + domain
  k8s_api_port = 6443

  """
  It is recommended that all nodes have
  - 2 CPUs or more
  - 2GB or more of RAM

  for further infomation: see https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
  """

  # master node settings
  # NOT support multi-master cluster
  # DO NOT change 'num_master' variable
  num_master = 1
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
  
  (1..num_master).each do |i|
    config.vm.define "master-#{i}" do |master|
      master.vm.provider "virtualbox" do |vb|
        vb.name = "master-#{i}"
        vb.cpus = master_node_cpu
        vb.memory = master_node_mem
      end

      master.vm.hostname = "master-#{i}" + domain
      master.vm.network "private_network", ip: "10.0.10.#{i+1}", netmask: "255.255.0.0", virtualbox__intnet: true
      master.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.#{i}"
      master.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.#{i}"
      master.vm.network "forwarded_port", guest: 6443, host: 6443, host_ip: "127.0.0.#{i}"
      master.vm.provision "shell" do |s|
        s.privileged = false
        s.env = {"CONTROL_PLANE_ENDPOINT" => control_plane_endpoint, "API_SERVER_PORT" => k8s_api_port}
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
        s.env = {"CONTROL_PLANE_ENDPOINT" => control_plane_endpoint, "API_SERVER_PORT" => k8s_api_port}
        s.path = "node_init.sh" 
        s.args = ["worker"]
      end
    end
  end
end
