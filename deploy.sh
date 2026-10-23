#!/usr/bin/env bash
# Pull the latest images of the given services and restart them. Called by each repo's CI over SSH:
#   ./deploy.sh api worker beat
set -euo pipefail
cd "$(dirname "$0")"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <service>..." >&2
  exit 1
fi

docker compose pull "$@"
docker compose up -d --no-deps "$@"
docker image prune -f >/dev/null
docker compose ps "$@"
