#!/bin/bash

set -e
goVersion=1.11
packerVersion=1.3.4

sudo apt-get update -qq
sudo apt-get install -y software-properties-common
sudo add-apt-repository --yes ppa:gophers/archive

# Install required packages
sudo apt-get update
sudo apt-get install -y \
    jq \
    git \
    wget \
    curl \
    vim \
    unzip \
    golang-${goVersion}-go

# Set GO paths for vagrant user
(
  echo "export GOROOT=/usr/lib/go-${goVersion}"
  echo 'export GOPATH=$HOME/work'
  echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin'
  echo 'export NETWORK=192.168.2'
) > /home/vagrant/.piinit.profile
echo ". /home/vagrant/.piinit.profile" >> /home/vagrant/.profile
. /home/vagrant/.piinit.profile

# Download and install packer
[[ -e /tmp/packer ]] && rm /tmp/packer
wget https://releases.hashicorp.com/packer/${packerVersion}/packer_${packerVersion}_linux_amd64.zip \
    -q -O /tmp/packer_${packerVersion}_linux_amd64.zip
pushd /tmp
unzip -u packer_${packerVersion}_linux_amd64.zip
sudo cp packer /usr/local/bin
popd

# Download and install go-jsonnet and jsonnet-bundler
go get -u github.com/fatih/color
go get -u github.com/google/go-jsonnet/jsonnet
go get -u github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
go get -u github.com/hashicorp/go-getter
go get -u github.com/cheggaaa/pb
go install github.com/hashicorp/go-getter/cmd/go-getter