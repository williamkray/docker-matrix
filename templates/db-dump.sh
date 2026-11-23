#!/bin/sh
# Nightly logical postgres dumps, run by crond in the `db-dump` service of docker-compose.yml,
# which mounts storage/db-dump read-only at /opt/db-dump and storage/backups/postgresql at /dumps.
# (A directory mount, not the file: editors and git replace files, and a single-file bind mount
# keeps serving the old one.) The db-dump image must be the same postgres major as the server.
#
# Env: PGHOST PGUSER PGPASSWORD   superuser connection to the stack's postgres
#      DUMP_NAME                  label for logs/alerts (e.g. the stack name)
#      DUMP_DATABASES             space-separated DBs; default: every non-template DB but postgres
#      KEEP_DUMPS                 dumps to keep (default 7, minimum 1)
#      BACKUP_NTFY_URL            full ntfy URL for failure alerts (optional)
#
# Writes /dumps/<timestamp>/{globals.sql,<db>.dump} atomically. Old dumps are pruned only after a
# fully successful dump, so a failure never eats good ones. Any failure sends an ntfy alert.
#
# Restore into a fresh cluster (roles first, then each DB):
#   psql -f globals.sql            # skip if it holds md5 hashes; let the image create the role
#   createdb -O <owner> -T template0 [-E UTF8 --locale=C] <db>   # match the original's locale
#   pg_restore -d <db> -j4 <db>.dump
set -eu
umask 077

NAME="${DUMP_NAME:-postgres}"
KEEP="${KEEP_DUMPS:-7}"
[ "$KEEP" -ge 1 ] 2>/dev/null || KEEP=1
ts=$(date +%Y%m%dT%H%M%S)
tmp="/dumps/.inprogress-$ts"
step="start"

on_exit() {
  rc=$?
  [ "$rc" = 0 ] && return 0
  echo "$(date -Is) db-dump FAILED at: $step (exit $rc)"
  if [ -n "${BACKUP_NTFY_URL:-}" ]; then
    wget -q -O /dev/null --post-data "$NAME db dump failed at: $step (exit $rc)" "$BACKUP_NTFY_URL" || true
  fi
  rm -rf "$tmp"
}
trap on_exit EXIT

DBS="${DUMP_DATABASES:-}"
if [ -z "$DBS" ]; then
  step="list databases"
  DBS=$(psql -X -d postgres -Atc "select datname from pg_database where not datistemplate and datname <> 'postgres' order by 1")
fi
step="no databases found"
[ -n "$DBS" ]

echo "$(date -Is) db-dump starting ($NAME: $(echo $DBS))"
step="prepare $tmp"
rm -rf /dumps/.inprogress-*
mkdir -p "$tmp"

step="globals"
pg_dumpall --globals-only -f "$tmp/globals.sql"
for db in $DBS; do
  step="pg_dump $db"
  pg_dump -Fc -Z zstd -d "$db" -f "$tmp/$db.dump"
  step="verify $db"   # read the whole archive back to catch truncation/corruption
  pg_restore -f /dev/null "$tmp/$db.dump"
done

step="finalize"
mv "$tmp" "/dumps/$ts"
echo "$(date -Is) db-dump wrote /dumps/$ts: $(du -sh "/dumps/$ts" | cut -f1)"

step="prune"
ls -1d /dumps/20*/ | sort -r | tail -n +"$((KEEP + 1))" | while read -r old; do
  echo "$(date -Is) pruning $old"
  rm -rf "$old"
done
