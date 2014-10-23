#!/bin/bash

boot2docker ssh docker run -p 3333:80 -v /tmp/haproxy:/haproxy-override dockerfile/haproxy

boot2docker ssh docker ps
