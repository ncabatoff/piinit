#!/usr/bin/env bash

# Set up dnsmasq and consul and nomad clients on the Vagrant guest.
# These will speak to the consul and nomad servers running in docker.

set -e

. /home/vagrant/.piinit.profile
test -n ${NETWORK}

# Use the docker private network interface as our hostname.  Then our
# consul-wrapper script will invoke consul such that consul will bind to that
# interface and be able to gossip to the docker consul servers.
sed -i -E  "s/127\.0\.1\.1[ 	]*(ubuntu-.*)/$NETWORK.1 \1/" /etc/hosts

apt-get install -y dnsmasq supervisor
apt-get install -y /vagrant/packages/amd64/{terraform,nomad,consul}.deb /vagrant/packages/all/nomad-client.deb /vagrant/packages/all/consul-local.deb
cat - > /etc/dnsmasq.d/10-consul <<EOF
server=/consul/192.168.2.51#8600
server=/consul/192.168.2.52#8600
server=/consul/192.168.2.53#8600
EOF
systemctl restart dnsmasq supervisor

cat - /vagrant/provision-docker-launch.sh > /etc/rc.local <<"EOF"
#!/usr/bin/env bash
supervisorctl stop nomad consul
killall nomad consul
docker kill `docker ps -q`
rm -rf /opt/nomad/data/* /opt/nomad/logs/* /opt/consul/data/* /opt/consul/logs/*
supervisorctl start nomad consul
EOF

cat - >> /home/vagrant/.bashrc <<"EOF"
export NOMAD_ADDR=http://127.0.0.1:4646
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
PATH=$PATH:/opt/consul/bin:/opt/nomad/bin:/opt/terraform/bin
EOF
