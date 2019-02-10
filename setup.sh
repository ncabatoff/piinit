#!/usr/bin/env bash

set -e

iso_url=$(jq -r .builders[0].iso_url < packer.json)
iso_base=$(basename "$iso_url")

test -d packer-builder-arm-image || git clone https://github.com/ncabatoff/packer-builder-arm-image
cd packer-builder-arm-image

test -d terraform-aws-consul || git clone https://github.com/ncabatoff/terraform-aws-consul
test -d terraform-aws-nomad || git clone https://github.com/ncabatoff/terraform-aws-nomad

test -f "$iso_base" || wget https://downloads.raspberrypi.org/raspbian_lite/images/"$iso_base"

vagrant up --provision-with build-env,packer-builder-arm-image
