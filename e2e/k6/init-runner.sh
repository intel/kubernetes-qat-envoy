#!/bin/bash
# Load the newest loadimpact image in the runner machines.
source ./e2e/vars.sh

ssh -i ${SSH_KEY} -oStrictHostKeyChecking=no ${K6_RUNNER} "docker system prune -a -f"
ssh -i ${SSH_KEY} -oStrictHostKeyChecking=no ${K6_RUNNER} "docker pull loadimpact/k6:master"
