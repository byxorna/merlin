#!/bin/bash
IMAGE="$1"
if [[ -z $IMAGE ]] ; then
  boot2docker ssh docker ps
  echo "What container do you want to kill?"
  read IMAGE
fi
boot2docker ssh docker kill $IMAGE
