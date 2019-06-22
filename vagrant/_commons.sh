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
kubespray_folder=${KUBESPRAY_FOLDER:-/opt/kubespray}

# uninstall_k8s() - Uninstall Kubernetes deployment
function uninstall_k8s {
    ansible-playbook -vvv -i ./inventory/hosts.ini $kubespray_folder/reset.yml --become
}

# uninstall_docker() - Removes docker packages and configs.
function uninstall_docker {
  docker system prune -a -f
  source /etc/os-release || source /usr/lib/os-release
  case ${ID,,} in
      rhel|centos|fedora)
          sudo yum remove -y docker-ce docker-ce-cli
      ;;
      clear-linux-os)
          sudo swupd bundle-remove containers-basic
      ;;
  esac
  sudo rm -rf /etc/systemd/system/docker.service.d
  sudo rm -rf /etc/docker
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
            sudo -E curl -fsSL https://get.docker.com/ | sh
        ;;
    esac

    sudo systemctl start docker # Not all distros starts docker by default.
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
    # NOTE: this installs runc in a kubespray non-expected folder https://github.com/kubernetes-sigs/kubespray/commit/2db289811261d90cdb335307a3ff43785fdca45a#diff-4cf53be44e33d00a3586c71ccf2028d2
    if [[ $(command -v runc ) == "/usr/sbin/runc" ]]; then
        sudo rm -rf /usr/bin/runc
        sudo ln -s /usr/sbin/runc /usr/bin/runc
    fi
}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    # Defaulting variables values and adding the possibility of overwrite them,
    # setting global variables.
    local kubespray_version=${KUBESPAY_VERSION:-v2.10.3}
    local cpu_manager_policy=${CPU_MANAGER_POLICY:-none}
    local kube_reserved_cpu=${KUBE_RESERVED_CPU:-1}
    local kube_reserved_memory=${KUBE_RESERVED_CPU:-2Gi}
    local kube_reserved_storage=${KUBE_RESERVED_STORAGE:-1Gi}
    local system_reserved_cpu=${SYSTEM_RESERVED_CPU:-1}
    local system_reserved_memory=${SYSTEM_RESERVED_CPU:-2Gi}
    local system_reserved_storage=${SYSTEM_RESERVED_STORAGE:-1Gi}

    echo "Deploying kubernetes"

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"

        # shellcheck disable=SC1091
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            rhel|centos|fedora)
                sudo -E yum install -y git
            ;;
            clear-linux-os)
                sudo -E swupd bundle-add git
            ;;
        esac
        sudo -E git clone --depth 1 https://github.com/kubernetes-sigs/kubespray $kubespray_folder -b $kubespray_version
        sudo chown -R "$USER" $kubespray_folder
        pushd $kubespray_folder
        sudo -E pip install -r ./requirements.txt
        make mitogen
        popd

        echo "Kubespray configuration"
        mkdir -p ./inventory/group_vars/
        cp all.yml ./inventory/group_vars/all.yml
        cp k8s-cluster.yml ./inventory/group_vars/k8s-cluster.yml
        if [[ "${CONTAINER_MANAGER:-docker}" == "crio" ]]; then
            case ${ID,,} in
                rhel|centos|fedora)
                    sudo -E yum install -y wget
                ;;
            esac
            wget -O $kubespray_folder/roles/container-engine/cri-o/templates/crio.conf.j2 https://raw.githubusercontent.com/kubernetes-sigs/kubespray/2db289811261d90cdb335307a3ff43785fdca45a/roles/container-engine/cri-o/templates/crio.conf.j2
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

    # If CPU_MANAGER_POLICY was speficied as static then the required values are,
    # passed as extra args to kubelet.
    if [[ "${cpu_manager_policy}" == "static" ]]; then
      echo "KUBELET_EXTRA_ARGS=\"--kube-reserved=cpu=${kube_reserved_cpu},memory=${kube_reserved_memory},ephemeral-storage=${kube_reserved_storage} --system-reserved=cpu=${system_reserved_cpu},memory=${system_reserved_memory},ephemeral-storage=${system_reserved_storage} --cpu-manager-policy=static --feature-gates=CPUManager=true\""  > /etc/sysconfig/kubelet
    else
      echo "" > /etc/sysconfig/kubelet
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
}

# install_dashboard() - Function that installs Helms, InfluxDB and Grafana Dashboard
function install_dashboard {
    if ! command -v helm; then
        sudo -E curl -L https://git.io/get_helm.sh | bash

        helm init --wait
        kubectl create serviceaccount --namespace kube-system tiller
        kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
        kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
        kubectl rollout status deployment/tiller-deploy --timeout=5m --namespace kube-system
        #helm init --service-account tiller --upgrade
        helm repo update
    fi

    if ! helm ls | grep -e metrics-db-qat; then
        helm install stable/influxdb --name metrics-db-qat -f influxdb_values.yml
    fi
    if ! helm ls | grep -e metrics-db-no-qat; then
        helm install stable/influxdb --name metrics-db-no-qat -f influxdb_values.yml
    fi
    if ! helm ls | grep -e metrics-dashboard; then
        helm install stable/grafana --name metrics-dashboard -f grafana_values.yml
    fi
    if ! helm ls | grep -e monitoring; then
        helm install stable/prometheus --name monitoring -f prometheus_values.yml
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

# configure_ansible_ssh_keys() - Creates the required ssh keys to handle comm
# between ansible and host.
function configure_ansible_ssh_keys {
  rm -f ~/.ssh/id_rsa*
  echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
  chmod og-wx ~/.ssh/authorized_keys
}

# generates_inventory_file() - Initializes the inventory host file required for
# ansible.
function generates_inventory_file {
    hostname=$(hostname)

    rm -rf ./inventory
    mkdir ./inventory
    cat << EOF > ./inventory/hosts.ini
[all]
$hostname

[kube-master]
$hostname

[kube-node]
$hostname

[etcd]
$hostname

[qat-node]
$hostname

[k8s-cluster:children]
kube-node
kube-master
EOF
}

# install_deps() - Pre-installation of deps to run all-in-one script.
function install_deps {
  swap_dev=$(sed -n -e 's#^/dev/\([0-9a-z]*\).*#dev-\1.swap#p' /proc/swaps)
  if [ -n "$swap_dev" ]; then
      sudo systemctl mask "$swap_dev"
  fi
  sudo swapoff -a
  if [ -e /etc/fstab ]; then
      sudo sed -i '/ swap / s/^/#/' /etc/fstab
  fi
  # shellcheck disable=SC1091
  source /etc/os-release || source /usr/lib/os-release
  case ${ID,,} in
      rhel|centos|fedora)
          sudo -E curl -sL https://bootstrap.pypa.io/get-pip.py | sudo -E python
      ;;
      clear-linux-os)
          sudo -E swupd bundle-add python3-basic
      ;;
  esac
  sudo mkdir -p /etc/ansible/
  sudo cp ./ansible.cfg /etc/ansible/ansible.cfg
  sudo -E pip install ansible==2.7.10
  ansible-galaxy install -r ./galaxy-requirements.yml --ignore-errors
}

# install_tls_secrets() - Creates cert and key to deploy them as a k8s secret.
function install_tls_secrets {
  if ! kubectl get secret --no-headers | grep -e envoy-tls-secret; then
      openssl req -x509 -new -batch -nodes -subj '/CN=localhost' -keyout /tmp/key.pem -out /tmp/cert.pem
      kubectl create secret tls envoy-tls-secret --cert /tmp/cert.pem --key /tmp/key.pem
  fi
}
