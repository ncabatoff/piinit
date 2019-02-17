#!/usr/bin/env bash

jsonnet -o packer-docker.json packer-docker.jsonnet &&
  packer build -var consul=server -var nomad=server packer-docker.json