#!/bin/sh

OUT="/volume2/docker/golem/dashboard/data/status.json"
CONTAINER="golem-provider"

ESC="$(printf '\033')"

STATUS="$(docker exec "$CONTAINER" golemsp status 2>/dev/null | sed "s/${ESC}\[[0-9;]*[A-Za-z]//g" | tr '│' ' ')"
SETTINGS="$(docker exec "$CONTAINER" golemsp settings show 2>/dev/null | sed "s/${ESC}\[[0-9;]*[A-Za-z]//g" | tr '│' ' ')"

SERVICE="$(echo "$STATUS" | grep -o 'Service[[:space:]]*is running' | head -1 | sed 's/Service[[:space:]]*//')"
NETWORK="$(echo "$STATUS" | grep -o 'network[[:space:]]*[A-Za-z0-9_-]*' | head -1 | awk '{print $2}')"
VM="$(echo "$STATUS" | grep -o 'VM[[:space:]]*[A-Za-z]*' | head -1 | awk '{print $2}')"
DRIVER="$(echo "$STATUS" | grep -o 'Driver[[:space:]]*[A-Za-z]*' | head -1 | awk '{print $2}')"

LAST1H="$(echo "$STATUS" | sed -n 's/.*last 1h processed[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)"
INPROGRESS="$(echo "$STATUS" | sed -n 's/.*last 1h in progress[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)"
TOTALJOBS="$(echo "$STATUS" | sed -n 's/.*total processed[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)"

TOTAL_GLM="$(echo "$STATUS" | sed -n 's/.*amount (total)[[:space:]]*\([0-9.][0-9.]*\).*/\1/p' | head -1)"
PENDING_GLM="$(echo "$STATUS" | sed -n 's/.*pending[[:space:]]*\([0-9.][0-9.]*\)[[:space:]]*GLM.*/\1/p' | head -1)"
ISSUED_GLM="$(echo "$STATUS" | sed -n 's/.*issued[[:space:]]*\([0-9.][0-9.]*\)[[:space:]]*GLM.*/\1/p' | head -1)"

CORES="$(echo "$SETTINGS" | grep "cores:" | head -1 | awk '{print $2}')"
MEMORY="$(echo "$SETTINGS" | grep "memory:" | head -1 | awk '{print $2}')"
DISK="$(echo "$SETTINGS" | grep "disk:" | head -1 | awk '{print $2}')"

CPU_PRICE="$(echo "$SETTINGS" | grep "GLM per cpu hour" | head -1 | awk '{print $1}')"
HOUR_PRICE="$(echo "$SETTINGS" | grep "GLM per hour" | head -1 | awk '{print $1}')"

PROFILE="UNKNOWN"

if [ "$CORES" = "2" ]; then
    PROFILE="DAY"
fi

if [ "$CORES" = "3" ]; then
    PROFILE="NIGHT"
fi

cat > "$OUT" <<EOF
{
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "service": "$SERVICE",
  "network": "$NETWORK",
  "vm": "$VM",
  "driver": "$DRIVER",
  "profile": "$PROFILE",
  "cores": "$CORES",
  "memory": "$MEMORY",
  "disk": "$DISK",
  "jobs_last_hour": "$LAST1H",
  "jobs_in_progress": "$INPROGRESS",
  "jobs_total": "$TOTALJOBS",
  "glm_total": "$TOTAL_GLM",
  "glm_pending": "$PENDING_GLM",
  "glm_issued": "$ISSUED_GLM",
  "cpu_price": "$CPU_PRICE",
  "hour_price": "$HOUR_PRICE"
}
EOF