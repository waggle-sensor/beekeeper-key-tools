#!/bin/bash -e

DEFAULT_CA_PATH=./beekeeper-keys/certca/beekeeper_ca_key
DEFAULT_KEY_PATH=./beekeeper-keys/registration_keys/registration.pub
DEFAULT_OUT_PATH=./cert

print_help() {
  echo """
usage: create-key-cert.sh -b <beehive name> [-e <expire date>] [-c <CA path>] [-k <registration public key path>] [-o <outdir>] [-n]

Creates a node registration certificate (signed by a certificate authority).

  -b : the beehive the node is to be assigned upon registration (required)
  -e : (optional) certificate expire date (ex. '+1d'; see ssh-keygen(1): 'validity_interval'), certificate will be valid forever if not provided (default: valid forever)
  -c : (optional) path to the unlocked certificate authority key used in creation of the registration certificate (default: ${DEFAULT_CA_PATH})
  -k : (optional) path to the registration public key for which the certificate is to be created (default: ${DEFAULT_KEY_PATH})
  -o : (optional) directory created to store output registration certificate (default: ${DEFAULT_OUT_PATH})
  -n : (optional) flag to indicate script should _not_ be run within Docker (default: not set; run within Docker)
  -? : print this help menu
"""
}

BEEHIVE=
VALID="always:forever"
CA_PATH=${DEFAULT_CA_PATH}
KEY_PATH=${DEFAULT_KEY_PATH}
OUT_PATH=${DEFAULT_OUT_PATH}
NATIVE=
while getopts "b:e:c:k:o:n?" opt; do
    case $opt in
        b) BEEHIVE=${OPTARG}
            ;;
        e) VALID=${OPTARG}
            ;;
        c) CA_PATH=${OPTARG}
            ;;
        k) KEY_PATH=${OPTARG}
            ;;
        o) OUT_PATH=${OPTARG}
            ;;
        n) NATIVE=1
            ;;
        ?|*)
            print_help
            exit 1
            ;;
    esac
done

if [ -z "${NATIVE}" ]; then
    echo "Launching docker container..."
    docker run -it \
        -v `pwd`:/workdir/:rw \
        --workdir=/workdir \
        waggle/waggle-pki-tools ./create-key-cert.sh -n ${@}
    exit 0
fi

# validate the CA key is found
if [ ! -f "${CA_PATH}" ]; then
    echo "Error: certificate authority key [${CA_PATH}] not found. Exiting."
    exit 1
fi

# validate the Registration key is found
if [ ! -f "${KEY_PATH}" ]; then
    echo "Error: registration public key [${KEY_PATH}] not found. Exiting."
    exit 1
fi

# validate the provided beehive is formatted properly
if [[ ! $BEEHIVE =~ ^[A-Za-z0-9_\-]+$ ]]; then
    echo "Error: beehive [-b] is required and must contain only these characters [A-Za-z0-9_-]. Exiting."
    exit 1
fi

# make output directory and copy registration public and private key
mkdir -p ${OUT_PATH}
cp ${KEY_PATH} ${OUT_PATH}/
cp ${KEY_PATH%.*} ${OUT_PATH}/

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
    ${OUT_PATH}/$(basename ${KEY_PATH})

echo "Registration certificate created successfully! [${OUT_PATH}]"
