#!/bin/bash

set -e

. /home/vagrant/.piinit.profile

cd $GOPATH
go get -u github.com/ncabatoff/pkgbuilder
cd $GOPATH/src/github.com/ncabatoff/pkgbuilder
GO111MODULE=on go install

mkdir -p /vagrant/packages
cd /vagrant/packages
encrypt=`dd if=/dev/urandom bs=16 count=1 2>/dev/null | base64`
pkgbuilder -config '{"ConsulSerfEncrypt": "'"$encrypt"'", "CoreServers": ["192.168.2.51", "192.168.2.52", "192.168.2.53"]}'



