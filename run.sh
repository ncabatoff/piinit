#!/usr/bin/env bash

set -e
WORKDIR=packer-builder-arm-image
cp ~/.ssh/id_rsa.pub $WORKDIR/authorized_keys
cp *.json consul-client-pi.hcl $WORKDIR
cd $WORKDIR
PACKERFILE=packer-arm.json vagrant provision --provision-with build-image
