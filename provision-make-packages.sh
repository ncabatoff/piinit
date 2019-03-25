#!/bin/bash

set -e

. /home/vagrant/.piinit.profile

cd $GOPATH
go get -u github.com/ncabatoff/pkgbuilder
cd $GOPATH/src/github.com/ncabatoff/pkgbuilder
GO111MODULE=on go install

mkdir -p /vagrant/packages
cd /vagrant/packages
pkgbuilder



