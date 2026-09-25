#!/usr/bin/env bash
set -euo pipefail

# Threshold limits (%)
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=85

LOG_FILE="/tmp/system_health.log"

log_alert() {
  local message="$1"
  echo "[ALERT $(date '+%Y-%m-%d %H:%M:%S')] ${message}" | tee -a "${LOG_FILE}"
}

echo "=== System Health Check: $(date '+%Y-%m-%d %H:%M:%S') ==="

# 1. CPU Usage Check
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1)
CPU_USAGE=$((100 - CPU_IDLE))
if [ "${CPU_USAGE}" -gt "${CPU_THRESHOLD}" ]; then
  log_alert "High CPU usage detected: ${CPU_USAGE}% (Threshold: ${CPU_THRESHOLD}%)"
else
  echo "[OK] CPU Usage: ${CPU_USAGE}%"
fi

# 2. Memory Usage Check
MEM_USAGE=$(free | grep Mem | awk '{printf("%.0f"), $3/$2 * 100}')
if [ "${MEM_USAGE}" -gt "${MEM_THRESHOLD}" ]; then
  log_alert "High Memory usage detected: ${MEM_USAGE}% (Threshold: ${MEM_THRESHOLD}%)"
else
  echo "[OK] Memory Usage: ${MEM_USAGE}%"
fi

# 3. Disk Usage Check (Root Partition)
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "${DISK_USAGE}" -gt "${DISK_THRESHOLD}" ]; then
  log_alert "High Disk usage detected on /: ${DISK_USAGE}% (Threshold: ${DISK_THRESHOLD}%)"
else
  echo "[OK] Disk Usage: ${DISK_USAGE}%"
fi

# 4. Top Running Processes
echo "--- Top 5 CPU Consuming Processes ---"
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 6
