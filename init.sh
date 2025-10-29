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
mkdir -p storage/traefik/config
touch storage/traefik/config/acme.json
chmod 600 storage/traefik/config/acme.json

echo "moving db-init script into place"
mkdir -p storage/postgresql/
cp templates/init-db.sh storage/postgresql/init-db.sh

echo "adding nginx config file"
mkdir -p storage/nginx/
cp templates/nginx.conf.sample storage/nginx/matrix.conf
sed -i "s/REPLACE_WITH_MATRIX_HOST/$MATRIX_HOST/" storage/nginx/matrix.conf

echo "generating initial synapse config file for $HOSTNAME"
docker run --rm -it \
  -v "$PWD/storage/synapse/data:/data" \
  -e SYNAPSE_SERVER_NAME=$HOSTNAME \
  -e SYNAPSE_REPORT_STATS=yes \
  -e UID=${UID} \
  -e GID=${UID} \
  ghcr.io/element-hq/synapse:${SYNAPSE_VERSION_TAG} generate

echo "config file generated in ./storage/synapse/data/homeserver.yaml"

echo "generating initial MAS config file"
mkdir -p storage/mas/data
docker run --rm \
  ghcr.io/element-hq/matrix-authentication-service \
  config generate > storage/mas/data/config.yaml

echo "config file generated in ./storage/mas/data/config.yaml"

echo "generating initial maubot config file"
docker run --rm -it \
  -v "$PWD/storage/maubot/data:/data" \
  dock.mau.dev/maubot/maubot:latest


echo "starting with base docker-compose file"
cp templates/docker-compose.yml.sample docker-compose.yml

echo "replacing UID in docker-compose"
sed -i "s/REPLACE_WITH_UID/${UID}/g" docker-compose.yml

echo "replacing container version tags"
sed -i "s/REPLACE_WITH_SYNAPSE_VERSION_TAG/${SYNAPSE_VERSION_TAG}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_MAS_VERSION_TAG/${MAS_VERSION_TAG}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_ELEMENT_VERSION_TAG/${ELEMENT_VERSION_TAG}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_POSTGRES_VERSION_TAG/${POSTGRES_VERSION_TAG}/g" docker-compose.yml

echo "replacing acme email address"
sed -i "s/REPLACE_WITH_ACME_EMAIL/${ACME_EMAIL}/g" docker-compose.yml

echo "updating PostgreSQL password in docker-compose.yml and init script"
sed -i "s/REPLACE_WITH_POSTGRES_PW/${POSTGRES_PW}/g" storage/postgresql/init-db.sh
sed -i "s/REPLACE_WITH_POSTGRES_MAS_PW/${POSTGRES_MAS_PW}/g" storage/postgresql/init-db.sh
sed -i "s/REPLACE_WITH_POSTGRES_ROOT_PW/${POSTGRES_ROOT_PW}/g" docker-compose.yml

echo "updating docker labels in docker-compose.yml"
sed -i "s/REPLACE_WITH_MATRIX_HOST/${MATRIX_HOST}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_MAS_HOST/${MAS_HOST}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_HOSTNAME/${HOSTNAME}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_SITE_HOST/${SITE_HOST}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_REDIRECT_HOST/${REDIRECT_HOST}/g" docker-compose.yml

echo "starting with base Element config file"
mkdir -p storage/element/data
cp templates/element.config.json.sample storage/element/data/config.json

echo "updating Element config file"
sed -i "s/REPLACE_WITH_MATRIX_HOST/${MATRIX_HOST}/g" storage/element/data/config.json
sed -i "s/REPLACE_WITH_HOSTNAME/${HOSTNAME}/g" storage/element/data/config.json

echo "updating Element docker labels in docker-compose.yml"
sed -i "s/REPLACE_WITH_ELEMENT_HOST/${ELEMENT_HOST}/g" docker-compose.yml

echo "updating maubot labels in docker-compose.yml"
sed -i "s/REPLACE_WITH_MAUBOT_HOST/${MAUBOT_HOST}/g" docker-compose.yml

echo "modifying synapse config to use postgres instead of sqlite"
sed -i "s/^  name: sqlite3/  name: psycopg2/" storage/synapse/data/homeserver.yaml
sed -i "s#^    database: /data/homeserver.db#    user: synapse_user\n    password: ${POSTGRES_PW}\n    database: synapse\n    host: database\n    cp_min: 5\n    cp_max: 10#" storage/synapse/data/homeserver.yaml

echo "modifying MAS config to use postgres and connect to synapse"
sed -i "s#^  issuer: http://\[::\]:8080/##" storage/mas/data/config.yaml
sed -i "s#^  public_base: http://\[::\]:8080/#  public_base: https://${MAS_HOST}/#" storage/mas/data/config.yaml
sed -i "s#^  uri: postgresql://#  uri: postgresql://mas_user:${POSTGRES_MAS_PW}@database/mas#" storage/mas/data/config.yaml
sed -i "s#^  homeserver: localhost:8008#  homeserver: ${HOSTNAME}#" storage/mas/data/config.yaml
sed -i "s#^  endpoint: http://localhost:8008/#  endpoint: https://${MATRIX_HOST}#" storage/mas/data/config.yaml
MAS_SYNAPSE_SHARED_SECRET=$(grep '  secret: ' ./storage/mas/data/config.yaml | awk '{print $2}' | tr -d '\r')
sed -i "s/^# vim:ft=yaml//" ./storage/synapse/data/homeserver.yaml
cat << EOF >> ./storage/synapse/data/homeserver.yaml
matrix_authentication_service:
  enabled: true
  endpoint: https://${MAS_HOST}/
  secret: "${MAS_SYNAPSE_SHARED_SECRET}"
EOF

echo "starting everything up..."
#docker compose up -d

echo "done"
