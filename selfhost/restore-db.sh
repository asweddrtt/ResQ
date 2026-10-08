#!/usr/bin/env bash
# Restore a Supabase dashboard backup (db_cluster-*.backup[.gz]) into the
# self-hosted database container.
#
# Usage: ./restore-db.sh /path/to/db_cluster-XX.backup.gz [db-container-name]
#
# Run it on the VPS after `docker compose up -d` has brought the stack up once.
# Errors like "already exists" are expected: the fresh self-hosted database
# already has Supabase's own schemas (auth, storage, realtime...). Your tables,
# policies, functions and the rows in auth.users / storage.objects are what we need.
set -uo pipefail

BACKUP="${1:?path to db_cluster backup file}"
DB_CONTAINER="${2:-supabase-db}"
DOCKER_DIR="${DOCKER_DIR:-$HOME/supabase/docker}"
LOG="restore-$(date +%Y%m%d-%H%M%S).log"

# shellcheck disable=SC1091
source "$DOCKER_DIR/.env"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD missing from $DOCKER_DIR/.env}"

if [[ "$BACKUP" == *.gz ]]; then reader=(gunzip -c "$BACKUP"); else reader=(cat "$BACKUP"); fi

echo "Restoring $BACKUP into $DB_CONTAINER (log: $LOG) ..."
{
  # Skip triggers/FK checks while loading rows, like pg_restore --disable-triggers.
  echo "SET session_replication_role = replica;"
  # Drop lines that would break the self-hosted stack:
  #  - role passwords from the cloud project (services log in with POSTGRES_PASSWORD)
  #  - psql 17 \restrict / \unrestrict meta-commands older psql clients reject
  "${reader[@]}" | grep -vE '^(ALTER|CREATE) ROLE .*PASSWORD|^\\(un)?restrict '
  echo "SET session_replication_role = DEFAULT;"
} | docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=0 >"$LOG" 2>&1

# Re-assert the service role passwords the self-hosted stack expects, in case the
# backup changed them anyway.
docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -v pw="$POSTGRES_PASSWORD" <<'SQL' >>"$LOG" 2>&1
ALTER USER authenticator            WITH PASSWORD :'pw';
ALTER USER pgbouncer                WITH PASSWORD :'pw';
ALTER USER supabase_auth_admin      WITH PASSWORD :'pw';
ALTER USER supabase_functions_admin WITH PASSWORD :'pw';
ALTER USER supabase_storage_admin   WITH PASSWORD :'pw';
SQL

echo
echo "Errors logged (most are harmless 'already exists'):"
grep -c "ERROR" "$LOG" || true
echo "Errors that are NOT 'already exists' / duplicate key (review these):"
grep "ERROR" "$LOG" | grep -vE 'already exists|duplicate key|multiple primary keys' | sort | uniq -c | sort -rn | head -40

echo
echo "Row counts:"
docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres -c "
  SELECT 'auth.users' AS table, count(*) FROM auth.users
  UNION ALL SELECT 'storage.objects', count(*) FROM storage.objects
  UNION ALL SELECT 'public.users', count(*) FROM public.users
  UNION ALL SELECT 'public.cases', count(*) FROM public.cases;"
echo "Realtime tables:"
docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres -c \
  "SELECT schemaname, tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';"

echo "Restarting services so they pick up the restored schema ..."
(cd "$DOCKER_DIR" && docker compose restart)
