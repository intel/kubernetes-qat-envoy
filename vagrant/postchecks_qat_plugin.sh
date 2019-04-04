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

echo "QAT plugin validation"

echo "Ensuring that envoy-qat:devel docker image exists..."
if ! sudo docker images | grep -E "envoy-qat.*devel"; then
    echo "envoy-qat:devel docker image doesn't exists"
    exit 1
fi

echo "Verifying intel-qat2-plugin daemonset is available..."
plugin_daemonset=$( kubectl get daemonset | grep intel-qat2-plugin)
if [[ -n $plugin_daemonset ]]; then
    if [[ $(echo "$plugin_daemonset" | awk '{print $2}') != $(echo "$plugin_daemonset" | awk '{print $6}') ]]; then
        echo "The Intel QAT daemonset plugin is not available yet"
        exit 1
    fi
else
    echo "The Intel QAT daemonset plugin is not created"
    exit 1
fi

qat_svc=$(sudo /etc/init.d/qat_service status | grep "There is .* QAT acceleration device(s) in the system:")
if [[ "$qat_svc" != *"0"* ]]; then
    echo "Ensuring that the intel-qat2-plugin pod has registered the devices..."
    for plugin_pod in $(kubectl get pods | grep intel-qat2 | awk '{print $1}'); do
        if ! kubectl logs "$plugin_pod" | grep -q "Start server for"; then
            echo "The Intel QAT daemonset has not started properly"
            exit 1
        fi
        if ! kubectl logs "$plugin_pod" | grep -q "Device plugin for"; then
            echo "The QAT devices weren't registered properly"
            exit 1
        fi
    done
fi

echo -e " \nPost-checks for qat plugin complete! "
