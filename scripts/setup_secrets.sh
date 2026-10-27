#!/bin/bash
# Create the git-ignored secret files needed by docker-compose.yml.
# Run on the monitor host from the repo root:
#   EXPORTER_PASS=... PROM_PASS=... GRAFANA_PASS=... SLACK_URL=... ./scripts/setup_secrets.sh
set -euo pipefail

: "${EXPORTER_PASS:?set EXPORTER_PASS (node_exporter basic auth password)}"
: "${PROM_PASS:?set PROM_PASS (Prometheus admin password)}"
: "${GRAFANA_PASS:?set GRAFANA_PASS (Grafana admin password)}"
: "${SLACK_URL:?set SLACK_URL (Slack incoming webhook URL)}"

cd "$(dirname "$0")/.."

# Hash first so a missing python3-bcrypt aborts before any file is written
PROM_HASH=$(python3 hashpw.py admin "$PROM_PASS")

mkdir -p secrets
printf '%s' "$EXPORTER_PASS" > secrets/exporter_pass
printf '%s' "$PROM_PASS"     > secrets/prometheus_pass
printf '%s' "$SLACK_URL"     > secrets/slack_url
{ echo "basic_auth_users:"; echo "  $PROM_HASH"; } > prometheus/web.yml
printf 'GF_SECURITY_ADMIN_PASSWORD=%s\nPROM_WEB_PASS=%s\n' "$GRAFANA_PASS" "$PROM_PASS" > .env

# Prometheus/Alertmanager run as nobody inside the container, so mounted files must be world-readable;
# .env is only read by docker compose on the host
chmod 644 secrets/* prometheus/web.yml
chmod 600 .env

echo "Created secrets/, prometheus/web.yml and .env - next: docker compose up -d"
