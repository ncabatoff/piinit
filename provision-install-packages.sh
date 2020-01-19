#!/usr/bin/env bash

# Set up dnsmasq, consul, nomad, and monitoring.

set -e

binPkgDir=$1
cfgPkgDir=$2
serverOrClient=$3

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y supervisor
if [ "$binPkgDir" != "" ]; then
  apt-get install -y "$binPkgDir"/{nomad,consul,node_exporter,process-exporter,script-exporter}.deb
fi
if [ "$cfgPkgDir" != "" ]; then
  apt-get install -y \
    "$cfgPkgDir"/{nomad-config-local,consul-config-local,node_exporter-supervisord,process-exporter-config}.deb \
    "$cfgPkgDir"/nomad-config-$serverOrClient.deb "$cfgPkgDir"/consul-config-$serverOrClient.deb
  [ -x /bin/systemctl ] && systemctl restart supervisor
fi

cat - >> /root/.bashrc <<"EOF"
export NOMAD_ADDR=http://127.0.0.1:4646
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
PATH=$PATH:/opt/consul/bin:/opt/nomad/bin
EOF

