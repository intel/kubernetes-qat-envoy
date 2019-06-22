#!/bin/bash
# Script to install k8s with kubespray using scripts in vagrant dir.
cd ./vagrant
CPU_MANAGER_POLICY="static"
source _commons.sh
install_k8s
install_tls_secrets
