#!/usr/bin/env bash
#
# Copyright (c) 2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

die() {
	msg="$*"
	echo "ERROR: $msg" >&2
	exit 1
}

info() {
	echo -e "INFO: $*"
}

jobs() {
	j=$(($(nproc)-1))
	[ $j -le 0 ] && echo 1
	echo $j
}
