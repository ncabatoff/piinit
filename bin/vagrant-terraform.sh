#!/usr/bin/env bash

cd /home/vagrant/home-nomad-jobs/terraform
(cd ../gendash && make ../dashboards.tgz) && terraform apply -auto-approve
