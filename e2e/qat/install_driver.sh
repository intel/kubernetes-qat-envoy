#!/bin/bash
cd ./vagrant
ansible-playbook -vvv -i inventory/hosts.ini configure-qat.yml
ansible-playbook -vvv -i inventory/hosts.ini configure-qat-envoy.yml --tags="driver"
