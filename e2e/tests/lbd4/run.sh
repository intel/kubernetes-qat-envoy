#!/bin/bash
# Script to check if deployment is incrementing QAT fw_counters under stress test.
DEPLOY=boringssl-envoy-deployment ./e2e/k8s/multiple-check-counters.sh
DEPLOY=envoy-deployment ./e2e/k8s/multiple-check-counters.sh
DEPLOY=envoy-deployment IMAGE=envoy-qat:clr ./e2e/k8s/multiple-check-counters.sh
