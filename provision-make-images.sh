#!/bin/bash

set -e

. /home/vagrant/.piinit.profile

# packer-docker only uses amd64 packages, which tend to be big.  Rather than
# download the binaries used twice, we build these in the shared directory so
# we can re-use what we do for the ARM builder.
cd /vagrant
jsonnet -o packer-docker.json /vagrant/packer-docker.jsonnet
packer build packer-docker.json

# We use some different config in the docker env (e.g. consul PSK) so build
# private 'all' packages here.
jsonnet -o packer-docker-server-cn.json /vagrant/packer-docker-server-cn.jsonnet
packer build packer-docker-server-cn.json
jsonnet -o packer-docker-server-mon.json /vagrant/packer-docker-server-mon.jsonnet
packer build packer-docker-server-mon.json
