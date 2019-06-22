#!/bin/bash
# Script to clean k8s resources
# NOTE: all clean steps are temporary when the BMaaS is ready,
# having clean environment this steps won't be needed.
cd ./vagrant
source _commons.sh
sed -i 's/default: "no"/default: "yes"/g' $kubespray_folder/reset.yml
sed -i 's/private: no/private: yes/g' $kubespray_folder/reset.yml
echo yes | uninstall_k8s
rm -rf $kubespray_folder
