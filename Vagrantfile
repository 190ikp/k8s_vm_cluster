# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  
    config.vm.box = "ubuntu/bionic64"

    config.vm.box_check_update = false
    
    config.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.customize ["modifyvm", :id, "--ostype", "Ubuntu_64"]
    end

    (1..3).each do |i|
      config.vm.define "master-#{i}" do |master|
        master.vm.network "private_network", ip: "10.10.10.1#{i}", virtualbox__intnet: "k8s"
        master.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1#{i}"
        master.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.1#{i}"
        master.vm.provision "shell", inline: <<-SHELL
          export HOSTNAME
          HOSTNAME=master-#{i}
          /vagrant/node_init.sh all
        SHELL
      end

      config.vm.define "worker-#{i}" do |worker|
        worker.vm.network "private_network", ip: "10.10.10.2#{i}", virtualbox__intnet: "k8s"
        worker.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.2#{i}"
        worker.vm.network "forwarded_port", guest: 443, host: 8443, host_ip: "127.0.0.2#{i}"
        worker.vm.provision "shell", inline: <<-SHELL
          export HOSTNAME
          HOSTNAME=worker-#{i}
          /vagrant/node_init.sh all
        SHELL
      end
    end
  end
  