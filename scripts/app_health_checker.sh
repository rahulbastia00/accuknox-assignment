#!/usr/bin/env bash
set -euo pipefail

# Target URL (defaults to Wisecow ingress endpoint)
TARGET_URL="${1:-https://wisecow.local}"

echo "=========================================="
echo "Checking Application Health: ${TARGET_URL}"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# Check HTTP status code (-k flag allows self-signed local certs)
HTTP_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${TARGET_URL}" || echo "000")

if [ "${HTTP_STATUS}" -eq 200 ]; then
  echo "[STATUS: UP] Application is healthy and responsive (HTTP ${HTTP_STATUS})."
  exit 0
elif [ "${HTTP_STATUS}" -eq 000 ]; then
  echo "[STATUS: DOWN] Application unreachable or connection timed out."
  exit 1
else
  echo "[STATUS: DEGRADED/DOWN] Received unexpected HTTP status: ${HTTP_STATUS}."
  exit 1
fi
