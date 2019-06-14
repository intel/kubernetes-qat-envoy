pipeline {
  agent {
    label "kubernetes-qat-envoy"
  }
  stages {
    stage('Create container for QAT-accelerated Envoy') {
      options {
        timeout(time: 180, unit: "MINUTES")
      }
      steps {
        retry(2) {
          sh "docker image build -t envoy-qat:devel -f Dockerfile.envoy . --no-cache"
          sh "docker image build -t envoy-boringssl-qat:devel -f Dockerfile-boringssl-envoy . --no-cache"
          sh "docker image build -t envoy-qat:clr -f Dockerfile.clr.envoy . --no-cache"
        }
      }
    }
  }
}
