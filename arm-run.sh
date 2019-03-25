#!/usr/bin/env bash

set -e

cwd=`pwd`
if [ "$(basename $cwd)" != "packer-builder-arm-image" ]; then
    echo "Expecting to be run from packer-builder-arm-image checkout" 1>&2
    exit 1
fi

if [ $# -gt 1 ]; then
    echo "Usage: $0 [varsfile.json]" 1>&2
    exit 1
fi

varsfile=$1
createdVarsFile=""
if [ $# == 0 ]; then
    varsfile=pivariables.json
    if [ ! -f $varsfile ]; then
        createdVarsFile=$varsfile
        encrypt=`dd if=/dev/urandom bs=16 count=1 2>/dev/null | base64`
        echo "{consul_encrypt: '$encrypt'}" > $varsfile
        echo "No arg file provided, using generated consul encryption key."
        echo "Key persisted in $varsfile, to reuse next time run:"
        echo "  $0 $varsfile"
    fi
fi

PACKERFILE="packer-arm.json"
echo "Building $PACKERFILE, which will contain any sensitive data in input variables."
echo "Normally this will be automatically cleaned up, but may not if script is aborted."
function cleanup {
    rm $PACKERFILE
    if [ "$createdVarsFile" != "" ]; then
        echo
        echo "WARNING: created vars file $createdVarsFile.  This file contains the"
        echo "         consul gossip encryption key.  It is convenient while "
        echo "         experimenting to keep this file but it is a security risk."
        echo "         Consider deleting it instead."
    fi
}
trap cleanup EXIT

source=$(dirname $0)
jsonnet -o $PACKERFILE --tla-code-file variables=$varsfile $source/packer-arm.jsonnet

# don't assume jq is installed, use grep/sed instead
# iso_url=$(jq -r .builders[0].iso_url < packer-arm.json)
iso_url=$(grep '"iso_url":' < packer-arm.json |sed -e 's/"iso_url",//' -e s/,//)
iso_base=$(basename "$iso_url")
if [ ! -f "$iso_base" ]; then
    echo "Downloading ARM OS image $iso_base"
    curl -s -o "$iso_base" "https://downloads.raspberrypi.org/raspbian_lite/images/${iso_base}"
fi

echo "Copying ~/.ssh/id_rsa.pub to target authorized_keys"
cp ~/.ssh/id_rsa.pub ./authorized_keys

mkdir -p packages
cp -a $source/packages/a[lr]* packages/

PACKERFILE=$PACKERFILE vagrant provision --provision-with build-image

