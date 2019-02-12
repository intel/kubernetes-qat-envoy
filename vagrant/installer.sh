#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019 Intel Corporation
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o xtrace
set -o errexit
set -o nounset

source _commons.sh

./prechecks.sh

# Configure SSH keys for ansible communication
rm -f ~/.ssh/id_rsa*
echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod og-wx ~/.ssh/authorized_keys

# Install dependencies
sudo swapoff -a
curl -sL https://bootstrap.pypa.io/get-pip.py | sudo python
sudo -E pip install ansible
sudo mkdir -p /etc/ansible/
sudo cp ./ansible.cfg /etc/ansible/ansible.cfg
ansible-galaxy install -r ./galaxy-requirements.yml --ignore-errors

# QAT Driver installation
ansible-playbook -vvv -i ./inventory/hosts.ini configure-qat.yml | tee setup-qat.log
./postchecks_qat_driver.sh

# Kubernetes installation
install_k8s

# QAT Plugin installation
ansible-playbook -vvv -i ./inventory/hosts.ini configure-qat-envoy.yml | tee setup-qat-envoy.log
./postchecks_qat_plugin.sh
