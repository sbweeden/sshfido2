#!/bin/bash

# Check for the existence of a public key file in the resources directory

if ! ls resources/id_ed25519_sk.pub 1> /dev/null 2>&1
then
  echo "You need to setup a private/public keypair first before building this image"
  echo "Put the id_ed25519_sk.pub file in the resources directory"
  echo "Exiting!"
  exit 1
fi

# Build - including support for building on my M1 Mac
if uname -a | grep -q arm64
then
  # This is how I build it on an M1 Mac and push straight to a target container registry
  # You change the target registry and/or remove the --push as needed
  #docker buildx build --push --platform linux/amd64 --tag us.icr.io/sweeden/sshfido2:latest .
  docker buildx build --platform linux/amd64 --tag sshfido2:latest .
else
  # This is typical on an intel system
  docker build --tag sshfido2:latest .
fi
