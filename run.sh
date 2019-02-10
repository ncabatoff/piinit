#!/usr/bin/env bash

set -e
WORKDIR=packer-builder-arm-image
cp ~/.ssh/id_rsa.pub $WORKDIR/authorized_keys
cp -a *.json init-consul init-nomad {install,run}-node_exporter $WORKDIR
cd $WORKDIR
PACKERFILE=packer.json vagrant provision --provision-with build-image
