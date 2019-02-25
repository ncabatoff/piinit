#!/usr/bin/env bash

set -e
cp ~/.ssh/id_rsa.pub ./authorized_keys
source=$(dirname $0)
make -C $source
cp $source/*.json $source/consul-client-*.hcl .

PACKERFILE=packer-arm.json vagrant provision --provision-with build-image
