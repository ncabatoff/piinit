#!/bin/bash

set -e

. /home/vagrant/.piinit.profile

cd /vagrant
make

for i in packer-docker{,-server-cn,-server-mon}.json; do
  packer build $i
done

