#!/usr/bin/env bash

set -e

iso_url=$(jq -r .builders[0].iso_url < packer.json)
iso_base=$(basename "$iso_url")

test -d packer-builder-arm-image || git clone https://github.com/ncabatoff/packer-builder-arm-image
cd packer-builder-arm-image

go get github.com/hashicorp/go-getter/cmd/go-getter
test -d pkgbuilder || git clone https://github.com/ncabatoff/pkgbuilder
cd pkgbuilder
make packages
cd ..

test -f "$iso_base" || wget https://downloads.raspberrypi.org/raspbian_lite/images/"$iso_base"

vagrant up --provision-with build-env,packer-builder-arm-image
