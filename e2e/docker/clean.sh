#!/bin/bash
# Script to clean docker system
# NOTE: all clean steps are temporary when the BMaaS is ready,
# having clean environment this steps won't be needed.
cd ./vagrant
source _commons.sh
uninstall_docker
