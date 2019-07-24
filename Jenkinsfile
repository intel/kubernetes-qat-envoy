pipeline {
  agent none
  triggers {
    cron('0 0 * * *')
  }
  stages {
    stage('Build') {
      agent {
        label "builder"
      }
      stages {
        stage('Pre-steps') {
          steps {
            retry(count: 3) {
              sh 'git submodule update --init --recursive'
              sh 'docker system prune -a -f'
            }
          }
        }
        stage('Docker builds') {
          parallel {
            stage ('Debian Envoy+OpenSSL+QAT') {
              steps {
                retry(count: 3) {
                  sh 'make -f ./e2e/Makefile envoy-qat'
                }
              }
            }
            stage ('Clearlinux Envoy+OpenSSL+QAT') {
              steps {
                retry(count: 3) {
                  sh 'make -f ./e2e/Makefile envoy-qat-clr'
                }
              }
            }
            stage ('Debian Envoy+BoringSSL+QAT') {
              steps {
                retry(count: 3) {
                  sh 'make -f ./e2e/Makefile envoy-boringssl-qat'
                }
              }
            }
            stage ('Intel-QAT-Plugin') {
              steps {
                retry(count: 3) {
                  sh 'cd ./intel-device-plugins-for-kubernetes && make intel-qat-plugin'
                }
              }
            }
          }
        }
      }
      post {
        success {
          stash name: "intel-device-plugins-for-kubernetes", includes: "intel-device-plugins-for-kubernetes/**/*"
          sh './e2e/docker/push-internal-images.sh'
          deleteDir()
        }
        failure {
          deleteDir()
        }
      }
    }
    stage ("e2e") {
      parallel {
        stage('dh895xcc') {
          agent {
            label "dh895xcc"
          }
          stages {
            stage('Pre-steps') {
              steps {
                unstash 'intel-device-plugins-for-kubernetes'
                withCredentials([sshUserPrivateKey(credentialsId: "K6-Runner", keyFileVariable: 'SSH_KEY')]) {
                  sh './e2e/k6/init-runner.sh'
                }
              }
            }
            stage('CP1') {
              steps {
                sh './e2e/tests/cp1/run.sh'
              }
            }
            stage('CP2') {
              steps {
                sh './e2e/tests/cp2/run.sh'
              }
            }
            stage('CP3') {
              steps {
                sh './e2e/tests/cp3/run.sh'
              }
            }
            stage('CP5') {
              steps {
                sh './e2e/tests/cp5/run.sh'
              }
            }
            stage('LBD1') {
              steps {
                sh './e2e/tests/lbd1/run.sh'
              }
            }
            stage('LBD2') {
              steps {
                sh './e2e/tests/lbd2/run.sh'
              }
            }
            stage('LBD3') {
              steps {
                sh './e2e/tests/lbd3/run.sh'
              }
            }
            stage('LBD4') {
              steps {
                sh './e2e/tests/lbd4/run.sh'
              }
            }
            stage('LBD5') {
              steps {
                withCredentials([sshUserPrivateKey(credentialsId: "K6-Runner", keyFileVariable: 'SSH_KEY')]) {
                  sh './e2e/tests/lbd5/run.sh'
                }
              }
            }
          }
          post {
            always {
              sh './e2e/k8s/clean.sh'
              sh './e2e/docker/clean.sh'
              sh 'sleep 60s'
              deleteDir()
            }
          }
        }
        stage('c6xx') {
          agent {
            label "c6xx"
          }
          stages {
            stage('Pre-steps') {
              steps {
                unstash 'intel-device-plugins-for-kubernetes'
                withCredentials([sshUserPrivateKey(credentialsId: "K6-Runner", keyFileVariable: 'SSH_KEY')]) {
                  sh './e2e/k6/init-runner.sh'
                }
              }
            }
            stage('CP1') {
              steps {
                sh './e2e/tests/cp1/run.sh'
              }
            }
            stage('CP2') {
              steps {
                sh './e2e/tests/cp2/run.sh'
              }
            }
            stage('CP3') {
              steps {
                sh './e2e/tests/cp3/run.sh'
              }
            }
            stage('CP5') {
              steps {
                sh './e2e/tests/cp5/run.sh'
              }
            }
            stage('LBD1') {
              steps {
                sh './e2e/tests/lbd1/run.sh'
              }
            }
            stage('LBD2') {
              steps {
                sh './e2e/tests/lbd2/run.sh'
              }
            }
            stage('LBD3') {
              steps {
                sh './e2e/tests/lbd3/run.sh'
              }
            }
            stage('LBD4') {
              steps {
                sh './e2e/tests/lbd4/run.sh'
              }
            }
            stage('LBD5') {
              steps {
                withCredentials([sshUserPrivateKey(credentialsId: "K6-Runner", keyFileVariable: 'SSH_KEY')]) {
                 sh './e2e/tests/lbd5/run.sh'
                }
              }
            }
          }
          post {
            always {
              sh './e2e/k8s/clean.sh'
              sh './e2e/docker/clean.sh'
              sh 'sleep 60s'
              deleteDir()
            }
          }
        }
      }
    }
    stage('Performance test') {
      parallel {
        stage('dh895xcc') {
          agent {
            label "dh895xcc"
          }
          stages {
            stage('Cluster init') {
              steps {
                retry(count: 2) {
                  unstash 'intel-device-plugins-for-kubernetes'
                  sh './e2e/qat/cluster-init.sh'
                }
              }
            }
            stage('Handshake 1') {
              steps {
                withCredentials([sshUserPrivateKey(credentialsId: "K6-Runner", keyFileVariable: 'SSH_KEY')]) {
                  sh './e2e/tests/handshake1/run.sh'
                }
              }
            }
            stage('Loopback 1') {
              steps {
                withCredentials([sshUserPrivateKey(credentialsId: "K6-Runner", keyFileVariable: 'SSH_KEY')]) {
                  sh './e2e/tests/loopback1/run.sh'
                }
              }
            }
            stage('K8s 1') {
              steps {
                sh './e2e/tests/k8s1/run.sh'
              }
            }
          }
          post {
            always {
              stash name: "dh895xcc", includes: "dh895xcc/**/*"
              sh './e2e/k8s/clean.sh'
              sh './e2e/docker/clean.sh'
              deleteDir()
            }
          }
        }
        stage('c6xx') {
          agent {
            label "c6xx"
          }
          stages {
            stage('Cluster init') {
              steps {
                retry(count: 2) {
                  unstash 'intel-device-plugins-for-kubernetes'
                  sh './e2e/qat/cluster-init.sh'
                }
              }
            }
            stage('Handshake 1') {
              steps {
                withCredentials([sshUserPrivateKey(credentialsId: "K6-Runner", keyFileVariable: 'SSH_KEY')]) {
                  sh './e2e/tests/handshake1/run.sh'
                }
              }
            }
            stage('Loopback 1') {
              steps {
                withCredentials([sshUserPrivateKey(credentialsId: "K6-Runner", keyFileVariable: 'SSH_KEY')]) {
                  sh './e2e/tests/loopback1/run.sh'
                }
              }
            }
            stage('K8s 1') {
              steps {
                sh './e2e/tests/k8s1/run.sh'
              }
            }
          }
          post {
            always {
              stash name: "c6xx", includes: "c6xx/**/*"
              sh './e2e/k8s/clean.sh'
              sh './e2e/docker/clean.sh'
              deleteDir()
            }
          }
        }
      }
    }
    stage("Results") {
      agent {
        label "logs"
      }
      stages {
        stage("Publish results") {
          steps {
            unstash 'dh895xcc'
            unstash 'c6xx'
            sh "mkdir -p $LOG_DIRECTORY"
            sh "mv ./dh895xcc $LOG_DIRECTORY"
            sh "mv ./c6xx $LOG_DIRECTORY"
          }
        }
      }
      post {
        always {
          deleteDir()
        }
      }
    }
  }
  post {
    success {
      emailext body: 'Jenkins log: ${JENKINS_BLUE_OCEAN_URL_QAT}, Results: ${LOG_URL}, Dashboard: ${QAT_DASHBOARD}', subject: 'SUCCESS: kubernetes-qat-envoy #${BUILD_NUMBER}', to: '$QAT_ENVOY_MAILING_LIST'
    }
    failure {
      emailext body: 'Jenkins log: ${JENKINS_BLUE_OCEAN_URL_QAT}', subject: 'FAILURE: kubernetes-qat-envoy #${BUILD_NUMBER}', to: '$QAT_ENVOY_MAILING_LIST'
    }
  }
}
