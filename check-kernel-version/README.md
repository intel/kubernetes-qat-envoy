# Automatically re-install out-of-tree QAT driver

Updating the kernel without updating the out-of-tree QAT driver can lead
to incorrect behavior when the in-tree QAT driver tries to load the
firmware blobs. QAT driver doesn't yet have DKMS support implemented. As
a workaround, we offer a script for checking if the out-of-tree driver
is not used during system startup and re-installing the driver.

# Install and configure the script

Copy the script, the service file and the configuration file in place:

    # install -d /etc/systemd/system/check-qat-kernel.service.d
    # install -d /usr/local/bin
    # install check-qat-kernel.sh /usr/local/bin/
    # install check-qat-kernel.service /etc/systemd/system/
    # install check-qat-kernel.conf /etc/systemd/system/check-qat-kernel.service.d/

Edit the configuration file
`/etc/systemd/system/check-qat-kernel.service.d/check-qat-kernel.conf` to point
the `QAT_DRIVER_FILE` environment variable to the location of the QAT
driver archive in your system.

Enable the service file:

    # systemctl enable check-qat-kernel.service
