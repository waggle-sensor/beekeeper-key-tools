#!/bin/bash -e

DEFAULT_KEY_GEN_TYPE=ed25519
DEFAULT_OUT_PATH=./beekeeper-keys

print_help() {
  echo """
usage: ${0} [-t <key type>] [-o <outdir>] [-p]

Creates a node registration certificate (signed by a certificate authority).

  -t : (optional) key type (default: ${DEFAULT_KEY_GEN_TYPE})
  -o : (optional) directory created to store output registration certificate (default: ${DEFAULT_OUT_PATH})
  -p : (optional) flag to indicate script should generate a certificate authority with _no_ password (default: require password)
  -? : print this help menu
"""
}

KEY_GEN_TYPE=${DEFAULT_KEY_GEN_TYPE}
OUT_PATH=${DEFAULT_OUT_PATH}
CA_PASSWD=1
while getopts "t:o:pn?" opt; do
    case $opt in
        t) KEY_GEN_TYPE=${OPTARG}
            ;;
        o) OUT_PATH=${OPTARG}
            ;;
        p) CA_PASSWD=
            ;;
        ?|*)
            print_help
            exit 1
            ;;
    esac
done

# validate the key gen type is not empty
if [ -z "${KEY_GEN_TYPE}" ]; then
    echo "Error: key type must not be empty. Exiting"
    exit 1
fi
echo "KEY_GEN_TYPE: ${KEY_GEN_TYPE}"

# get the CA password
if [ -z "${CA_PASSWD}" ]; then
    # needed for automated testing
    export ca_password=""
else
    echo "Enter password for new certificate authority (CA):"
    read -s ca_password
fi

mkdir -p ${OUT_PATH}

### admin key-pair ###
BK_SSH_DIR="${OUT_PATH}/bk-admin-ssh-key"
BK_SSH_KEY="${BK_SSH_DIR}/admin.pem"
KEY_DESC="beekeeper admin key-pair"
if [ ! -e ${BK_SSH_KEY} ] ; then
    echo "Creating: ${KEY_DESC}... "
    mkdir -p ${BK_SSH_DIR}
    ssh-keygen -f ${BK_SSH_KEY} -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N ''
else
    echo "Skipped: ${KEY_DESC} already exists"
fi

### nodes key-pair ###
# the public key of this key-pair is baked into the images, so beekeeper can ssh into the nodes.
NODE_SSH_DIR="${OUT_PATH}/node-ssh-key"
NODE_SSH_KEY="${NODE_SSH_DIR}/nodes.pem"
KEY_DESC="node ssh key-pair"
if [ ! -e ${NODE_SSH_KEY}  ] ; then
    echo "Creating: ${KEY_DESC}... "
    mkdir -p ${NODE_SSH_DIR}
    ssh-keygen -f ${NODE_SSH_KEY} -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N ''
else
    echo "Skipped: ${KEY_DESC} already exists"
fi

### CA ###
CERT_CA_DIR="${OUT_PATH}/bk-ca"
CERT_CA_KEY="${CERT_CA_DIR}/beekeeper_ca_key"
KEY_DESC="beekeeper certificate authority key-pair"
if [ ! -e ${CERT_CA_KEY} ] ; then
    echo "Creating: ${KEY_DESC}... "
    mkdir -p ${CERT_CA_DIR}
    ssh-keygen -f ${CERT_CA_KEY} -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N "${ca_password}"
else
    echo "Skipped: ${KEY_DESC} already exists"
fi

# beekeeper server key-pair and cert
CERT_SERVER_DIR="${OUT_PATH}/bk-server-key"
CERT_SERVER_KEY="${CERT_SERVER_DIR}/beekeeper_server_key"
KEY_DESC="beekeeper server key-pair and certificate"
if [ ! -e ${CERT_SERVER_KEY}-cert.pub ] ; then
    echo "Creating: ${KEY_DESC}... "
    mkdir -p ${CERT_SERVER_DIR}

    # create key pair
    if [ ! -e ${CERT_SERVER_KEY} ] ; then
        ssh-keygen -f ${CERT_SERVER_KEY} -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N ''
    fi

    # sign key (creates beekeeper_server_key-cert.pub) This creates the sshd "HostCertificate" file
    echo sshpass -v -P passphrase -p "******"  ssh-keygen -I beekeeper_server -s ${CERT_CA_KEY} -h ${CERT_SERVER_KEY}.pub
    sshpass -v -P passphrase -p "${ca_password}"  ssh-keygen -I beekeeper_server -s ${CERT_CA_KEY} -h ${CERT_SERVER_KEY}.pub
else
    echo "Skipped: ${KEY_DESC} already exists"
fi

# registration key-pair (NOT reg certificate ! )
NODE_REG_DIR="${OUT_PATH}/node-registration-key"
NODE_REG_KEY="${NODE_REG_DIR}/registration"
KEY_DESC="node registration key-pair"
if [ ! -e ${NODE_REG_KEY} ] ; then
    echo "Creating: ${KEY_DESC}... "
    mkdir -p ${NODE_REG_DIR}
    ssh-keygen -f ${NODE_REG_KEY} -t ${KEY_GEN_TYPE} ${KEY_GEN_ARGS} -N ''
else
    echo "Skipped: ${KEY_DESC} already exists"
fi

echo "All keys created successfully! [${OUT_PATH}]"
