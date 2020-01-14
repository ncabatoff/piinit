#!/usr/bin/env bash

# Set up dnsmasq and consul and nomad clients on the Vagrant guest.
# These will speak to the consul and nomad servers running in docker.

set -e

. /home/vagrant/.piinit.profile
test -n ${NETWORK}

apt-get update
apt-get install -y dnsmasq supervisor
dpkg -i /vagrant/packages/amd64/{terraform,nomad,consul,node_exporter}.deb
dpkg -i /home/vagrant/packages/all/nomad-config-client.deb \
  /home/vagrant/packages/all/nomad-config-local.deb \
  /home/vagrant/packages/all/consul-config-local.deb \
  /home/vagrant/packages/all/consul-config-client.deb \
  /home/vagrant/packages/all/node_exporter-supervisord.deb
cat - > /etc/dnsmasq.d/10-consul <<EOF
server=/consul/127.0.0.1#8600
EOF
systemctl restart dnsmasq supervisor

cat - > /etc/rc.local <<"EOF"
#!/usr/bin/env bash
supervisorctl stop nomad consul
killall nomad consul
docker kill `docker ps -q`
rm -rf /opt/nomad/data/* /opt/nomad/logs/* /opt/consul/data/* /opt/consul/logs/*
supervisorctl start nomad consul
EOF
sed 1d </vagrant/provision-docker-launch.sh >> /etc/rc.local

cat - >> /home/vagrant/.bashrc <<"EOF"
export NOMAD_ADDR=http://127.0.0.1:4646
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
PATH=$PATH:/opt/consul/bin:/opt/nomad/bin:/opt/terraform/bin
EOF

/etc/rc.local
