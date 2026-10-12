#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
umask 077
mkdir -p .secrets
chmod 700 .secrets
if [[ -f .secrets/grafana-admin-password ]]; then
  echo 'Password file already exists; leaving it unchanged.'
  exit 0
fi
read -r -s -p 'New Grafana admin password (at least 12 characters): ' stream_password
printf '\n'
if [[ ${#stream_password} -lt 12 ]]; then
  echo 'Choose a password of at least 12 characters.' >&2
  exit 1
fi
printf '%s' "$stream_password" > .secrets/grafana-admin-password
# Compose file secrets use a read-only bind mount. The Grafana container UID
# must be able to read this file; the host directory stays private (0700).
chmod 644 .secrets/grafana-admin-password
unset stream_password
echo 'Password file created. Start Grafana with sudo docker compose up -d.'
