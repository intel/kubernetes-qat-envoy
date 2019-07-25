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

source _commons.sh

install_dashboard
if ! kubectl get secret --no-headers | grep -e envoy-tls-secret; then
    openssl req -x509 -new -batch -nodes -subj '/CN=localhost' -keyout /tmp/key.pem -out /tmp/cert.pem
    kubectl create secret tls envoy-tls-secret --cert /tmp/cert.pem --key /tmp/key.pem
fi
kubectl apply -f k8s_resources/"${CONTAINER_MANAGER:-docker}/"
qat_svc=$(sudo /etc/init.d/qat_service status | grep "There is .* QAT acceleration device(s) in the system:")
if [[ "$qat_svc" != *"0"* ]]; then
    kubectl apply -f k8s_resources/"${CONTAINER_MANAGER:-docker}/qat/"
fi
