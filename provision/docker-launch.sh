#!/usr/bin/env bash

set -e

. /home/vagrant/.piinit.profile

docker network create --subnet $NETWORK.0/24 --gateway $NETWORK.1 hashinet 2>/dev/null || true

for i in 1 2 3; do
  docker run --rm -d --name hashinode${i} --network hashinet --ip $NETWORK.5${i} \
    -p $(($i+14645)):4646 -p $(($i+18499)):8500 piinit/hashinode-cn
done

docker run --rm -d --name hashinode0 --network hashinet  --ip $NETWORK.50 \
  -p 19090:9090 piinit/hashinode-mon

