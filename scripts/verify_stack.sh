#!/bin/bash
# Smoke-test the stack from your own machine (the IP allowed in monitor-sg):
#   1. PromQL: up{job="node-aws"} returns every target as 1
#   2. Grafana: the provisioned Prometheus datasource passes its health check
#   3. Security group: node_exporter :9100 on each target is NOT reachable from the Internet
# Usage:
#   PROM_PASS=... GRAFANA_PASS=... ./scripts/verify_stack.sh <monitor-public-ip> <target-public-ip>...
set -uo pipefail

: "${PROM_PASS:?set PROM_PASS (Prometheus admin password)}"
: "${GRAFANA_PASS:?set GRAFANA_PASS (Grafana admin password)}"
[ $# -ge 2 ] || { echo "usage: $0 <monitor-ip> <target-ip>..."; exit 2; }

MONITOR=$1; shift
FAIL=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAIL=1; }

# 1. PromQL
RESP=$(curl -s -m 10 -u "admin:$PROM_PASS" "http://$MONITOR:9090/api/v1/query" \
  --data-urlencode 'query=up{job="node-aws"}')
SUMMARY=$(printf '%s' "$RESP" | python3 -c '
import json, sys
r = json.load(sys.stdin)["data"]["result"]
up = [x["metric"].get("hostname", x["metric"]["instance"]) for x in r if x["value"][1] == "1"]
down = [x["metric"].get("hostname", x["metric"]["instance"]) for x in r if x["value"][1] != "1"]
print(len(r), len(down), "up=" + ",".join(up), "down=" + ",".join(down))
' 2>/dev/null) || SUMMARY=""
if [ -z "$SUMMARY" ]; then
  fail "Prometheus query failed (wrong password or 9090 not open to your IP)"
else
  read -r TOTAL DOWN DETAIL <<<"$SUMMARY"
  if [ "$TOTAL" -gt 0 ] && [ "$DOWN" -eq 0 ]; then pass "up{job=\"node-aws\"}: $TOTAL targets UP ($DETAIL)"
  else fail "up{job=\"node-aws\"}: $TOTAL targets, $DOWN down ($DETAIL)"; fi
fi

# 2. Grafana datasource
GRAFANA="http://$MONITOR:2404"
UID_=$(curl -s -m 10 -u "admin:$GRAFANA_PASS" "$GRAFANA/api/datasources/name/Prometheus" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["uid"])' 2>/dev/null)
if [ -z "$UID_" ]; then
  fail "Grafana datasource 'Prometheus' not found (wrong password or 2404 not open)"
else
  HEALTH=$(curl -s -m 15 -u "admin:$GRAFANA_PASS" "$GRAFANA/api/datasources/uid/$UID_/health")
  if printf '%s' "$HEALTH" | grep -q '"status":"OK"'; then pass "Grafana datasource Prometheus is healthy"
  else fail "Grafana datasource health: $HEALTH"; fi
fi

# 3. Port 9100 must be blocked by sg-target
for T in "$@"; do
  if curl -s -o /dev/null -m 5 "http://$T:9100/metrics"; then
    fail "$T:9100 is reachable from the Internet - check sg-target"
  else
    pass "$T:9100 blocked from the Internet"
  fi
done

exit $FAIL
