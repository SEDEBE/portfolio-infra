#!/usr/bin/env bash
# Forced command for the CI deploy key (see README). Whatever command the CI sends, this key can
# only run deploy.sh with known service names, so a leaked key can't open a shell on the server.
set -euo pipefail

allowed="landing web api worker beat"
services=()
for word in ${SSH_ORIGINAL_COMMAND:-}; do
  word="${word##*/}"        # drop any path
  word="${word//[^a-z]/}"   # drop punctuation such as ";"
  for service in $allowed; do
    if [ "$word" = "$service" ]; then
      services+=("$service")
    fi
  done
done

if [ "${#services[@]}" -eq 0 ]; then
  echo "Nothing to deploy. Allowed services: $allowed" >&2
  exit 1
fi

exec "${DEPLOY_SCRIPT:-$(dirname "$0")/../deploy.sh}" "${services[@]}"
