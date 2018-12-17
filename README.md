# Kubernetes and QAT-accelerated Envoy

## Introduction

This is a technical guide for getting QAT-accelerated Envoy running on a bare-metal Kubernetes cluster. You may need to adapt some commands to your particular cluster setup. You need to first install the QAT driver on every node which has QAT hardware installed. The driver used in this setup is located at https://01.org/sites/default/files/downloads/intelr-quickassist-technology/qat1.7.l.4.3.0-00033.tar.gz, and the package contains a README file which explains the installation.

# Clone this repository (with submodules) and fetch the QAT driver

Clone this repository with submodules:

    $ git clone --recurse-submodules <url to this git repository>

Then go to the created directory and fetch the QAT driver:

    $ cd kubernetes-qat-envoy
    $ wget https://01.org/sites/default/files/downloads/intelr-quickassist-technology/qat1.7.l.4.3.0-00033.tar.gz

## Create a container for QAT-accelerated Envoy

    # docker image build -t envoy-qat:devel -f Dockerfile.envoy .

Add the image to the Docker registry where all nodes in your cluster can find it. If you load the image to the Docker image cache on all nodes, you can skip this step. The exact commands depend on the Docker infrastructure you have.

## Prepare TLS keys and wrap them into a Kubernetes secret

Create SSL certificate and private key (note that your process for creating and signing the certificate may be different):

    $ openssl req -x509 -new -batch -nodes -subj '/CN=localhost' -keyout key.pem -out cert.pem

Create a kubernetes secret out of the certificate and the key:

    $ kubectl create secret tls envoy-tls-secret --cert cert.pem --key key.pem

# Create QAT Device Plugin daemonset

    $ cd intel-device-plugins-for-kubernetes
    # make intel-qat2-plugin # this builds a docker image with the plugin
    $ cd ..

Again, you’ll need to make sure that the Docker image is available on all nodes.

    $ kubectl apply -f ./intel-device-plugins-for-kubernetes/deployments/qat2_plugin/qat2_plugin.yaml

Make sure the QAT kernel driver is configured properly on the node. For this copy the content of `configs/c6xx_devX.conf` to the node as `/etc/c6xx_dev0.conf`, `/etc/c6xx_dev1.conf` and `/etc/c6xx_dev2.conf`. After that restart the QAT driver on the node:

    # adf_ctl restart

## Apply the Nginx and Envoy deployment

Create the Nginx with Envoy sidecar deployment:

    $ kubectl apply -f ./deployments/nginx-behind-envoy-deployment.yaml

Get the NodePort:

    $ kubectl get services
    nginx-behind-envoy   NodePort    10.108.116.104   <none>        9000:32675/TCP   82m

The NodePort in this case would be `32675`.

## Test the setup with and without QAT acceleration

Access the proxy using curl and the certificate (change the correct NodePort value to the URL):

    $ curl --cacert cert.pem https://localhost:32675

You should expect to see the nginx-provided web page source.

In order to run benchmarks with k6 load testing tool, first create a
container for a version which has
`TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256` support enabled:

    $ cd k6
    # docker image build -t loadimpact/k6:custom -f Dockerfile .
    $ cd ..

Edit the `tests/k6-testing-config-docker.js` file to set the test parameters.  You can among other things select the cipher suite in the file. At least replace the port `9000` in the URL with the NodePort value.  Then run the benchmark:

    # docker run --net=host -i loadimpact/k6:custom run --vus 10 --duration 20s -< tests/k6-testing-config-docker.js

To run benchmarks against non-accelerated setup apply this deployment config and run the benchmark again (after waiting for a few moments for the Pod to restart):

    $ kubectl apply -f deployments/nginx-behind-envoy-deployment-no-qat.yaml

If you would like to run the benchmark within Kubernetes, edit `tests/k6-testing-config.js` file to set the test parameters. Do not change the URL. Then create a ConfigMap from the file:

    $ kubectl create configmap k6-config --from-file=tests/k6-testing-config.js

Run the benchmark test (takes by default a bit over twenty seconds):

    $ kubectl create -f jobs/k6.yaml

After a while get the results:

    $ kubectl logs jobs/benchmark

Then delete the job:

    $ kubectl delete job benchmark

