#!/usr/bin/env bash
# Nightly backup of the self-hosted stack: full database dump + storage files.
# Keeps the last KEEP_DAYS days locally. Copy BACKUP_DIR off the server too
# (e.g. `rclone copy` to Google Drive) - a backup on the same VPS is not a backup.
#
# Install:  crontab -e  ->  30 3 * * * /home/ubuntu/ResQ/selfhost/backup.sh >> /var/log/resq-backup.log 2>&1
set -euo pipefail

DOCKER_DIR="${DOCKER_DIR:-$HOME/supabase/docker}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
DB_CONTAINER="${DB_CONTAINER:-supabase-db}"
KEEP_DAYS="${KEEP_DAYS:-14}"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"

# Roles + schema + data of every schema (auth, storage, public, ...), restorable with psql.
docker exec "$DB_CONTAINER" pg_dumpall -U supabase_admin --clean --if-exists \
  | gzip > "$BACKUP_DIR/db-$STAMP.sql.gz"

# Uploaded files (file storage backend lives in this volume).
tar -czf "$BACKUP_DIR/storage-$STAMP.tar.gz" -C "$DOCKER_DIR/volumes" storage

find "$BACKUP_DIR" -name 'db-*.sql.gz' -mtime +"$KEEP_DAYS" -delete
find "$BACKUP_DIR" -name 'storage-*.tar.gz' -mtime +"$KEEP_DAYS" -delete
echo "$(date) backup ok: $BACKUP_DIR/*-$STAMP.*"
