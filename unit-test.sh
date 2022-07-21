#!/bin/bash -e

pass() {
  echo "--> PASS"
}

fail() {
  echo "--> FAIL"
  exit $1
}

DOCKERTAG="beekeeper-key-tools:test"
docker build . -t ${DOCKERTAG}

echo "01: Test create init keys (no password)..."
if docker run --rm \
        -v $PWD:/workdir:rw \
        ${DOCKERTAG} \
        create-init-keys.sh \
        -o testkeys \
        -p ; then
    pass
else
    fail 1
fi

echo "02: Test create registration cert..."
if docker run --rm \
        -v $PWD:/workdir:rw \
        ${DOCKERTAG} \
        create-key-cert.sh \
        -b beehive-test \
        -o testkeys-reg \
        -e +1D \
        -c testkeys/bk-ca/beekeeper_ca_key \
        -k testkeys/node-registration-key/registration.pub ; then
    pass
else
    fail 2
fi

echo "03: Verify the regisration cert beehive is correct..."
if ssh-keygen -L -f testkeys-reg/registration-cert.pub \
        | grep 'force-command' \
        | grep 'beehive-test' ; then
    pass
else
    fail 3
fi
