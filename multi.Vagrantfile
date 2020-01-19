# -*- mode: ruby -*-
# vi: set ft=ruby :

network_prefix  = '192.168.2.'  # ip prefix of vm hosts, remaining octet provided by :id attribute in nodes, below:
nodes = [
  { :hostname => 'builder', :id => '10', :memory => 500 },
#   { :hostname => 'mon1',    :id => '41', :memory => 500 },
  { :hostname => 'srv1',    :id => '51', :memory => 500 },
  { :hostname => 'srv2',    :id => '52', :memory => 500 },
  { :hostname => 'srv3',    :id => '53', :memory => 500 },
  { :hostname => 'cli1',    :id => '61', :memory => 500 },
  { :hostname => 'cli2',    :id => '62', :memory => 500 },
]

Vagrant.configure("2") do |config|
  nodes.each do |node|
    config.vm.define node[:hostname] do |nodeconfig|
      # Use sshfs for synced folders because default doesn't work with multihost.
      # We use this mainly to get the debs built on builder to the other nodes.
      nodeconfig.vm.synced_folder ".", "/vagrant", type: "sshfs"
      nodeconfig.vm.box = "generic/debian9"
      nodeconfig.vm.hostname = node[:hostname]
      nodeconfig.vm.network :private_network, ip: network_prefix + node[:id], virtualbox__intnet: "hashicluster"

      nodeconfig.vm.provider :virtualbox do |vb|
        vb.linked_clone = true # Use virtualbox linked clones to reduce disk usage
        vb.memory = node[:memory]
        vb.name = node[:hostname]
        # Keep clocks synced
        vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000 ]
      end
      if node[:hostname] == 'builder'
        nodeconfig.vm.provision "build-env", type: "shell", :path => "provision/build-env.sh", privileged: false
        nodeconfig.vm.provision "make-pkgs", type: "shell", :path => "provision/make-packages.sh", privileged: false
      else
        nodeconfig.vm.provision "shell" do |s|
          s.name = "install-pkgs"
          s.path = "provision/install-packages.sh"
          s.args = ["/vagrant/packages/amd64", "/vagrant/packages/vm/all",
            node[:hostname].start_with?("srv") ? "server": "client"]
          s.privileged = true
        end
      end
    end
  end
end

