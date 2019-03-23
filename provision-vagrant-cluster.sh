#!/usr/bin/env bash

# This script is used to setup a host (presumably a vagrant machine) so that it
# can properly interact with the cluster and be a nomad client, i.e. run nomad
# jobs.  After many fruitless hours I gave up trying to get a dockerized nomad
# to run docker jobs.

set -e

. /home/vagrant/.piinit.profile
test -n ${NETWORK}

apt-get install -y dnsmasq /vagrant/packages/amd64/{terraform,nomad,consul}.deb /vagrant/packages/all/nomad-client.deb
cat - > /etc/dnsmasq.d/10-consul <<EOF
server=/consul/${NETWORK}.21#8600
server=/consul/${NETWORK}.22#8600
server=/consul/${NETWORK}.23#8600
bind-interfaces
EOF
systemctl restart dnsmasq supervisor

cat - /vagrant/docker-launch.sh > /etc/rc.local <<EOF
#!/usr/bin/env bash
supervisorctl stop nomad
killall nomad
docker kill `docker ps -q`
rm -rf /opt/nomad/data/* /opt/nomad/logs/*
EOF
echo "supervisorctl start nomad" >> /etc/rc.local

cat - >> /home/vagrant/.bashrc <<"EOF"
export NOMAD_ADDR=http://nomad.service.dc1.consul:4646
export CONSUL_HTTP_ADDR=http://consul.service.dc1.consul:8500
PATH=$PATH:/opt/consul/bin:/opt/nomad/bin:/opt/terraform/bin
EOF
