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

echo "QAT plugin validation"
# TODO:
# - Verify that qat devices are configured properly /etc/c6xx_dev*.conf (NumProcesses, NumberCyInstances and NumberDcInstances in SSH section)
# - Verify that intel-qat2-plugin daemonset is available
# - Ensure that intel-qat2-plugin pod has registered the devices with this log entry (Device plugin for cy*_dc* registered)
# - Ensure that envoy-qat:devel docker image exists.
