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
set -o nounset

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Deploying kubernetes"
    local dest_folder=/opt
    local version=2.8.3
    local tarball=v$version.tar.gz

    sudo yum install -y wget
    wget https://github.com/kubernetes-sigs/kubespray/archive/$tarball
    sudo tar -C $dest_folder -xzf $tarball
    sudo chown -R "$USER" $dest_folder/kubespray-$version
    rm $tarball

    sudo -E pip install -r $dest_folder/kubespray-$version/requirements.txt
    rm -f ./inventory/group_vars/all.yml 2> /dev/null
    echo "kubeadm_enabled: true" | tee ./inventory/group_vars/all.yml
    if [[ -n "${http_proxy+x}" ]]; then
        echo "http_proxy: \"$http_proxy\"" | tee --append ./inventory/group_vars/all.yml
    fi
    if [[ -n "${https_proxy+x}" ]]; then
        echo "https_proxy: \"$https_proxy\"" | tee --append ./inventory/group_vars/all.yml
    fi
    ansible-playbook -vvv -i ./inventory/hosts.ini $dest_folder/kubespray-$version/cluster.yml --become | tee setup-kubernetes.log

    # Configure environment
    mkdir -p "$HOME/.kube"
    cp ./inventory/artifacts/admin.conf "$HOME/.kube/config"
    _configure_dashboard
}

# _configure_dashboard() - Configure the Kubernetes dashboard and creates
# a information file with the authentication credentials
function _configure_dashboard {
    local info_file=$HOME/kubernetes_info.txt

    # Expose Dashboard using NodePort
    node_port=30080
    KUBE_EDITOR="sed -i \"s|type\: ClusterIP|type\: NodePort|g\"" kubectl -n kube-system edit service kubernetes-dashboard
    KUBE_EDITOR="sed -i \"s|nodePort\: .*|nodePort\: $node_port|g\"" kubectl -n kube-system edit service kubernetes-dashboard

    master_ip=$(kubectl cluster-info | grep "Kubernetes master" | awk -F ":" '{print $2}')

    printf "Kubernetes Info\n===============\n" > "$info_file"
    {
    echo "Dashboard URL: https:$master_ip:$node_port"
    echo "Admin user: kube"
    echo "Admin password: secret"
    } >> "$info_file"
}
