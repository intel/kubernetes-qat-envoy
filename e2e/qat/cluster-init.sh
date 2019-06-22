#!/bin/bash
# Install qat driver, docker, k8s, downloads required images and deploy qat plugin,
# using scripts in vagrant dir.

./e2e/qat/install_deps.sh
./e2e/qat/install_driver.sh
./e2e/docker/install.sh
./e2e/docker/set-registry.sh
./e2e/k8s/install.sh
./e2e/docker/pull-internal-images.sh
./e2e/k8s/deploy-qat-plugin.sh
sleep 60s
