#!/usr/bin/env bash
# Dump the Postgres database to backups/ and keep the 14 most recent dumps.
# Run every night by the systemd timer in systemd/. Restore a dump with:
#   gunzip -c backups/<file>.sql.gz | docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p backups
file="backups/db-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
# The credentials are already in the db container's environment, so .env isn't parsed here.
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" --clean --if-exists "$POSTGRES_DB"' | gzip > "$file"
echo "Saved $file ($(du -h "$file" | cut -f1))"

# Keep only the 14 most recent dumps.
find backups -name 'db-*.sql.gz' -type f | sort -r | tail -n +15 | xargs -r rm --
