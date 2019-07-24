#!/bin/bash
# Script to check if deployment is incrementing QAT fw_counters under stress test.
source ./e2e/vars.sh

# Building test results path.
if [ "$RUN" == "k8s" ]; then
  DIR=./${DEVICE_TYPE}/${RUN}/${TEST}/${TAG}
else
  DIR=./${DEVICE_TYPE}/${TEST}/${TAG}
fi

# Arrays to store test results associated with the current deployment,
# under testing;
XREQS=() # Connections per second from the last success build.
YREQS=() # Connections per seconf from the current build.
XTLSH=() # TLS handshake times from the las success build.
YTLSH=() # TLS handshake times from the current build.
XTLAT=() # Tail latency times from the last success build.
YTLAT=() # Tail latency times from the current build.

for CPU in ${CPUS[@]}; do
  CDIR=${DIR}/cpus/${CPU}
  mkdir -p ${CDIR}
  ./e2e/k8s/clean-deployment.sh;
  sed -i "s/cpu: [2-3]/cpu: $CPU/g" ./deployments/${DEPLOY}.yaml;
  if [ -n "$IMAGE" ]; then
    sed -i "s/image: .*:devel/image: ${IMAGE}/g" ./deployments/${DEPLOY}.yaml;
  fi
  kubectl apply -f ./deployments/${DEPLOY}.yaml && sleep 30s;
  STATUS=$(kubectl get pods | grep envoy | awk '{print $3}');
  if [ "$STATUS" == "Running" ]; then
    for CIPHER in ${CIPHERS[@]}; do
      echo "'$DEVICE_TYPE' running '$TEST' with '$TAG' using '$CPU cpus' and testing '$CIPHER' cipher-suite."
      mkdir -p ${CDIR}/ciphers/${CIPHER}
      if [ "$RUN" == "k8s" ]; then
        CIPHER_SUITE="$CIPHER" ./e2e/k8s/configure-k6.sh;
        kubectl create configmap k6-config --from-file=./tests/k6-testing-config.js;
        kubectl create -f ./jobs/k6.yaml;
        sleep 30s;
        kubectl logs jobs/benchmark | tee ${CDIR}/ciphers/${CIPHER}/results.txt;
      else
        CIPHER_SUITE="$CIPHER" ./e2e/docker/configure-k6.sh;
        # If K6 is required to run externally from the cluster. then we pass the,
        # js config file and run the container in the k6 runner.
        if [ -n "$CLIENT" ]; then
          scp -i ./key.pem -oStrictHostKeyChecking=no ./tests/k6-testing-config-docker.js ${CLIENT}:/tmp/
          ssh -i ./key.pem -oStrictHostKeyChecking=no ${CLIENT} "docker run --net=host -i loadimpact/k6:master run --out influxdb=http://k8s-ci-analytics.zpn.intel.com:8086/$DEVICE_TYPE --vus 30 --duration 20s -< /tmp/k6-testing-config-docker.js" | tee ${CDIR}/ciphers/${CIPHER}/results.txt;
          ssh -i ./key.pem -oStrictHostKeyChecking=no ${CLIENT} "rm -rf /tmp/k6-testing-config-docker.js"
        else
          docker run --net=host -i loadimpact/k6:master run --out influxdb=http://k8s-ci-analytics.zpn.intel.com:8086/${DEVICE_TYPE} --vus 30 --duration 20s -< ./tests/k6-testing-config-docker.js | tee ${CDIR}/ciphers/${CIPHER}/results.txt;
        fi
      fi
      # TODO: confirm if tail latency is calculated correctly.
      BUILD_ID=$(wget -qO- ${JENKINS_URL}/job/kubernetes-qat-envoy/job/master/lastSuccessfulBuild/buildNumber);
      XCONN+=( $(wget -qO- ${PROJECT_LOG_URL}/${BUILD_ID}/${CDIR}/ciphers/${CIPHER}/results.txt | grep http_reqs | awk '{print $3}' | cut -d '/' -f 1) );
      YCONN+=( $(cat ${CDIR}/ciphers/${CIPHER}/results.txt | grep http_reqs | awk '{print $3}' | cut -d '/' -f 1) );
      XTLSH+=( $(wget -qO- ${PROJECT_LOG_URL}/${BUILD_ID}/${CDIR}/ciphers/${CIPHER}/results.txt | grep tls | awk '{print $2}' | cut -d'=' -f 2 | cut -d'm' -f 1) )
      YTLSH+=( $(cat ${CDIR}/ciphers/${CIPHER}/results.txt | grep tls | awk '{print $2}' | cut -d'=' -f 2 | cut -d'm' -f 1) )
      XTLAT+=( $(wget -qO- ${PROJECT_LOG_URL}/${BUILD_ID}/${CDIR}/ciphers/${CIPHER}/results.txt | grep iteration_duration | awk '{print $2}' | cut -d '=' -f 2 | cut -d 'm' -f 1) )
      YTLAT+=( $(cat ${CDIR}/ciphers/${CIPHER}/results.txt | grep iteration_duration | awk '{print $2}' | cut -d '=' -f 2 | cut -d 'm' -f 1) )
    done
  else
    echo "Skipping test of ciphers for $CPU cpus, not sufficient resources in $HOSTNAME." | tee ${CDIR}/results.txt;
    break;
  fi
done
if [ -n "$BUILD_ID" ]; then
  echo "${DEVICE_TYPE}: ${RUN}-${TEST}-${TAG} getting regression results."
  echo "[CONNECTIONS_PER_SECOND]" &> ${DIR}/regression.txt
  X=${XCONN[@]} Y=${YCONN[@]} EXPECTED="INCREASE" ./e2e/tests/regression.sh >> ${DIR}/regression.txt
  echo "" &>> ${DIR}/regression.txt
  echo "[TLS_HANDSHAKE_TIME]" &>> ${DIR}/regression.txt
  X=${XTLSH[@]} Y=${YTLSH[@]} EXPECTED="DECREASE" ./e2e/tests/regression.sh >> ${DIR}/regression.txt
  echo "" &>> ${DIR}/regression.txt
  echo "[TAIL_LATENCY]" &>> ${DIR}/regression.txt
  X=${XTLAT[@]} Y=${YTLAT[@]} EXPECTED="DECREASE" ./e2e/tests/regression.sh >> ${DIR}/regression.txt
  cat ${DIR}/regression.txt
fi
