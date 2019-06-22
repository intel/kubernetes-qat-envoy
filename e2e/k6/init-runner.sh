#!/bin/bash
# Load the newest loadimpact image in the runner machines.
source ./e2e/vars.sh

ssh -i ${SSH_KEY} -oStrictHostKeyChecking=no ${K6_RUNNER} "docker pull ${DOCKER_QAT_REGISTRY}/loadimpact/k6:custom"
ssh -i ${SSH_KEY} -oStrictHostKeyChecking=no ${K6_RUNNER} "docker tag ${DOCKER_QAT_REGISTRY}/loadimpact/k6:custom loadimpact/k6:custom"
