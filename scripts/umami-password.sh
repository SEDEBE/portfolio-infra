#!/usr/bin/env bash
# Set the password of Umami's "admin" user. Umami starts with admin / umami, so run this before
# the dashboard is reachable from the internet. The password is never echoed, passed as an
# argument or stored in plain text: Caddy turns it into a bcrypt hash, which goes to the database.
set -euo pipefail
cd "$(dirname "$0")/.."

read -rsp "New Umami password for admin: " password; echo
read -rsp "Repeat it: " again; echo
[ "$password" = "$again" ] || { echo "They don't match." >&2; exit 1; }
[ "${#password}" -ge 12 ] || { echo "Use at least 12 characters." >&2; exit 1; }

hash=$(printf '%s\n%s\n' "$password" "$password" | docker compose exec -T caddy caddy hash-password | tail -n 1)
unset password again

# psql only expands :'hash' when the SQL comes from stdin, not from -c.
echo "UPDATE \"user\" SET password = :'hash' WHERE username = 'admin';" |
  docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d umami -v ON_ERROR_STOP=1 -v hash="$1"' sh "$hash"
