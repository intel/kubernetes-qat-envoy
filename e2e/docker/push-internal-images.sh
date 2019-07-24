#!/bin/bash
# Script to publish qat images in the internal registry.
source ./e2e/vars.sh

docker tag envoy-qat:devel ${DOCKER_QAT_REGISTRY}/envoy-qat:devel
docker tag envoy-qat:clr ${DOCKER_QAT_REGISTRY}/envoy-qat:clr
docker tag envoy-boringssl-qat:devel ${DOCKER_QAT_REGISTRY}/envoy-boringssl-qat:devel
docker tag intel-qat-plugin:devel ${DOCKER_QAT_REGISTRY}/intel-qat-plugin:devel

docker push ${DOCKER_QAT_REGISTRY}/envoy-qat:devel
docker push ${DOCKER_QAT_REGISTRY}/envoy-qat:clr
docker push ${DOCKER_QAT_REGISTRY}/envoy-boringssl-qat:devel
docker push ${DOCKER_QAT_REGISTRY}/intel-qat-plugin:devel
