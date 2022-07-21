#!/bin/bash -e

DEFAULT_CA_PATH=./beekeeper-keys/certca/beekeeper_ca_key
DEFAULT_OUT_PATH=./cert
DEFAULT_KEY_GEN_TYPE=ed25519
DEFAULT_REG_KEY=sage_registration

print_help() {
  echo """
usage: ${0} -b <beehive name> [-e <expire date>] [-c <CA path>] [-k <registration private key path>] [-t <key type>] [-o <outdir>]

Creates a node registration certificate (signed by a certificate authority).

  -b : the beehive the node is to be assigned upon registration (required)
  -e : (optional) certificate expire date (ex. '+1d'; see ssh-keygen(1): 'validity_interval'), certificate will be valid forever if not provided (default: valid forever)
  -c : (optional) path to the certificate authority key used in creation of the registration certificate (default: ${DEFAULT_CA_PATH})
  -k : (optional) path to an existing registration private key for which the certificate is to be created (default: create new key-pair)
  -t : (optional) registration key type (default: ${DEFAULT_KEY_GEN_TYPE})
  -o : (optional) directory created to store output registration certificate (default: ${DEFAULT_OUT_PATH})
  -? : print this help menu
"""
}

BEEHIVE=
VALID="always:forever"
CA_PATH=${DEFAULT_CA_PATH}
KEY_PATH=
KEY_GEN_TYPE=${DEFAULT_KEY_GEN_TYPE}
OUT_PATH=${DEFAULT_OUT_PATH}
while getopts "b:e:c:k:t:o:n?" opt; do
    case $opt in
        b) BEEHIVE=${OPTARG}
            ;;
        e) VALID=${OPTARG}
            ;;
        c) CA_PATH=${OPTARG}
            ;;
        k) KEY_PATH=${OPTARG}
            ;;
        t) KEY_GEN_TYPE=${OPTARG}
            ;;
        o) OUT_PATH=${OPTARG}
            ;;
        ?|*)
            print_help
            exit 1
            ;;
    esac
done

# validate the CA key is found
if [ ! -f "${CA_PATH}" ]; then
    echo "Error: certificate authority key [${CA_PATH}] not found. Exiting."
    exit 1
fi

# validate the key gen type is not empty
if [ -z "${KEY_GEN_TYPE}" ]; then
    echo "Error: key type must not be empty. Exiting"
    exit 1
fi

# validate the provided beehive is formatted properly
if [[ ! $BEEHIVE =~ ^[A-Za-z0-9_\-]+$ ]]; then
    echo "Error: beehive [-b] is required and must contain only these characters [A-Za-z0-9_-]. Exiting."
    exit 1
fi

## create the registration certificate
mkdir -p ${OUT_PATH}

# create registration key if one is not provided
if [ -z "${KEY_PATH}" ]; then
    echo "Generating new registration key-pair [type: ${KEY_GEN_TYPE}]."
    REGPATH=${OUT_PATH}/${DEFAULT_REG_KEY}
    ssh-keygen -f ${REGPATH} -t ${KEY_GEN_TYPE} -N ''
else
    # validate the Registration key is found
    if [ -f "${KEY_PATH}" ]; then
        cp ${KEY_PATH} ${OUT_PATH}/
        cp ${KEY_PATH}.pub ${OUT_PATH}/
        REGPATH=${OUT_PATH}/$(basename ${KEY_PATH})
    else
        echo "Error: registration private key [${KEY_PATH}] not found. Exiting."
        exit 1
    fi
fi

# create the certificate
ssh-keygen \
    -I sage_registration \
    -s ${CA_PATH} \
    -n sage_registration \
    -V ${VALID} \
    -O no-agent-forwarding \
    -O no-port-forwarding \
    -O no-pty \
    -O no-user-rc \
    -O no-x11-forwarding \
    -O force-command="/opt/sage/beekeeper/register/register.sh -b ${BEEHIVE}" \
    ${REGPATH}

echo "Registration certificate created successfully! [${OUT_PATH}]"
