#!/bin/bash
# Script to deploy k8s plugin for QAT
DEST=$PWD
cd ./vagrant
ansible-playbook -vvv -i inventory/hosts.ini configure-qat-envoy.yml -e qat_envoy_dest=$DEST --tags="plugin" -u root
