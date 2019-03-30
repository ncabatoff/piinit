#!/bin/bash

set -e

. /home/vagrant/.piinit.profile

cd /vagrant

jsonnet -o packer-docker.json packer-docker.jsonnet
jsonnet -o packer-docker-server-cn.json packer-docker-server-cn.jsonnet
jsonnet -o packer-docker-server-mon.json packer-docker-server-mon.jsonnet

packer build packer-docker.json
packer build packer-docker-server-cn.json
packer build packer-docker-server-mon.json
