#!/usr/bin/env bash

set -e
sudo supervisorctl stop nomad consul
sudo dpkg -i /vagrant/packages/all/consul-local.deb
docker kill `docker ps -q`
sudo killall nomad
sudo docker network rm hashinet
sudo supervisorctl start consul