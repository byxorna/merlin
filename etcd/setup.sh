#!/bin/bash

PUBLIC_IP="${1:-192.168.59.103}"
PUBLIC_PORT="${2:-4001}"
CONTAINER_NAME=etcd0
CONTAINER_PORT=4001
echo "Starting up etcd container on $PUBLIC_IP:$PUBLIC_PORT -> $CONTAINER_NAME:$CONTAINER_PORT"
boot2docker ssh docker run -p $PUBLIC_PORT:$CONTAINER_PORT -p 7001:7001 coreos/etcd -addr $PUBLIC_IP:$PUBLIC_PORT -name=$CONTAINER_NAME

echo "etcd terminated"

