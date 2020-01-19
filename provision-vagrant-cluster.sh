#!/usr/bin/env bash

# Set up dnsmasq and consul and nomad clients on the Vagrant guest.
# These will speak to the consul and nomad servers running in docker.

set -e

. /home/vagrant/.piinit.profile
test -n ${NETWORK}

/vagrant/provision-install-packages.sh /vagrant/packages/{amd64,vm/all} client

# We don't need consul DNS for running the cluster or jobs, but if we want to
# deploy jobs using terraform and the nomad provider we might.
DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq
cat - > /etc/dnsmasq.d/10-consul <<EOF
server=/consul/127.0.0.1#8600
EOF
systemctl restart dnsmasq

# Update rc.local so that if we get rebooted the nomad and consul clients
# come back up properly, and the docker cluster starts.  In principle only
# the latter should be needed, but problems in the past prompted wiping nomad
# and consul state.
cat - > /etc/rc.local <<"EOF"
#!/usr/bin/env bash
supervisorctl stop nomad consul
killall nomad consul
docker kill `docker ps -q`
rm -rf /opt/nomad/data/* /opt/nomad/logs/* /opt/consul/data/* /opt/consul/logs/*
supervisorctl start nomad consul
EOF
sed 1d </vagrant/provision-docker-launch.sh >> /etc/rc.local
chmod 755 /etc/rc.local

# Like with dnsmasq, these env settings are mostly just a convenience.
cat - >> /home/vagrant/.bashrc <<"EOF"
export NOMAD_ADDR=http://127.0.0.1:4646
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
PATH=$PATH:/opt/consul/bin:/opt/nomad/bin:/opt/terraform/bin
EOF

/etc/rc.local
