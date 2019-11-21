#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
BASE_DIR="$(realpath "${SCRIPT_DIR}/..")"

CPUSET_PARAM=""
if [[ -n $1 ]]; then
  CPUSET_PARAM="--cpuset-cpus=$1"
fi

CONFIG_FILE_PARAM="${BASE_DIR}/examples/boringssl-envoy-conf.yaml"
if [[ -n $2 ]]; then
  CONFIG_FILE_PARAM="$2"
fi

# Generate the Docker device parameters.
DEVS_PARAM="--device=/dev/qat_dev_processes --device=/dev/qat_adf_ctl --device=/dev/usdm_drv"
UIO_DEVS=(/dev/uio*)
N_DEVS=${#UIO_DEVS[@]}
(( LAST_DEV = N_DEVS - 1 ))
for i in $(seq 0 $LAST_DEV); do
  DEVS_PARAM="$DEVS_PARAM --device=${UIO_DEVS[i]}"
done

# Check if the keys have been generated as in the README.md file instructs; if they haven't, generate them.
if [[ ! -f "${BASE_DIR}"/cert.pem || ! -f "${BASE_DIR}"/key.pem ]]; then
  openssl req -x509 -new -batch -nodes -subj '/CN=localhost' -keyout "${BASE_DIR}"/key.pem -out "${BASE_DIR}"/cert.pem
fi

docker run --rm -ti -p 9000:9000 $CPUSET_PARAM --security-opt seccomp=unconfined --security-opt apparmor=unconfined $DEVS_PARAM --cap-add=SYS_ADMIN --cap-add=IPC_LOCK -v "${BASE_DIR}"/cert.pem:/etc/envoy/tls/tls.crt -v "${BASE_DIR}"/key.pem:/etc/envoy/tls/tls.key -v $CONFIG_FILE_PARAM:/etc/envoy/config/envoy-conf.yaml envoy-boringssl-qat:devel --cpuset-threads
