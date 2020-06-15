#!/usr/bin/env bash

set -e

## this script will set up your matrix server
## from beginning to end.

## you must have a properly modified host.conf file
## to set these values

if ! [ -f host.conf ]; then
	echo "no host.conf file found. please create one by modifying templates/host.conf.sample"
	exit 1
fi

source host.conf

echo "setting permissions on acme.json"
chmod 600 storage/traefik/config/acme.json

echo "generating initial synapse config file for $HOSTNAME"
docker run --rm -it \
	-v "$PWD/storage/synapse/data:/data" \
	-e SYNAPSE_SERVER_NAME=$HOSTNAME \
	-e SYNAPSE_REPORT_STATS=yes \
  -e UID=1000 \
  -e GID=1000 \
	matrixdotorg/synapse:latest generate

echo "config file generated in ./storage/synapse/data/homeserver.yaml"

echo "starting with base docker-compose file"
cp templates/docker-compose.yml.sample docker-compose.yml

echo "replacing acme email address"
sed -i "s/REPLACE_WITH_ACME_EMAIL/${ACME_EMAIL}/g" docker-compose.yml

echo "updating PostgreSQL password in docker-compose.yml"
sed -i "s/REPLACE_WITH_POSTGRES_PW/${POSTGRES_PW}/g" docker-compose.yml

echo "updating synapse docker labels in docker-compose.yml"
sed -i "s/REPLACE_WITH_MATRIX_HOST/${MATRIX_HOST}/g" docker-compose.yml

echo "starting with base Riot config file"
mkdir -p storage/riot/data
cp templates/riot.config.json.sample storage/riot/data/config.json

echo "updating Riot config file"
sed -i "s/REPLACE_WITH_MATRIX_HOST/${MATRIX_HOST}/g" storage/riot/data/config.json

echo "updating Riot docker labels in docker-compose.yml"
sed -i "s/REPLACE_WITH_RIOT_HOST/${RIOT_HOST}/g" docker-compose.yml

echo "modifying synapse config to use postgres instead of sqlite"
sed -i "s/^  name: sqlite3/  name: psycopg2/" storage/synapse/data/homeserver.yaml
sed -i "s#^    database: /data/homeserver.db#    user: synapse_user\n    password: ${POSTGRES_PW}\n    database: synapse\n    host: database\n    cp_min: 5\n    cp_max: 10#" storage/synapse/data/homeserver.yaml
