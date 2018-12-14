# Kubernetes and QAT-accelerated Envoy

## Introduction

This is a technical guide for getting QAT-accelerated Envoy running on a bare-metal Kubernetes cluster. You may need to adapt some commands to your particular cluster setup.

# Clone this repository (with submodules) and fetch the QAT driver

Clone this repository with submodules:

    $ git clone --recurse-submodules <url to this git repository>

Then fetch the qat driver:

    $ wget https://01.org/sites/default/files/downloads/intelr-quickassist-technology/qat1.7.l.4.3.0-00033.tar.gz

## Create a container for QAT-accelerated Envoy

    # docker image build -t envoy-qat:devel -f Dockerfile.envoy .

Add the image to the Docker registry where all nodes in your cluster can find it. If you load the image to the Docker image cache on all nodes, you can skip this step. The exact commands depend on the Docker infrastructure you have.

## Prepare TLS keys and wrap them into a Kubernetes secret

Create SSL certificate and private key (note that your process for creating and signing the certificate may be different):

    $ openssl req -x509 -new -batch -nodes -keyout key.pem -out cert.pem

Create a kubernetes secret out of the certificate and the key:

    $ kubectl create secret tls envoy-tls-secret --cert cert.pem --key key.pem

# Create QAT Device Plugin daemonset

    $ cd intel-device-plugins-for-kubernetes
    $ make intel-qat2-plugin # this builds a docker image with the plugin
    $ cd ..

Again, you’ll need to make sure that the Docker image is available on all nodes.

    $ kubectl apply -f ./deployments/qat2_plugin/qat2_plugin.yaml

Make sure the QAT kernel driver is configured properly on the node. For this copy the content of `configs/c6xx_devX.conf` to the node as `/etc/c6xx_dev0.conf`, `/etc/c6xx_dev1.conf` and `/etc/c6xx_dev2.conf`. After that restart the QAT driver on the node:

    # adf_ctl restart

## Apply the Nginx and Envoy deployment

Create the Nginx with Envoy sidecar deployment:

    $ kubectl apply -f ./deployments/nginx-behind-envoy-deployment.yaml

Expose the deployment:

    $ kubectl expose deployment/nginx-behind-envoy

## Test the setup with and without QAT acceleration

Find the NodePort address of the Envoy proxy.

    $ kubectl get service nginx-behind-proxy

Access the proxy using curl and the same certificate:

    $ curl --cacert cert.pem https://<ip_addr>:9000

You should expect to see the nginx-provided web page source.

In order to run benchmarks with k6 load testing tool, first create a
container for a version which has TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256
support enabled:

    $ cd k6
    $ docker image build -t loadimpact/k6:custom -f Dockerfile .
    $ cd ..

Run the benchmark (note that you can select the cipher suite by editing
`tests/k6-test-config.js` file):

    $ docker run --net=host -i loadimpact/k6:custom run --vus 10 --duration 30s -< tests/k6-test-config.js

To run benchmarks against non-accelerated setup apply this deployment config:

    $ kubectl apply -f nginx-behind-envoy-deployment-no-qat.yaml

Wait until the new non-accelerated pod is running and run the same benchmark again.

    $ docker run --net=host -i loadimpact/k6:custom run --vus 10 --duration 30s -< tests/k6-test-config.js
