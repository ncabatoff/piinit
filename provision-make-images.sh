#!/bin/bash

set -e

. /home/vagrant/.piinit.profile

cd /vagrant

encrypt=`dd if=/dev/urandom bs=16 count=1 2>/dev/null | base64`
echo "{consul_encrypt: '$encrypt'}" > packer-docker-variables.jsonnet

(
  echo "["
  for i in 21 22 23; do
    echo "'$NETWORK.$i',"
  done
  echo "]"
) > packer-docker-coreips.jsonnet

commonArgs="--tla-code-file variables=packer-docker-variables.jsonnet \
  --tla-code-file coreips=packer-docker-coreips.jsonnet"

jsonnet -o packer-docker.json packer-docker.jsonnet
jsonnet -o packer-docker-server-cn.json $commonArgs packer-docker-server-cn.jsonnet
jsonnet -o packer-docker-server-mon.json $commonArgs packer-docker-server-mon.jsonnet

packer build packer-docker.json
packer build packer-docker-server-cn.json
packer build packer-docker-server-mon.json

