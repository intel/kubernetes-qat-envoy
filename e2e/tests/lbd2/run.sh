#!/bin/bash
# Script to check if svc in deployment is accesible.
DEPLOY=boringssl-envoy-deployment ./e2e/k8s/check-svc.sh
DEPLOY=envoy-deployment ./e2e/k8s/check-svc.sh
DEPLOY=envoy-deployment IMAGE=envoy-qat:clr ./e2e/k8s/check-svc.sh
