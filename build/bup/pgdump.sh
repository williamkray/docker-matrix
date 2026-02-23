#!/usr/bin/env bash

set -e
echo "[$(date +%c)] - starting database dump"
# make a backup using env variables for creds
pg_dumpall --verbose --clean --if-exists --username=postgres --host postgresql | gzip > "/backup/$(date +%s)_db_backup.sql.gz"

echo "[$(date +%c)] - clearing out old backups"
find /backup -mtime +7 -type f -delete

echo "$(date +%c) - backup complete"
