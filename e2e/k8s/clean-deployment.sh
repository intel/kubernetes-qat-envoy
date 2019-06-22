#!/bin/bash
# Script to delete nginx deploy.
kubectl delete -f ./deployments/nginx-behind-envoy-deployment.yaml --ignore-not-found=true
kubectl delete -f ./deployments/nginx-behind-envoy-deployment-no-qat.yaml --ignore-not-found=true
kubectl delete -f ./deployments/boringssl-envoy-deployment.yaml --ignore-not-found=true
kubectl delete -f ./deployments/boringssl-nginx-behind-envoy-deployment.yaml --ignore-not-found=true
kubectl delete -f ./deployments/envoy-deployment.yaml --ignore-not-found=true
git checkout ./deployments
sed -i "s/- name: nginx/- name: nginx\n          securityContext:\n            privileged: true/g" ./deployments/nginx-behind-envoy-deployment.yaml
sed -i "s/- name: envoy-sidecar/- name: envoy-sidecar\n          securityContext:\n            privileged: true/g" ./deployments/nginx-behind-envoy-deployment.yaml
sleep 45s
