#!/bin/bash
CPUS=(2 4 8 16)
CIPHERS=("TLS_RSA_WITH_AES_128_GCM_SHA256" "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256")
DEVICE_TYPE=$(adf_ctl status | grep qat | awk '{print $4}' | cut -d ',' -f 1 | tail -1)
HOSTIP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
