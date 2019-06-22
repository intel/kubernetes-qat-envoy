#!/bin/bash
# run handshake1 test with all deploys.
# If private key is gotten from jenkins, we also specify user and ip for a remote,
# k6 execution.
source ./e2e/vars.sh

if [ -n "$SSH_KEY" ]; then
  # Create a tmp key copy in the root dir, in order to have available this key in
  # later scripts.
  cat ${SSH_KEY} > ./key.pem && chmod 400 ./key.pem
  DEPLOY=envoy-deployment RUN=docker CLIENT=${K6_RUNNER} TEST=handshake1 TAG=openssl ./e2e/k6/run.sh
  DEPLOY=envoy-deployment RUN=docker CLIENT=${K6_RUNNER} TEST=handshake1 TAG=openssl-clr IMAGE=envoy-qat:clr ./e2e/k6/run.sh
  DEPLOY=boringssl-envoy-deployment RUN=docker CLIENT=${K6_RUNNER} TEST=handshake1 TAG=boringssl ./e2e/k6/run.sh
  rm -rf ./key.pem
else
  DEPLOY=envoy-deployment RUN=docker TEST=handshake1 TAG=openssl ./e2e/k6/run.sh
  DEPLOY=envoy-deployment RUN=docker TEST=handshake1 TAG=openssl-clr IMAGE=envoy-qat:clr ./e2e/k6/run.sh
  DEPLOY=boringssl-envoy-deployment RUN=docker TEST=handshake1 TAG=boringssl ./e2e/k6/run.sh
fi
