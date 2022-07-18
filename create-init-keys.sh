#!/bin/bash

if [ "${1}_" != "native_" ] ; then
    echo "Launching docker container..."
    docker run -i \
        -v `pwd`:/workdir/:rw \
        --workdir=/workdir \
        --env KEY_GEN_TYPE=${KEY_GEN_TYPE} \
        waggle/waggle-pki-tools ./create-init-keys.sh native ${@}
    exit 0
fi

set -e
export DATADIR=/workdir/beekeeper-keys
mkdir -p ${DATADIR}

### INIT ###

if [ -z "${KEY_GEN_TYPE}" ] ; then
    KEY_GEN_TYPE="ed25519"
fi

echo "KEY_GEN_TYPE: ${KEY_GEN_TYPE}"

if [ "${3}_" != "--nopassword_" ] ; then
    echo "Enter password for new CA:"
    read -s ca_password
else
    # needed for automated testing
    export ca_password=""
fi

set -e

### admin key-pair ###
if [ ! -e ${DATADIR}/admin-key/admin.pem  ] ; then
    set -x
    mkdir -p ${DATADIR}/admin-key
    ssh-keygen -f ${DATADIR}/admin-key/admin.pem -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N ''
    set +x
fi

### nodes key-pair ###
# the public key of this key-pair is baked into the images, so beekeeper can ssh into the nodes.
if [ ! -e ${DATADIR}/node-key/nodes.pem  ] ; then
    set -x
    mkdir -p ${DATADIR}/node-key
    ssh-keygen -f ${DATADIR}/node-key/nodes.pem -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N ''
    set +x
fi

CERT_CA_TARGET_DIR="${DATADIR}/certca"
### CA ###
if [ ! -e ${CERT_CA_TARGET_DIR}/beekeeper_ca_key ] ; then


    mkdir -p ${CERT_CA_TARGET_DIR}

    echo ssh-keygen -f ${CERT_CA_TARGET_DIR}/beekeeper_ca_key -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N "*****"
    ssh-keygen -f ${CERT_CA_TARGET_DIR}/beekeeper_ca_key -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N "${ca_password}"


else
    echo "CA already exists"
fi

# beekeeper server key-pair and cert

if [ ! -e ${DATADIR}/bk-server/beekeeper_server_key-cert.pub ] ; then
    echo "creating beekeeper server key-pair and certificate... "


    CERT_SERVER_TARGET_DIR="${DATADIR}/bk-server"

    set -x
    mkdir -p ${CERT_SERVER_TARGET_DIR}


    # create key pair
    if [ ! -e ${CERT_SERVER_TARGET_DIR}/beekeeper_server_key ] ; then
        ssh-keygen -f ${CERT_SERVER_TARGET_DIR}/beekeeper_server_key -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N ''
    fi
    set +x
    # sign key (creates beekeeper_server_key-cert.pub) This creates the sshd "HostCertificate" file
    echo sshpass -v -P passphrase -p "******"  ssh-keygen -I beekeeper_server -s ${CERT_CA_TARGET_DIR}/beekeeper_ca_key -h ${CERT_SERVER_TARGET_DIR}/beekeeper_server_key.pub
    sshpass -v -P passphrase -p "${ca_password}"  ssh-keygen -I beekeeper_server -s ${CERT_CA_TARGET_DIR}/beekeeper_ca_key -h ${CERT_SERVER_TARGET_DIR}/beekeeper_server_key.pub

else
    echo "beekeeper server key-pair and cert already exist"
fi

# registration key-pair (NOT reg certificate ! )

if [ ! -e ${DATADIR}/registration-keys/registration ] ; then

    mkdir -p ${DATADIR}/registration-keys/

    ssh-keygen -f ${DATADIR}/registration-keys/registration -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N ''
else
    echo "reg key already exists"

fi