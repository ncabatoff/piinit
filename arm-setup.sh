#!/usr/bin/env bash

set -e

cwd=`pwd`
if [ "$(basename $cwd)" != "packer-builder-arm-image" ]; then
    echo "Expecting to be run from packer-builder-arm-image checkout" 1>&2
    exit 1
fi

if [ "`which jsonnet`" == "" ]; then
    echo "Installing go-jsonnet"
    go get -u github.com/fatih/color
    go get -u github.com/google/go-jsonnet/jsonnet
fi

# It is assumed that this script is invoked from within the packer-builder-arm-image
# git checkout.
vagrant up --provision-with build-env,packer-builder-arm-image


