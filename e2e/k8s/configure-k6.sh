#!/bin/bash
# Script to check if nginx svc is running and accessible and then configures,
# the script file.
source ./e2e/vars.sh
kubectl delete job benchmark --ignore-not-found=true
kubectl delete configmap k6-config  --ignore-not-found=true
git checkout ./tests/k6-testing-config.js
SVC_PORT=$(kubectl get svc | grep hello | awk '{print $5}' | cut -d":" -f 2 | cut -d"/" -f 1)
sed -i s/'${__ENV.HELLONGINX_SERVICE_HOST}'/${HOSTIP}/g ./tests/k6-testing-config.js
sed -i "s/9000/$SVC_PORT/g" ./tests/k6-testing-config.js
if [ -n "$CIPHER_SUITE" ]; then
  sed -i "s/TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256/$CIPHER_SUITE/g" ./tests/k6-testing-config.js;
fi
