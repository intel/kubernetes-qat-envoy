#!/bin/bash
# Script to check if deployment pods are ok.
DEPLOY=boringssl-envoy-deployment ./e2e/k8s/check-pod-dmesg.sh
DEPLOY=envoy-deployment ./e2e/k8s/check-pod-dmesg.sh
DEPLOY=envoy-deployment IMAGE=envoy-qat:clr ./e2e/k8s/check-pod-dmesg.sh
