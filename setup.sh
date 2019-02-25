#!/usr/bin/env bash

set -e

# It is assumed that this script is invoked from within the packer-builder-arm-image
# git checkout.
# vagrant up --provision-with build-env,packer-builder-arm-image

#if [ "`which jsonnet`" == "" ]; then
#    echo "Installing go-jsonnet"
#    go get github.com/fatih/color github.com/google/go-jsonnet
#    cd $GOPATH/src/github.com/google/go-jsonnet/jsonnet
#    go install
#fi

#echo "Downloading ARM OS image"
#iso_url=$(jq -r .builders[0].iso_url < packer-arm.json)
#iso_base=$(basename "$iso_url")
#test -f "$iso_base" || wget https://downloads.raspberrypi.org/raspbian_lite/images/"$iso_base"

