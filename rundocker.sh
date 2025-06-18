#!/bin/bash

# READ IN ENV VARS
while IFS= read -r line; do
    export $line
done < .env

# run it
docker run --rm --detach \
  --privileged \
  -p 127.0.0.1:30222:22/tcp \
  --env-file .env \
  --name sshfido2 \
  sshfido2:latest

echo "The container should be running now. Check with: docker ps -a"
echo "To try it:"
echo "$ ssh -l $USERNAME -p 30222 localhost"
echo "To stop it when done:"
echo "$ docker stop sshfido2"
