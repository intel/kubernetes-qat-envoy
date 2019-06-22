#!/bin/bash
# Check if all pods in kube-system namespaces are up and running
PODS_STATUS=$(kubectl get pods -n kube-system | awk '{print $3}' | tail -n +2)
for STATUS in ${PODS_STATUS[@]}; do
  if [[ "$STATUS" == "Running" || "$STATUS" == "Pending" ]]; then
    echo "OK: pod running or trying to run.";
  else
    echo "ERROR: pod with error found.";
    exit 1;
  fi
done
echo "OK: kubernetes cluster is running.";
