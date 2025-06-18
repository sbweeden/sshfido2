#!/bin/bash
#
# Used to deploy the sshfido2 to kubernetes
#

PODNAME=sshfido2

# You could modify the environment variables here, but better to create a .env file with them in it
# The .env file is included in .gitignore and will not be checked in
USERNAME="testuser"
DISPLAYNAME="Test User"

# Allow override of above variables from a local .env file (which is in .gitignore)
# Basically you can create a .env file with those variables above defined in it with your 
# own values, then you do not have to ever modify this script.
if [ -f .env ]
then
. .env
fi

SNAME=$(kubectl get secrets -o "jsonpath={range .items[?(.metadata.name==\"$PODNAME\")]}{.metadata.name}{end}" 2>/dev/null)
if [ ! -z "$SNAME" ]
then
	echo "Removing existing secret: $SNAME"
	kubectl delete secret $SNAME
fi

kubectl create secret generic $PODNAME \
  --from-literal=USERNAME="$USERNAME" \
  --from-literal=DISPLAYNAME="$DISPLAYNAME"
 

POD=$(kubectl get pod -o json | jq -r ".items[] | select(.metadata.labels.app==\"$PODNAME\") | .metadata.name")

if [ ! -z "$POD" ]
then 
  echo "Deleting existing pod: $PODNAME"
  kubectl delete pod $PODNAME
fi

PODSVC=$(kubectl get svc -o json | jq -r ".items[] | select(.metadata.name==\"$PODNAME\") | .metadata.name")
if [ ! -z "$PODSVC" ]
then 
  echo "Deleting existing service: $PODSVC"
  kubectl delete service $PODSVC
fi

kubectl create -f "$PODNAME.yaml"
