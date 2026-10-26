#!/usr/bin/env bash
# Dump the Postgres databases to backups/ and keep the 14 most recent dumps of each.
# Run every night by the systemd timer in systemd/. Restore a dump with:
#   gunzip -c backups/<file>.sql.gz | docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
set -euo pipefail
cd "$(dirname "$0")/.."

# The dumps hold every user's data: only the owner may read them. umask covers the new files;
# chmod fixes the folder and any dump made before this line existed.
umask 077
mkdir -p backups
chmod -R go= backups
file="backups/db-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
# The credentials are already in the db container's environment, so .env isn't parsed here.
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" --clean --if-exists "$POSTGRES_DB"' | gzip > "$file"
echo "Saved $file ($(du -h "$file" | cut -f1))"

# The visit statistics are a separate database in the same server.
if docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -lqt' | cut -d'|' -f1 | grep -qw umami; then
  stats="backups/umami-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
  docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" --clean --if-exists umami' | gzip > "$stats"
  echo "Saved $stats ($(du -h "$stats" | cut -f1))"
fi

# Keep only the 14 most recent dumps.
for prefix in db umami; do
  find backups -name "$prefix-*.sql.gz" -type f | sort -r | tail -n +15 | xargs -r rm --
done
