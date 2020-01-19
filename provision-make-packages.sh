#!/bin/bash

set -e

. /home/vagrant/.piinit.profile

cd /vagrant/cmd/pkgbuilder
GO111MODULE=on go install

# packer-docker only uses amd64 packages, which tend to be big.  Rather than
# download the binaries used twice, we build these in the shared directory so
# we can re-use what we do for the ARM builder.
mkdir -p /vagrant/packages
cd /vagrant/packages
pkgbuilder -arches amd64

# We use some different config in the docker env (e.g. consul PSK) so build
# private 'all' packages here.
mkdir -p ./vm
cd ./vm
encrypt=`dd if=/dev/urandom bs=16 count=1 2>/dev/null | base64`
pkgbuilder -arches all -config '{
  "ConsulSerfEncrypt": "'"$encrypt"'",
  "CoreServers": ["192.168.2.51", "192.168.2.52", "192.168.2.53"],
  "CoreCidr": "192.168.2.0/24"
}'



