#!/usr/bin/env bash

set -e
cd packer-builder-arm-image
sudo /Users/ncc/Downloads/balena-etcher-cli-1.4.9-darwin-x64-dist/balena-etcher -d /dev/disk2 -y output-arm-image.img
