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
set -o errexit
set -o xtrace

echo "QAT driver validation"

# Driver validation
supported_dev="c6xx dh895xcc"
qat_svc=$(sudo service qat_service status | grep "There is .* QAT acceleration device(s) in the system:")
if [[ "$qat_svc" != *"0"* ]]; then
    sudo pip install crudini --quiet
    devices=$(sudo service qat_service status | grep 'state: up')
    while read -r device; do
        dev_type=$(echo "$device" | awk '{print $4}' | tr -d ',')
        if [[ "$supported_dev" != *"$dev_type"* ]]; then
            echo "The $dev_type device type is not supported by QAT envoy plugin"
            exit 1
        fi
        dev_name=$(echo "$device" | awk '{print substr($4,0,4) substr($1,4,8)}')
        for ssl_key in NumProcesses NumberCyInstances NumberDcInstances; do
            sudo crudini --get --existing "/etc/$dev_name.conf" SSL $ssl_key > /dev/null
        done
    done <<< "$devices"
else
    echo "WARNING: There is no QAT devides running in this node"
    sleep 15
fi
