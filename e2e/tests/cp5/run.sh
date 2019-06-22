#!/bin/bash
# to chek if deployment is ready and pod have set proper env variables.
DEPLOY=boringssl-envoy-deployment ./e2e/k8s/check-pod-env.sh
DEPLOY=envoy-deployment ./e2e/k8s/check-pod-env.sh
DEPLOY=envoy-deployment IMAGE=envoy-qat:clr ./e2e/k8s/check-pod-env.sh
