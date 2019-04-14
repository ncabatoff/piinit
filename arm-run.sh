#!/usr/bin/env bash

set -e

cwd=`pwd`
if [ "$(basename $cwd)" != "packer-builder-arm-image" ]; then
    echo "Expecting to be run from packer-builder-arm-image checkout" 1>&2
    exit 1
fi

source=$(dirname $0)

usage="Usage: $0
or
   $0 packerfile.json
or
   $0 packerfile.json packerfile.jsonnet"

case $# in
2)  PACKERFILE="$1"
    jsonnet -o $PACKERFILE $source/`basename "$PACKERFILE" .json`.jsonnet
    ;;
1)  PACKERFILE="$1"
    ;;
0)  PACKERFILE="packer-arm.json"
    ;;
*)  echo "$usage" 1>&2
    exit 1
    ;;
esac

if [ ! -f "$PACKERFILE" ]; then
    echo "$usage" 1>&2
    exit 1
fi


# don't assume jq is installed, use grep/sed instead
# iso_url=$(jq -r .builders[0].iso_url < $PACKERFILE)
iso_url=$(grep '"iso_url":' < $PACKERFILE |sed -e 's/"iso_url": "//' -e 's/",//')
iso_base=$(basename "$iso_url")
if [ ! -f "$iso_base" ]; then
    echo "Downloading ARM OS image $iso_base"
    curl -s -o "$iso_base" "https://downloads.raspberrypi.org/raspbian_lite/images/${iso_base}"
fi

echo "Copying ~/.ssh/id_rsa.pub to target authorized_keys"
cp ~/.ssh/id_rsa.pub ./authorized_keys

mkdir -p packages
cp -a $source/packages/{all,arm*} packages/

PACKERFILE=$PACKERFILE vagrant provision --provision-with build-image

