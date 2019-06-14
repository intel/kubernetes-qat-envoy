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
set -o nounset

function usage {
    cat <<EOF
usage: $0 -r <REPO_URL> -d <TEST_DIR> -b <BRANCH>
Run functional tests in different screen sessions that verifies functionality
of this project

Argument:
    -r  URL repository
    -d  Destination directory
    -b  Branch version to be tested
EOF
}

repo="$(git remote -v | awk 'NR==1{print $2}')"
dest="/tmp/integration_tests"
branch="$(git rev-parse --abbrev-ref HEAD)"
prefix_screen="qat_test_"
while getopts ":r:d:b:" OPTION; do
    case $OPTION in
    r)
        repo=$OPTARG
        ;;
    d)
        dest=$OPTARG
        ;;
    b)
        branch=$OPTARG
        ;;
    \?)
        usage
        exit 1
        ;;
    esac
done


function run {
    local distro=$1
    local manager=$2

    functional_test="${distro}_${manager}"
    bash="QAT_DISTRO=${distro} QAT_CONTAINER_MANAGER=${manager}"

    echo "[INFO - $(date)] $functional_test - Cloning repo $repo"
    screen -d -S "$prefix_screen$functional_test" -m bash -c "git clone --recurse-submodules --depth 1 $repo -b $branch $dest/$functional_test; cd $dest/$functional_test/vagrant; $bash vagrant up; exec sh"
}

# Setup - Cleanup old resources
for line in $(screen -ls | grep qat_test_ | awk '{print $1}'); do
    if [[ -n $line ]]; then
        echo "[INFO - $(date)] Killing ${line#*.} screen"
        screen -X -S "${line#*.}" quit
    fi
done
for vagrant_id in $(vagrant global-status --prune | grep running | grep "$dest" | awk '{print $1}'); do
    if [[ -n $vagrant_id ]]; then
        vagrant destroy -f "$vagrant_id"
    fi
done
rm -rf "$dest"
mkdir -p "$dest"

# Run
for distro in centos clearlinux; do
    for manager in docker crio; do
        run "$distro" "$manager"
    done
done

screen -d -S "${prefix_screen}dashboard" -m watch "find $dest -name \"installer.log\" | xargs tail -n 6"
