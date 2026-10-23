#!/usr/bin/env bash
# Run the whole portfolio on this machine, for development:
#   API (Docker Compose)        http://localhost:8000/api/docs/
#   Expense tracker app (Vite)  http://localhost:5173
#   Landing page (Vite)         http://localhost:5174
# Ctrl+C stops the app and the landing; `make stop` also stops the API containers.
# Expects the repos side by side: expense-tracker-api, expense-tracker-web, portfolio-site.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
api="$root/expense-tracker-api"
web="$root/expense-tracker-web"
site="$root/portfolio-site"

for dir in "$api" "$web" "$site"; do
  if [ ! -d "$dir" ]; then
    echo "Missing $dir: clone it next to portfolio-infra." >&2
    exit 1
  fi
done

if [ ! -f "$api/.env" ]; then
  echo "==> Creating $api/.env from .env.example"
  cp "$api/.env.example" "$api/.env"
fi

echo "==> Starting the API, worker, beat, Postgres, Redis and Mailpit"
(cd "$api" && docker compose up -d --build --wait)

for dir in "$web" "$site"; do
  # Reinstall when package-lock.json changed since the last install (e.g. after a git pull).
  if [ ! -d "$dir/node_modules" ] || [ "$dir/package-lock.json" -nt "$dir/node_modules/.package-lock.json" ]; then
    echo "==> npm ci in $(basename "$dir")"
    (cd "$dir" && npm ci --no-audit --no-fund)
  fi
done

# Stop both Vite servers when this script ends (Ctrl+C included).
trap 'trap - EXIT; kill 0' EXIT INT TERM

(cd "$web" && npm run dev -- --strictPort --clearScreen false) &
(cd "$site" && npm run dev -- --strictPort --clearScreen false) &

cat <<URLS

  Landing         http://localhost:5174
  Gastos (app)    http://localhost:5173
  API docs        http://localhost:8000/api/docs/
  Admin           http://localhost:8000/admin/
  Emails          http://localhost:8025

  Ctrl+C to stop the app and the landing; 'make stop' stops the API too.

URLS
wait
