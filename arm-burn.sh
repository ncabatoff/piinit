#!/usr/bin/env bash

set -e
cwd=`pwd`
if [ "$(basename $cwd)" != "packer-builder-arm-image" ]; then
    echo "Expecting to be run from packer-builder-arm-image checkout" 1>&2
    exit 1
fi

# Note that the CLI was removed in Etcher 1.5.0, don't know why.
# Get the last release at
# https://github.com/balena-io/etcher/releases/download/v1.4.9/balena-etcher-cli-1.4.9-darwin-x64.tar.gz
balena-etcher -d /dev/disk2 -y output-arm-image.img
