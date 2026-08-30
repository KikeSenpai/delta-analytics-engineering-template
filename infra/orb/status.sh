#!/usr/bin/env bash
# Health check for Orb-native services.
# Exits 0 if all healthy, 1 otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

UC_PORT="${UC_PORT:-8090}"
THRIFT_PORT="${THRIFT_PORT:-10000}"
PID_DIR="$REPO_DIR/.orb-runtime/pids"

HEALTHY=true

# ── Unity Catalog ───────────────────────────────────────────────────────
echo "── Unity Catalog (port $UC_PORT) ──"
if curl -sf "http://localhost:$UC_PORT/api/2.1/unity-catalog/catalogs" > /dev/null 2>&1; then
  echo "  UC API: healthy"
  curl -sf "http://localhost:$UC_PORT/api/2.1/unity-catalog/catalogs" 2>&1 | head -c 200
  echo
else
  echo "  UC API: NOT responding"
  HEALTHY=false
fi

if [ -f "$PID_DIR/uc.pid" ]; then
  UC_PID=$(cat "$PID_DIR/uc.pid")
  if kill -0 "$UC_PID" 2>/dev/null; then
    echo "  UC PID: $UC_PID (running)"
  else
    echo "  UC PID: $UC_PID (DEAD)"
    HEALTHY=false
  fi
else
  echo "  UC PID: not recorded"
fi

# ── Spark Thrift Server ─────────────────────────────────────────────────
echo "── Spark Thrift Server (port $THRIFT_PORT) ──"
if ss -tlnp 2>/dev/null | grep -q ":$THRIFT_PORT "; then
  echo "  Thrift port: listening"
else
  echo "  Thrift port: NOT listening"
  HEALTHY=false
fi

if [ -f "$PID_DIR/spark.pid" ]; then
  SPARK_PID=$(cat "$PID_DIR/spark.pid")
  if kill -0 "$SPARK_PID" 2>/dev/null; then
    echo "  Spark PID: $SPARK_PID (running)"
  else
    echo "  Spark PID: $SPARK_PID (DEAD)"
    HEALTHY=false
  fi
else
  echo "  Spark PID: not recorded"
fi

if [ "$HEALTHY" = true ]; then
  echo "── All services healthy ──"
  exit 0
else
  echo "── Some services unhealthy ──"
  exit 1
fi
