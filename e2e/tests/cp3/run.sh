#!/bin/bash
# Script to deploy intel_qat_plugin (kernel mode) using tasks in vagrant dir.
./e2e/k8s/deploy-qat-plugin.sh
./vagrant/postchecks_qat_plugin.sh
