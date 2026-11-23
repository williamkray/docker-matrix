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

## defaults for settings that older host.conf files may not have
: "${COMPRESSOR_VERSION_TAG:=latest}"
: "${TIMEZONE:=UTC}"
: "${DB_BACKUP_SCHEDULE:=0 3 * * *}"
: "${DB_BACKUP_KEEP:=7}"
: "${DB_BACKUP_NTFY_URL:=}"
: "${STATE_COMPRESSOR_SCHEDULE:=30 4 * * *}"
: "${ROOM_PURGE_AFTER:=28d}"

## postgres 18 moved its data directory: mounting the parent with an older image would put the
## database in an anonymous docker volume instead of ./storage. latest (or any non-number) is 18+.
postgres_major=${POSTGRES_VERSION_TAG%%[.-]*}
if [[ "$postgres_major" =~ ^[0-9]+$ ]] && [ "$postgres_major" -lt 18 ]; then
  POSTGRES_DATA_PATH=/var/lib/postgresql/data
else
  POSTGRES_DATA_PATH=/var/lib/postgresql
fi
## the backup container must be the same postgres version, alpine variant (latest -> alpine, 17-trixie -> 17-alpine)
if [ "$POSTGRES_VERSION_TAG" = latest ]; then
  DB_DUMP_IMAGE_TAG=alpine
else
  DB_DUMP_IMAGE_TAG="${POSTGRES_VERSION_TAG%%-*}-alpine"
fi

if [ -d /usr/share/zoneinfo ] && ! [ -e "/usr/share/zoneinfo/${TIMEZONE}" ]; then
  echo "unknown TIMEZONE '${TIMEZONE}' in host.conf (expected something like America/New_York or UTC)"
  exit 1
fi

## refuse to run over an existing deployment. this script regenerates secrets and overwrites
## configs: re-running it would break MAS and the lk-jwt appservice, append duplicate blocks to
## homeserver.yaml, and leave docker-compose.yml with passwords the existing database doesn't use.
existing=""
for f in docker-compose.yml storage/synapse/data/homeserver.yaml storage/mas/data/config.yaml storage/postgresql/data; do
  if [ -e "$f" ]; then existing="$existing  $f\n"; fi
done
if [ -n "$existing" ]; then
  printf "refusing to run: this looks like an existing deployment. found:\n$existing"
  echo "init.sh is only for the first setup and would overwrite or break the above."
  echo "to start over from scratch (DESTROYS all data): docker compose down, then move or delete"
  echo "./storage and ./docker-compose.yml, and run init.sh again."
  exit 1
fi

echo "setting permissions on acme.json"
mkdir -p storage/traefik/config
touch storage/traefik/config/acme.json
chmod 600 storage/traefik/config/acme.json

echo "moving db-init script into place"
mkdir -p storage/postgresql/
cp templates/init-db.sh storage/postgresql/init-db.sh

echo "adding database backup script and backup directory"
mkdir -p storage/db-dump storage/backups/postgresql
cp templates/db-dump.sh storage/db-dump/db-dump.sh

echo "adding synapse state compressor build files"
mkdir -p storage/statecompressor
cp templates/statecompressor/* storage/statecompressor/
sed -i "s/REPLACE_WITH_COMPRESSOR_VERSION_TAG/${COMPRESSOR_VERSION_TAG}/g" storage/statecompressor/Dockerfile

echo "adding nginx config file"
mkdir -p storage/nginx/
cp templates/nginx.conf.sample storage/nginx/matrix.conf
sed -i "s/REPLACE_WITH_MATRIX_HOST/$MATRIX_HOST/" storage/nginx/matrix.conf
sed -i "s/REPLACE_WITH_MATRIX_RTC_HOST/${MATRIX_RTC_HOST}/g" storage/nginx/matrix.conf

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
sed -i "s/REPLACE_WITH_DB_DUMP_IMAGE_TAG/${DB_DUMP_IMAGE_TAG}/g" docker-compose.yml
sed -i "s|REPLACE_WITH_POSTGRES_DATA_PATH|${POSTGRES_DATA_PATH}|g" docker-compose.yml
sed -i "s/REPLACE_WITH_MATRIX_JWT_VERSION_TAG/${MATRIX_JWT_VERSION_TAG}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_LIVEKIT_VERSION_TAG/${LIVEKIT_VERSION_TAG}/g" docker-compose.yml

echo "setting timezone and schedules for backups and state compression"
## | as the sed delimiter: timezones, cron schedules and URLs can contain /
sed -i "s|REPLACE_WITH_TIMEZONE|${TIMEZONE}|g" docker-compose.yml
sed -i "s|REPLACE_WITH_DB_BACKUP_SCHEDULE|${DB_BACKUP_SCHEDULE}|g" docker-compose.yml
sed -i "s|REPLACE_WITH_DB_BACKUP_KEEP|${DB_BACKUP_KEEP}|g" docker-compose.yml
sed -i "s|REPLACE_WITH_DB_BACKUP_NTFY_URL|${DB_BACKUP_NTFY_URL}|g" docker-compose.yml
sed -i "s|REPLACE_WITH_STATE_COMPRESSOR_SCHEDULE|${STATE_COMPRESSOR_SCHEDULE}|g" docker-compose.yml

echo "replacing acme email address"
sed -i "s/REPLACE_WITH_ACME_EMAIL/${ACME_EMAIL}/g" docker-compose.yml

echo "updating PostgreSQL password in docker-compose.yml and init script"
sed -i "s/REPLACE_WITH_POSTGRES_PW/${POSTGRES_PW}/g" storage/postgresql/init-db.sh
sed -i "s/REPLACE_WITH_POSTGRES_MAS_PW/${POSTGRES_MAS_PW}/g" storage/postgresql/init-db.sh
sed -i "s/REPLACE_WITH_POSTGRES_ROOT_PW/${POSTGRES_ROOT_PW}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_POSTGRES_PW/${POSTGRES_PW}/g" docker-compose.yml

echo "updating docker labels in docker-compose.yml"
sed -i "s/REPLACE_WITH_MATRIX_HOST/${MATRIX_HOST}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_MAS_HOST/${MAS_HOST}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_HOSTNAME/${HOSTNAME}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_SITE_HOST/${SITE_HOST}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_REDIRECT_HOST/${REDIRECT_HOST}/g" docker-compose.yml
sed -i "s/REPLACE_WITH_MATRIX_RTC_HOST/${MATRIX_RTC_HOST}/g" docker-compose.yml

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

echo "generating lk-jwt-service application service registration"
lk_jwt_as_token=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 64)
lk_jwt_hs_token=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 64)
cp templates/lk-jwt-registration.yaml.sample ./storage/synapse/data/lk-jwt-registration.yaml
sed -i "s/REPLACE_WITH_LK_JWT_AS_TOKEN/${lk_jwt_as_token}/g" ./storage/synapse/data/lk-jwt-registration.yaml ./docker-compose.yml
sed -i "s/REPLACE_WITH_LK_JWT_HS_TOKEN/${lk_jwt_hs_token}/g" ./storage/synapse/data/lk-jwt-registration.yaml ./docker-compose.yml
sed -i "s/REPLACE_WITH_MATRIX_RTC_HOST/${MATRIX_RTC_HOST}/g" ./storage/synapse/data/lk-jwt-registration.yaml

echo "modifying synapse config for matrix-rtc (element-call) and room cleanup"
cat << EOF >> ./storage/synapse/data/homeserver.yaml
app_service_config_files:
  - /data/lk-jwt-registration.yaml

experimental_features:
  # MSC4143: advertise the matrix_rtc transports below to clients
  msc4143_enabled: true
  # MSC4075: matrix-rtc call invites and notifications
  msc4075_enabled: true
  # MSC4354: sticky events, used by element-call for call memberships
  msc4354_enabled: true
  # MSC4502 + MSC4512: lk-jwt-service as an application service (room membership lookups, and
  # Synapse proxying /rtc/livekit requests to it on the client-server and federation APIs)
  msc4502_enabled: true
  msc4512_enabled: true

matrix_rtc:
  transports:
    # current clients get livekit tokens through Synapse (proxied to the lk-jwt appservice).
    # url must equal LIVEKIT_URL of the jwt service in docker-compose.yml.
    - type: m.livekit
      url: wss://${MATRIX_RTC_HOST}/livekit/sfu
    # older clients call lk-jwt-service directly (also advertised in .well-known/matrix/client)
    - type: livekit
      url: wss://${MATRIX_RTC_HOST}/livekit/sfu
      livekit_service_url: https://${MATRIX_RTC_HOST}/livekit/jwt

# The maximum allowed duration by which sent events can be delayed, as
# per MSC4140.
max_event_delay_duration: 24h

rc_message:
  # This needs to match at least e2ee key sharing frequency plus a bit of headroom
  # Note key sharing events are bursty
  per_second: 0.5
  burst_count: 30

rc_delayed_event_mgmt:
  # This needs to match at least the heart-beat frequency plus a bit of headroom
  # Currently the heart-beat is every 5 seconds which translates into a rate of 0.2s
  per_second: 1
  burst_count: 20

# Rooms a user leaves are forgotten automatically. Once every local ex-member has forgotten a
# room, it is purged from the database after this period. Without these, rooms nobody on your
# server is in anymore (e.g. large public rooms you left) stay in the database forever.
# Trade-off: users can't scroll back through rooms they've left.
forget_rooms_on_leave: true
forgotten_room_retention_period: ${ROOM_PURGE_AFTER}
EOF

echo "starting with sample livekit config file"
mkdir -p ./storage/livekit/data
cp ./templates/livekit.config.sample ./storage/livekit/data/config.yaml

echo "generating key/secret for livekit"
livekit_key=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)
livekit_secret=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 40)

echo "injecting key/secret into livekit config and docker-compose"
sed -i "s/REPLACE_WITH_LIVEKIT_KEY/${livekit_key}/" ./storage/livekit/data/config.yaml ./docker-compose.yml
sed -i "s/REPLACE_WITH_LIVEKIT_SECRET/${livekit_secret}/" ./storage/livekit/data/config.yaml ./docker-compose.yml

#echo "starting everything up..."
#docker compose up -d

echo ""
echo ""
echo "================="
echo 'you can now inspect your generated files. configs and persistent storage is in the folder named "storage".

run "docker compose up -d" to launch your services, and wait a few minutes for SSL certificates to be generated by LetsEncrypt. 

interactively create your first matrix user with the ./register.sh script. have fun!'
echo ""
echo "done"
