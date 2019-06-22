# DOCKER_QAT_REGISTRY value defined in Jenkins vars.
# Add insecure resgitry to push images.
source ./e2e/vars.sh

sudo sh -c "echo '{\"insecure-registries\": [\"${DOCKER_QAT_REGISTRY}\"]}' > /etc/docker/daemon.json"
sudo sh -c "systemctl restart docker"
