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

# Kubespray configuration values
kubespray_dest_folder=/opt
kubespray_version=2.8.3
kubespray_tarball=v$kubespray_version.tar.gz
kubespray_folder=$kubespray_dest_folder/kubespray-$kubespray_version

# uninstall_k8s() - Uninstall Kuberentes deployment
function uninstall_k8s {
    ansible-playbook -vvv -i ./inventory/hosts.ini $kubespray_folder/reset.yml --become
}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Deploying kubernetes"

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"

        sudo yum install -y wget
        wget https://github.com/kubernetes-sigs/kubespray/archive/$kubespray_tarball
        sudo tar -C $kubespray_dest_folder -xzf $kubespray_tarball
        sudo chown -R "$USER" $kubespray_folder
        rm $kubespray_tarball

        sudo -E pip install -r $kubespray_folder/requirements.txt
        echo "Kubespray configuration"

        rm -f ./inventory/group_vars/all.yml 2> /dev/null
        echo "kubeadm_enabled: true" | tee ./inventory/group_vars/all.yml
        if [[ ${HTTP_PROXY+x} = "x" ]]; then
             echo "http_proxy: \"$HTTP_PROXY\"" | tee --append ./inventory/group_vars/all.yml
        fi
        if [[ ${HTTPS_PROXY+x} = "x" ]]; then
            echo "https_proxy: \"$HTTPS_PROXY\"" | tee --append ./inventory/group_vars/all.yml
        fi
    fi

    ansible-playbook -vvv -i ./inventory/hosts.ini $kubespray_folder/cluster.yml --become | tee setup-kubernetes.log

    for vol in vol1 vol2 vol3; do
        if [[ ! -d /mnt/disks/$vol ]]; then
            sudo mkdir /mnt/disks/$vol
            sudo mount -t tmpfs -o size=5G $vol /mnt/disks/$vol
        fi
    done
    sudo -E gpasswd -a "$USER" docker

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

# install_dashboard() - Function that installs Helms, InfluxDB and Grafana Dashboard
function install_dashboard {
    local helm_version=v2.11.0
    local helm_tarball=helm-${helm_version}-linux-amd64.tar.gz

    if ! command -v helm; then
        wget http://storage.googleapis.com/kubernetes-helm/$helm_tarball
        tar -zxvf $helm_tarball -C /tmp
        rm $helm_tarball
        sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm
    fi

    helm init
    helm repo update

    if ! helm ls | grep -e metrics-db-qat; then
        helm install stable/influxdb --name metrics-db-qat -f influxdb_values.yml
    fi
    if ! helm ls | grep -e metrics-db-no-qat; then
        helm install stable/influxdb --name metrics-db-no-qat -f influxdb_values.yml
    fi
    if ! helm ls | grep -e metrics-dashboard; then
        helm install stable/grafana --name metrics-dashboard -f grafana_values.yml
    fi
}
