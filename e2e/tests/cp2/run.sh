#!/bin/bash
# Install k8s cluster and pull images.
./e2e/docker/install.sh
./e2e/docker/set-registry.sh
./e2e/docker/pull-internal-images.sh
./e2e/k8s/install.sh && sleep 60s
./e2e/k8s/check-cluster.sh
