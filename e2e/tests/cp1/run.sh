#!/bin/bash
# Install qat driver using ansible-playbooks in vagrant dir, and then checks if,
# adf_ctl is working.
./e2e/qat/install_deps.sh
./e2e/qat/install_driver.sh
# Check if the devices are up.
STATUS=$(adf_ctl status | grep -i qat_dev | grep -i up) && echo $STATUS
if [ -z "$STATUS" ]; then
  echo "ERROR: No qat devices up were found.";
  exit 1;
fi
