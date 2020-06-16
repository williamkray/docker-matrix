#!/usr/bin/env bash

## use this script to easily register new
## users without having to enable registration
## on the synapse server

source host.conf

docker-compose exec synapse register_new_matrix_user -c /data/homeserver.yaml https://$HOSTNAME
