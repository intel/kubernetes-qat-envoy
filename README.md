# Kubernetes* and Intel Quick Assist Technology accelerated Envoy*

## Introduction

This is a technical guide for getting Intel Quick Assist Technology (QAT) accelerated Envoy* running on a bare-metal Kubernetes* cluster. You may need to adapt some commands to your particular cluster setup. You need to first install the QAT driver on every node which has QAT hardware installed. The driver used in this setup is located at https://01.org/sites/default/files/downloads/qat1.7.l.4.10.0-00014.tar.gz, and the package contains a README file which explains the installation.

## Clone this repository with submodules

    $ git clone --recurse-submodules <url to this git repository>
    $ cd kubernetes-qat-envoy

## Create a container for QAT-accelerated Envoy

    # docker image build -t envoy-qat:devel -f Dockerfile.boringssl .

Add the image to the Docker registry where all nodes in your cluster can find it. If you load the image to the Docker image cache on all nodes, you can skip this step. The exact commands depend on the Docker infrastructure you have.

## Set up the node's kubelet to use the static CPU Management Policy

Make sure that kubelet's configuration file (set with `--config` command line option) contains the following settings:

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cpuManagerPolicy: static
systemReserved:
  cpu: 500m
  memory: 256M
kubeReserved:
  cpu: 500m
  memory: 256M
...
```

If the original policy was `none` then remove CPU manager's snapshot file and restart kubelet:

    # rm /var/lib/kubelet/cpu_manager_state
    # systemctl restart kubelet

Check kubelet is running with its CPU manager using the static policy

    $ systemctl status kubelet
    $ cat /var/lib/kubelet/cpu_manager_state

## Prepare TLS keys and wrap them into a Kubernetes secret

Create SSL certificate and private key (note that your process for creating and signing the certificate may be different):

    $ openssl req -x509 -new -batch -nodes -subj '/CN=localhost' -keyout key.pem -out cert.pem

Create a Kubernetes* secret out of the certificate and the key:

    $ kubectl create secret tls envoy-tls-secret --cert cert.pem --key key.pem

## Install QAT Device Plugin

Follow the instructions at
https://github.com/intel/intel-device-plugins-for-kubernetes/tree/main/cmd/qat_plugin
to install the latest release image of Kubernetes* QAT Device Plugin. 

## Apply the Nginx* and Envoy* deployment

Create the Nginx* with Envoy* sidecar deployment:

    $ kubectl apply -f ./deployments/nginx-behind-envoy-deployment.yaml

Get the NodePort:

    $ kubectl get services
    nginx-behind-envoy   NodePort    10.108.116.104   <none>        9000:32675/TCP   82m

The NodePort in this case would be `32675`.

## Test and benchmark the setup with and without QAT acceleration using K6

Access the proxy using curl and the certificate (change the correct NodePort value to the URL):

    $ curl --cacert cert.pem https://localhost:32675

You should expect to see the Nginx*-provided web page source.

Edit the `tests/k6-testing-config-docker.js` file to set the test parameters.  You can among other things select the cipher suite in the file. At least replace the port `9000` in the URL with the NodePort value.  Then run the benchmark:

    # docker run --net=host -i loadimpact/k6 run --vus 10 --duration 20s -< tests/k6-testing-config-docker.js

To run benchmarks against non-accelerated setup apply this deployment config and run the benchmark again (after waiting for a few moments for the Pod to restart):

    $ kubectl apply -f deployments/nginx-behind-envoy-deployment-no-qat.yaml

If you would like to run the benchmark within Kubernetes*, edit `tests/k6-testing-config.js` file to set the test parameters. Do not change the URL. Then create a ConfigMap from the file:

    $ kubectl create configmap k6-config --from-file=tests/k6-testing-config.js

Run the benchmark test (takes by default a bit over twenty seconds):

    $ kubectl create -f jobs/k6.yaml

After a while get the results:

    $ kubectl logs jobs/benchmark

Then delete the job:

    $ kubectl delete job benchmark

## Envoy using BoringSSL QAT private key provider

To test that QAT works, run the new container:

    $ scripts/envoy-boringssl-docker.sh

Then in another shell access Envoy over TLS:

    $ curl --cacert cert.pem https://localhost:9000

## License

All files in this repository are licensed with BSD license (see `COPYING`), unless they are explicitly licensed with some other license.  This does not apply to the git submodules.
