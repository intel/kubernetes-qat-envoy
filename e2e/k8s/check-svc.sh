#!/bin/bash
# Script to check if deployment is accesible.
source ./e2e/vars.sh
./e2e/k8s/clean-deployment.sh;

# If a image is defined as variable then we switch the value in the deploy file;
if [ -n "$IMAGE" ]; then
  sed -i "s/image: .*:devel/image: ${IMAGE}/g" ./deployments/${DEPLOY}.yaml;
fi

kubectl apply -f ./deployments/${DEPLOY}.yaml && sleep 30s;
STATUS=$(kubectl get pods | grep envoy | awk '{print $3}');
if [ "$STATUS" == "Running" ]; then
  echo "OK: pod running.";
  SVC_PORT=$(kubectl get svc | grep hello | awk '{print $5}' | cut -d":" -f 2 | cut -d"/" -f 1);
  if [ -n "$CLIENT" ]; then
    CODE=$(ssh -i ./key.pem -oStrictHostKeyChecking=no ${CLIENT} "curl -i -s -l -k https://$HOSTIP:$SVC_PORT | grep HTTP | awk '{print \$2}'");
  else
    CODE=$(curl -i -s -l -k  --cacert cert.pem https://127.0.0.1:$SVC_PORT | grep HTTP | awk '{print $2}');
  fi

  if [ "$CODE" == "200" ]; then
    echo "OK: svc is accessible.";
  else
    echo "ERROR: service is not accessible.";
    exit 1;
  fi
else
  echo "ERROR: pod not running.";
  exit 1;
fi
