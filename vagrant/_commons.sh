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
kubespray_folder=/opt/kubespray

# uninstall_k8s() - Uninstall Kubernetes deployment
function uninstall_k8s {
    ansible-playbook -vvv -i ./inventory/hosts.ini $kubespray_folder/reset.yml --become
}

# install_docker() - Download and install docker-engine
function install_docker {
    if docker version &>/dev/null; then
        return
    fi

    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        clear-linux-os)
            sudo -E swupd bundle-add containers-basic
            sudo systemctl unmask docker.service
        ;;
        *)
            curl -fsSL https://get.docker.com/ | sh
        ;;
    esac

    sudo mkdir -p /etc/systemd/system/docker.service.d
    if [ -n "$HTTP_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
        echo "Environment=\"HTTP_PROXY=$HTTP_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/http-proxy.conf
    fi
    if [ -n "$HTTPS_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/https-proxy.conf
        echo "Environment=\"HTTPS_PROXY=$HTTPS_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/https-proxy.conf
    fi
    if [ -n "$NO_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/no-proxy.conf
        echo "Environment=\"NO_PROXY=$NO_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/no-proxy.conf
    fi
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    sudo usermod -aG docker "$USER"
}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Deploying kubernetes"

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"

        # shellcheck disable=SC1091
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            rhel|centos|fedora)
                sudo yum install -y git
            ;;
            clear-linux-os)
                sudo swupd bundle-add git
            ;;
        esac
        sudo git clone --depth 1 https://github.com/kubernetes-sigs/kubespray $kubespray_folder -b release-2.10
        sudo chown -R "$USER" $kubespray_folder
        sudo -E pip install -r $kubespray_folder/requirements.txt

        echo "Kubespray configuration"
        mkdir -p ./inventory/group_vars/
        cp all.yml ./inventory/group_vars/all.yml
        cp k8s-cluster.yml ./inventory/group_vars/k8s-cluster.yml
        if [[ "${CONTAINER_MANAGER:-docker}" == "crio" ]]; then
            echo "CRI-O configuration"
            {
            echo "download_container: false"
            echo "skip_downloads: false"
            } >> ./inventory/group_vars/all.yml
            sed -i 's/^etcd_deployment_type: .*$/etcd_deployment_type: host/' ./inventory/group_vars/k8s-cluster.yml
            sed -i 's/^kubelet_deployment_type: .*$/kubelet_deployment_type: host/' ./inventory/group_vars/k8s-cluster.yml
            sed -i 's/^container_manager: .*$/container_manager: crio/' ./inventory/group_vars/k8s-cluster.yml
            # TODO: https://github.com/kubernetes-sigs/kubespray/issues/4737
            sed -i 's/^kube_version: .*$/kube_version: v1.13.5/' ./inventory/group_vars/k8s-cluster.yml
            # (TODO): https://github.com/kubernetes-sigs/kubespray/pull/4607
            sudo mkdir -p /etc/systemd/system/crio.service.d/
            if [ -n "$HTTP_PROXY" ]; then
                echo "[Service]" | sudo tee /etc/systemd/system/crio.service.d/http-proxy.conf
                echo "Environment=\"HTTP_PROXY=$HTTP_PROXY\"" | sudo tee --append /etc/systemd/system/crio.service.d/http-proxy.conf
            fi
            if [ -n "$HTTPS_PROXY" ]; then
                echo "[Service]" | sudo tee /etc/systemd/system/crio.service.d/https-proxy.conf
                echo "Environment=\"HTTPS_PROXY=$HTTPS_PROXY\"" | sudo tee --append /etc/systemd/system/crio.service.d/https-proxy.conf
            fi
            if [ -n "$NO_PROXY" ]; then
                echo "[Service]" | sudo tee /etc/systemd/system/crio.service.d/no-proxy.conf
                echo "Environment=\"NO_PROXY=$NO_PROXY\"" | sudo tee --append /etc/systemd/system/crio.service.d/no-proxy.conf
            fi
        fi
        if [[ ${HTTP_PROXY+x} = "x" ]]; then
            echo "http_proxy: \"$HTTP_PROXY\"" | tee --append ./inventory/group_vars/all.yml
        fi
        if [[ ${HTTPS_PROXY+x} = "x" ]]; then
            echo "https_proxy: \"$HTTPS_PROXY\"" | tee --append ./inventory/group_vars/all.yml
        fi
        if [[ ${NO_PROXY+x} = "x" ]]; then
            echo "no_proxy: \"$NO_PROXY\"" | tee --append ./inventory/group_vars/all.yml
        fi
    fi

    ansible-playbook -vvv -i ./inventory/hosts.ini $kubespray_folder/cluster.yml --become | tee setup-kubernetes.log

    for vol in vol1 vol2 vol3; do
        if [[ ! -d /mnt/disks/$vol ]]; then
            sudo mkdir -p /mnt/disks/$vol
            sudo mount -t tmpfs -o size=5G $vol /mnt/disks/$vol
        fi
    done

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

# parse_yaml() - Function that returns the yaml values of a given key
function parse_yaml {
    python -c "import yaml;print(yaml.safe_load(open('$1'))$2)"
}

# vercmp() - Function that compares two versions
function vercmp {
    local v1=$1
    local op=$2
    local v2=$3
    local result

    # sort the two numbers with sort's "-V" argument.  Based on if v2
    # swapped places with v1, we can determine ordering.
    result=$(echo -e "$v1\n$v2" | sort -V | head -1)

    case $op in
        "==")
            [ "$v1" = "$v2" ]
            return
            ;;
        ">")
            [ "$v1" != "$v2" ] && [ "$result" = "$v2" ]
            return
            ;;
        "<")
            [ "$v1" != "$v2" ] && [ "$result" = "$v1" ]
            return
            ;;
        ">=")
            [ "$result" = "$v2" ]
            return
            ;;
        "<=")
            [ "$result" = "$v1" ]
            return
            ;;
        *)
            die $LINENO "unrecognised op: $op"
            ;;
    esac
}
