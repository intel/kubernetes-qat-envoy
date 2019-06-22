#!/bin/bash
# Script to check if all deployments increase QAT counters (single).
DEPLOY=boringssl-envoy-deployment ./e2e/k8s/single-check-counters.sh
DEPLOY=envoy-deployment ./e2e/k8s/single-check-counters.sh
DEPLOY=envoy-deployment IMAGE=envoy-qat:clr ./e2e/k8s/single-check-counters.sh
