#!/bin/sh

set -e

MODULE_NAME=$(modinfo -n intel_qat)

if echo "$MODULE_NAME" | grep -q updates; then
    echo "Properly using the out-of-tree kernel driver."
    exit 0
fi

# Re-install QAT driver.

if [ ! -f "$QAT_DRIVER_FILE" ]; then
    echo "No QAT driver file found."
    exit 1
fi

BUILD_DIR=$(mktemp -d /tmp/qat-build-dir.XXXXXXXX)
cd "$BUILD_DIR"
tar xzvf "$QAT_DRIVER_FILE"
./configure --enable-qat-uio
make -j8
make install

# Using systemd PrivateTmp, cleanup is done automatically.
