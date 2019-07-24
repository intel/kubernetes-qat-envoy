#!/bin/bash
# Script to check if deployment is incrementing QAT fw_counters under stress test.
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
  CODE=$(curl -i -s -l -k  --cacert cert.pem https://127.0.0.1:$SVC_PORT | grep HTTP | awk '{print $2}');
  if [ "$CODE" == "200" ]; then
    echo "OK: svc is accessible.";
    ./e2e/qat/print-counters.sh | tee ./before.txt;
    # Using a cipher suite that is available/supported for all envoy images;
    CIPHER_SUITE="TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256" ./e2e/docker/configure-k6.sh
    docker run --net=host -i loadimpact/k6:master run --vus 30 --duration 20s -< ./tests/k6-testing-config-docker.js
    ./e2e/qat/print-counters.sh | tee ./after.txt;
    DIFF=$(diff ./before.txt ./after.txt);
    echo ${DIFF}
    # TODO: do the math to match counter vs http_request;
    if [ -z "$DIFF" ]; then
      echo "ERROR: no diff in QAT counters, not updated.";
      exit 1;
    fi
  else
    echo "ERROR: service is not accessible.";
    exit 1;
  fi
else
  echo "ERROR: pod not running.";
  exit 1;
fi
