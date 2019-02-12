# Virtual Machines

This project uses [Vagrant tool][1] for provisioning a Virtual Machine
automatically. The [setup](setup.sh) bash script contains the
Linux instructions to install dependencies and plugins required for
its usage. This script supports two Virtualization technologies
(Libvirt and VirtualBox).

    $ ./setup.sh -p libvirt

Once Vagrant is installed, it's possible to provision an All-in-One
Kubernetes cluster using the following instruction:

    $ vagrant up

## License

Apache-2.0

[1]: https://www.vagrantup.com/
