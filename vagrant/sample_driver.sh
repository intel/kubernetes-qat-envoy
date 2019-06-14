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
#set -o xtrace

# Driver validation
qat_svc=$(sudo /etc/init.d/qat_service status | grep "There is .* QAT acceleration device(s) in the system:")
if [[ "$qat_svc" != *"0"* ]]; then
    echo "Running QAT sample's code"
    pushd /tmp/qat
    if [[ ! -f ./build/cpa_sample_code ]]; then
        sudo make samples-install
    fi
    pushd build
    echo "Running User space sample code"
    sudo ./cpa_sample_code
    if [[ -e ./cpa_sample_code.ko && $(lsmod | grep -q \"^qat_api\") ]]; then
        echo "Running Kernel space sample code"
        sudo dmesg -c
        sudo insmod ./cpa_sample_code.ko
        if ! dmesg | grep -q "Sample Code Complete"; then
            echo "There was a failure during the execution of sample code in Kernel space"
            exit 1
        fi
        sudo rmmod cpa_sample_code
    fi
    popd
fi
