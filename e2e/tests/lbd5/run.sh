#!/bin/bash
# Script to check if we can get a response from envoy in other machine.
source ./e2e/vars.sh

cat ${SSH_KEY} > ./key.pem
chmod 400 ./key.pem
CLIENT=${K6_RUNNER} DEPLOY=boringssl-envoy-deployment ./e2e/k8s/check-svc.sh
CLIENT=${K6_RUNNER} DEPLOY=envoy-deployment ./e2e/k8s/check-svc.sh
CLIENT=${K6_RUNNER} DEPLOY=envoy-deployment IMAGE=envoy-qat:clr ./e2e/k8s/check-svc.sh
rm -rf ./key.pem
