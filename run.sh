#!/usr/bin/env bash

set -e
cd packer-builder-arm-image
cp ~/.ssh/id_rsa.pub authorized_keys
cp ../*.json .
cp ../init-consul ../init-nomad .
PACKERFILE=packer.json vagrant provision --provision-with build-image
