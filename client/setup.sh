#!/bin/bash

CONFD=~/code/go/bin/confd
CONF_DIR="${1:-$(pwd)}"
ETCD_SERVER="192.168.59.103"
ETCD_PORT=4001

echo "Using confdir $CONF_DIR"
[[ ! -d $CONF_DIR/conf.d ]] && echo "No conf.d directory found at $CONF_DIR" && exit 1
[[ ! -d $CONF_DIR/templates ]] && echo "No templates directory found at $CONF_DIR" && exit 1
$CONFD -backend etcd -node $ETCD_SERVER:$ETCD_PORT -confdir $CONF_DIR -debug -watch


