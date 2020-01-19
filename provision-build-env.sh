#!/bin/bash

set -e
goVersion=1.13.6
packerVersion=1.3.4

sudo apt-get update -qq
sudo apt-get install -y \
    jq \
    git \
    wget \
    curl \
    vim \
    unzip

curl -s -O https://dl.google.com/go/go${goVersion}.linux-amd64.tar.gz
tar zxf go${goVersion}.linux-amd64.tar.gz

# Set GO paths for vagrant user
(
  echo 'export GOROOT=$HOME/go'
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

jsonnetVer=v0.14.0
jsonnetTgz=jsonnet-bin-$jsonnetVer-linux.tar.gz
wget -q -O /tmp/$jsonnetTgz https://github.com/google/jsonnet/releases/download/$jsonnetVer/$jsonnetTgz
sudo tar zxfC /tmp/$jsonnetTgz /usr/local/bin jsonnet

wget -q -O /tmp/jb https://github.com/jsonnet-bundler/jsonnet-bundler/releases/download/v0.2.0/jb-linux-amd64
chmod 755 /tmp/jb
sudo cp /tmp/jb /usr/local/bin

gogetterVer=1.4.1
gogetterZip=go-getter_${gogetterVer}_linux_amd64.zip
wget -q -O /tmp/$gogetterZip https://github.com/ncabatoff/go-getter/releases/download/v$gogetterVer/$gogetterZip
sudo unzip -o -d /usr/local/bin /tmp/$gogetterZip go-getter
