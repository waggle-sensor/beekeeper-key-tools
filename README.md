# Beekeeper Keys and Certificate Tools

This repository contains the tools used to create the keys and certificates used to establish secure communication channels between the nodes and the Beekeeper services.

> Note: some of the tools make use of the [Waggle PKI Tools](https://github.com/waggle-sensor/waggle-pki-tools) Docker container to establish a reliable run-time environment.

## Initializing the Beekeeper Keys

The `create-init-keys.sh` script creates the initial Beekeeper certificate authority key-pair, the beekeeper server key-pair and certificate, and the node registration key-pair.

Usage:
```bash
./create-init-keys.sh
```

The following keys/certs are created:

### **bk-admin-ssh-key**

This is the key-pair that is used by Beekeeper administrators to SSH to the Beekeeper service instance. This key is used during the reverse ssh (rssh) access chain to a node.

- private key: needed by system administators needing privileged Beekeeper access
- public key: saved into the [Beekeeper](https://github.com/waggle-sensor/beekeeper) `sshd` instance `authorized_keys` file

### **node-ssh-key**

This is the key-pair used by system administrators to SSH to the nodes. This key is used during the reverse ssh (rssh) access chain to a node.

- private key: needed by system administrators needing privileged node access
- public key: saved into the Node's `root`  user `authorized_keys` file

### **bk-server-key**

This the the Beekeeper key-pair and certificate that is saved to the Beeekeeper service instance. This CA signed certificate is used during the Node's SSH connection to verify that the Beekeeper is the trusted server.

- private key, public key, certificate: saved into the [Beekeeper](https://github.com/waggle-sensor/beekeeper)

^ TODO figure out where?

### **bk-ca**

TODO: details

Beekeeper certificate authority files used in the creation of certificates (i.e. node registration certificate)

- private key: kept private
- public key: save into the Node's `/etc/ssh/ssh_known_hosts` file

### node-registration-key**

TODO: details

Node registration keys to be copied to the nodes. 

> *Note*: successful registration requires a [node certificate](#creating-a-node-registration-certificate).

## Creating a Node Registration Certificate

The `create-key-cert.sh` script is used to create node registration certificates (from the Beekeeper registration keys).

At a minimum the certification script requires the name of the "Beehive" the node is to be assigned to after registration.

```bash
./create-key-cert.sh -b <beehive name>
```

Additional parameters can be specified such as the certificates "validity" time (see: ['validity_interval'](https://www.man7.org/linux/man-pages/man1/ssh-keygen.1.html)). This example has the certificate valid for 1 day from the time it is created.

```bash
./create-key-cert.sh -b <beehive_name> -e +1D
```

For details on other script arguments:

```bash
./create-key-cert.sh -?
```

This will produce a folder (via the `-o` option) that contains 3 files
- private registration key (copied from the path specified by `-k`)
- public registration key (copied from the path specified by `-k`)
- registration certificate

For example, the following command will generate a certficate (in the folder `./cert/nodex`) for the registration keys (`./beekeeper-keys/registration_keys/registration.pub`) that expires in 1 day  for the `beehive-dev` Beehive using the Beekeeper certificate authority (found in `./beekeeper-keys/certca/beekeeper_ca_key`)
```bash
$ ./create-key-cert.sh -b beehive-dev -e +1D -o cert/nodex -c beekeeper-keys/certca/beekeeper_ca_key -k beekeeper-keys/registration_keys/registration.pub

$ ls ./cert/nodex
registration		registration-cert.pub	registration.pub

$ ssh-keygen -L -f cert/nodex/registration-cert.pub
cert/nodex/registration-cert.pub:
        Type: ssh-ed25519-cert-v01@openssh.com user certificate
        Public key: ED25519-CERT SHA256:VjVrn2Kof8rAcYy2EOXIh/kDMF10isPGxVtFBh+WnJM
        Signing CA: ED25519 SHA256:KUq2jxddaBuAU76eOUxUsNolH6wCie2/psu7JHZDkHo (using ssh-ed25519)
        Key ID: "sage_registration"
        Serial: 0
        Valid: from 2022-07-14T17:51:00 to 2022-07-15T17:52:16
        Principals:
                sage_registration
        Critical Options:
                force-command /opt/sage/beekeeper/register/register.sh -b beehive-dev
        Extensions: (none)
```
