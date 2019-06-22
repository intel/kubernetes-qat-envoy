#!/bin/bash
# Run handshake1 and loopback1 test over k8s.
DEPLOY=envoy-deployment RUN=k8s TEST=handshake1 TAG=openssl ./e2e/k6/run.sh
DEPLOY=envoy-deployment RUN=k8s TEST=handshake1 TAG=openssl-clr IMAGE=envoy-qat:clr ./e2e/k6/run.sh
DEPLOY=boringssl-envoy-deployment RUN=k8s TEST=handshake1 TAG=boringssl ./e2e/k6/run.sh
DEPLOY=boringssl-nginx-behind-envoy-deployment RUN=k8s TEST=loopback1 TAG=boringssl ./e2e/k6/run.sh
DEPLOY=nginx-behind-envoy-deployment RUN=k8s TEST=loopback1 TAG=openssl ./e2e/k6/run.sh
DEPLOY=nginx-behind-envoy-deployment RUN=k8s TEST=loopback1 TAG=openssl-clr IMAGE=envoy-qat:clr ./e2e/k6/run.sh
