# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "generic/debian9"
  config.vm.provider :virtualbox do |vb|
    vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000 ]
    vb.memory = 1500
  end
  config.vm.synced_folder "./", "/vagrant", disabled: false

  config.vm.provision :docker

  # The following line terminates all ssh connections. Therefore
  # Vagrant will be forced to reconnect.
  # This is a hack to ensure that the vagrant user is running a shell in which
  # it is a member of the docker group, and hence is able to run docker commands.
  config.vm.provision "shell", inline:
     "ps aux | grep 'sshd:' | awk '{print $2}' | xargs kill"

  config.vm.provision "build-env", type: "shell", :path => "provision-build-env.sh", privileged: false
  config.vm.provision "make-pkgs", type: "shell", :path => "provision-make-packages.sh", privileged: false
  config.vm.provision "make-images", type: "shell", :path => "provision-make-images.sh", privileged: false
  config.vm.provision "cluster-client", type: "shell", :path => "provision-vagrant-cluster.sh", privileged: true

  config.vm.network "forwarded_port", guest: 18500, host: 48500  # consul
  config.vm.network "forwarded_port", guest: 14646, host: 44646  # nomad
  config.vm.network "forwarded_port", guest: 19090, host: 49090  # prometheus
  config.vm.network "forwarded_port", guest: 3000, host: 43000   # grafana
end

