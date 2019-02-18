#!/usr/bin/env bash

jsonnet -o packer-docker.json packer-docker.jsonnet && packer build "$@" packer-docker.json