#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
BASE_DIR="$(realpath "${SCRIPT_DIR}/..")"

mkdir -p ${BASE_DIR}/build

ENVOY_DEV_IMAGE=${1}

CMD="-c 'CC=clang CXX=clang++ bazel --output_user_root=/build/ build //:envoy'"

OPTIND=2
while getopts "i" opt; do
    case $opt in
        i) CMD="" ;;
    esac
done

docker run \
       --rm \
       -it \
       -v ${BASE_DIR}/build:/build \
       -v ${BASE_DIR}:/envoy-qat \
       -w /envoy-qat \
       ${ENVOY_DEV_IMAGE} \
       /bin/bash -x -c \
       "
           groupadd --gid $(id -g) envoy
           useradd --uid $(id -u) --gid $(id -g) \
                   --no-create-home --home-dir=/envoy-qat envoy
           su -s /bin/bash envoy ${CMD}
       "
