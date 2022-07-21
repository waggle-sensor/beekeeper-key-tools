# Beekeeper Keys and Certificate Tools

This repository contains the tools used to create the keys and certificates used to establish secure communication channels between the nodes and the Beekeeper services.

The tools are executed through the [waggle/beekeeper-key-tools](https://hub.docker.com/r/waggle/beekeeper-key-tools) docker container.

## Initializing the Beekeeper Keys

The `create-init-keys.sh` script creates all the keys and certificates needed for Beekeeper / node registration process, including keys to enable admin access to both the Beekeeper and nodes.

Usage:
```bash
docker run --rm -it \
  -v ${PWD}:/workdir:rw \
  waggle/beekeeper-key-tools:latest \
  create-init-keys.sh
```

For details on script arguments:

```bash
docker run --rm -it \
  -v ${PWD}:/workdir:rw \
  waggle/beekeeper-key-tools:latest \
  create-init-keys.sh -?
```

The following keys/certs are created:

### **Beekeeper admin ssh key-pair [bk-admin-ssh-key]**

This is the key-pair that is used by Beekeeper administrators to SSH to the Beekeeper service instance. This key is used during the reverse ssh (`rssh`) access chain to a node.

- private key: needed by system administators requiring privileged Beekeeper access
- public key: saved into the [Beekeeper](https://github.com/waggle-sensor/beekeeper) `sshd` instance `authorized_keys` file

### **Node ssh key-pair [node-ssh-key]**

This is the key-pair used by system administrators to `ssh` to the nodes. This key is used during the reverse ssh (`rssh`) access chain to a node.

- private key: needed by system administrators requiring privileged node access
- public key: saved into the node's `root`  user `authorized_keys` file

### **Beekeeper server key-pair and certificate [bk-server-key]**

This is the Beekeeper key-pair and certificate that is saved to the Beeekeeper service instance. This CA signed certificate is used during the node's `ssh` connection to verify that the Beekeeper is the trusted server.

- private key & certificate: saved into the [Beekeeper](https://github.com/waggle-sensor/beekeeper) `sshd` instance as the servers `HostKey` and `HostCertificate`

### **Beekeeper certificate authority key-pair [bk-ca]**

This is the main Beekeeper certificate authority files used in the creation of certificates (i.e. node registration certificate).

- private key: kept secret and used for future certificate creation (i.e. [not registration certificates](#creating-a-node-registration-certificate))
- public key: save into the [Beekeeper](https://github.com/waggle-sensor/beekeeper) `sshd` instance as the servers `TrustedUserCAKeys` and into the node's `/etc/ssh/ssh_known_hosts` file

### **Node registration keys [node-registration-key]**

This is the key-pair used by the node's upon registration to the Beekeeper.

- private key: kept secret and copied to the node for Beekeeper registration (i.e. used by the [waggle-bk-registration service](https://github.com/waggle-sensor/waggle-bk-registration))
- public key: un-used

> *Note*: successful registration requires a [node certificate](#creating-a-node-registration-certificate).

## Creating a Node Registration Certificate

The `create-key-cert.sh` script is used to create node registration certificates (signed by the Beekeeper certificate authority).

At a minimum the certification script requires the name of the "Beehive" the node is to be assigned to after registration.

```bash
docker run --rm -it \
  -v ${PWD}:/workdir:rw \
  waggle/beekeeper-key-tools:latest \
  create-key-cert.sh -b <beehive name>
```

Additional parameters can be specified such as the certificates "validity" time (see: ['validity_interval'](https://www.man7.org/linux/man-pages/man1/ssh-keygen.1.html)). This example has the certificate valid for 1 day from the time it is created.

```bash
docker run --rm -it \
  -v ${PWD}:/workdir:rw \
  waggle/beekeeper-key-tools:latest \
  create-key-cert.sh -b <beehive_name> -e +1D
```

For details on other script arguments:

```bash
docker run --rm -it \
  -v ${PWD}:/workdir:rw \
  waggle/beekeeper-key-tools:latest \
  create-key-cert.sh -?
```

This will produce a folder (via the `-o` option) that contains 3 files
- private registration key
- public registration key
- registration certificate

> Note: the private and public registration key will be copied if the `-k` option is provided, otherwise created as a new key-pair.

## Examples

### Creating a CA with no password in a specific directory

```bash
docker run --rm -it \
  -v ${PWD}:/workdir:rw \
  waggle/beekeeper-key-tools:latest \
  create-init-keys.sh -o mydir -p
```

```bash
[NAISE-MAC07.localdomain] ~/workspace/waggle-sensor/beekeeper-key-tools$ ls mydir/
bk-admin-ssh-key	bk-ca			bk-server-key		node-registration-key	node-ssh-key
```

### Create a new registration key-pair and certificate that expires in 1 week

The following command will generate a new registration key-pair and certificate (in the folder `./mydir-newreg`) that expires in 1 week for the `beehive-joe` Beehive using the Beekeeper certificate authority (found in `./beekeeper-keys/bk-ca/beekeeper_ca_key`)

```bash
docker run --rm -it \
  -v ${PWD}:/workdir:rw \
  waggle/beekeeper-key-tools:latest \
  create-key-cert.sh -b beehive-joe -e +1W -c beekeeper-keys/bk-ca/beekeeper_ca_key -o mydir-newreg
```

```bash
[NAISE-MAC07.localdomain] ~/workspace/waggle-sensor/beekeeper-key-tools$ ls mydir-newreg
sage_registration		sage_registration-cert.pub	sage_registration.pub
```

```bash
[NAISE-MAC07.localdomain] ~/workspace/waggle-sensor/beekeeper-key-tools$ ssh-keygen -L -f mydir-newreg/sage_registration-cert.pub
mydir-newreg/sage_registration-cert.pub:
        Type: ssh-ed25519-cert-v01@openssh.com user certificate
        Public key: ED25519-CERT SHA256:cKEpwrxGKz35/gxyR67gi4PxoQpUvtbl6H1XgfuE8eI
        Signing CA: ED25519 SHA256:WagIaLh5GBstGJe3DSdXFA0NoCFwkcM6bUIvi/MxGTk (using ssh-ed25519)
        Key ID: "sage_registration"
        Serial: 0
        Valid: from 2022-07-20T23:31:00 to 2022-07-27T23:32:42
        Principals:
                sage_registration
        Critical Options:
                force-command /opt/sage/beekeeper/register/register.sh -b beehive-joe
        Extensions: (none)
```

### Creating a registration certificate that expires in 1 day

The following command will generate a certificate (in the folder `./mydir-reg`) for the registration keys (`./mydir/node-registration-key/registration.pub`) that expires in 1 day for the `beehive-joe` Beehive using the Beekeeper certificate authority (found in `./mydir/bk-ca/beekeeper_ca_key`)

```bash
docker run --rm -it \
  -v ${PWD}:/workdir:rw \
  waggle/beekeeper-key-tools:latest \
  create-key-cert.sh -b beehive-joe -e +1D -c mydir/bk-ca/beekeeper_ca_key -k mydir/node-registration-key/registration.pub -o mydir-reg
```

> _Note_: the above command uses the node registration key from the `./create-init-keys.sh` script

```bash
[NAISE-MAC07.localdomain] ~/workspace/waggle-sensor/beekeeper-key-tools$ ls mydir-reg/
registration		registration-cert.pub	registration.pub
```

```bash
[NAISE-MAC07.localdomain] ~/workspace/waggle-sensor/beekeeper-key-tools$ ssh-keygen -L -f mydir-reg/registration-cert.pub
mydir-reg/registration-cert.pub:
        Type: ssh-ed25519-cert-v01@openssh.com user certificate
        Public key: ED25519-CERT SHA256:/qrVNtRxYHYIjbvPgVK908R07XwOczjqtenB9wR3vDk
        Signing CA: ED25519 SHA256:25fS21u2zlr7JDI95CzmNsXdONZaBDVjFEhD6kWQ+qQ (using ssh-ed25519)
        Key ID: "sage_registration"
        Serial: 0
        Valid: from 2022-07-20T19:14:00 to 2022-07-21T19:15:41
        Principals:
                sage_registration
        Critical Options:
                force-command /opt/sage/beekeeper/register/register.sh -b beehive-joe
        Extensions: (none)
```
