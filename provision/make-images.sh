#!/bin/bash

set -e

. /home/vagrant/.piinit.profile

cd /vagrant
jsonnet -o packer/docker.json packer/docker.jsonnet
packer build packer/docker.json
jsonnet -o packer/docker-server-cn.json packer/docker-server-cn.jsonnet
packer build packer/docker-server-cn.json
jsonnet -o packer/docker-server-mon.json packer/docker-server-mon.jsonnet
packer build packer/docker-server-mon.json
