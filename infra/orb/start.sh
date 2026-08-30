#!/usr/bin/env bash
# Start Unity Catalog + Spark Thrift Server as native processes in the Orb.
# Uses PID files, log files, and readiness checks (no fragile sleeps).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Config ───────────────────────────────────────────────────────────────
UC_PORT="${UC_PORT:-8090}"
THRIFT_PORT="${THRIFT_PORT:-10000}"
UC_CATALOG="${UC_CATALOG:-prod}"

SHARE_DIR="$HOME/.local/share"
JAVA_HOME_ORB="$SHARE_DIR/java-17"
SPARK_HOME_ORB="$SHARE_DIR/spark-4.1.1"
UC_DIR="$SHARE_DIR/unitycatalog-0.5.0"

RUNTIME_DIR="$REPO_DIR/.orb-runtime"
PID_DIR="$RUNTIME_DIR/pids"
LOG_DIR="$RUNTIME_DIR/logs"
UC_STORAGE="$RUNTIME_DIR/uc-storage"
SPARK_WAREHOUSE="$RUNTIME_DIR/spark-warehouse"

# ── Helpers ──────────────────────────────────────────────────────────────
is_port_open() {
  ss -tlnp 2>/dev/null | grep -q ":$1 " && return 0 || return 1
}

wait_for_port() {
  local port="$1" name="$2" max="${3:-60}"
  for i in $(seq 1 "$max"); do
    if is_port_open "$port"; then
      echo "$name ready (port $port)"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: $name did not start on port $port within ${max}s" >&2
  return 1
}

wait_for_http() {
  local url="$1" name="$2" max="${3:-30}"
  for i in $(seq 1 "$max"); do
    if curl -sf "$url" > /dev/null 2>&1; then
      echo "$name ready"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: $name did not respond at $url within ${max}s" >&2
  return 1
}

is_pid_alive() {
  local pid_file="$1"
  [ -f "$pid_file" ] || return 1
  local pid
  pid=$(cat "$pid_file")
  kill -0 "$pid" 2>/dev/null
}

# ── Setup ────────────────────────────────────────────────────────────────
export JAVA_HOME="$JAVA_HOME_ORB"
export PATH="$JAVA_HOME/bin:$PATH"
export SPARK_HOME="$SPARK_HOME_ORB"
export SPARK_LOCAL_IP=127.0.0.1

mkdir -p "$PID_DIR" "$LOG_DIR" "$UC_STORAGE" "$SPARK_WAREHOUSE"

# ── Check if already running ─────────────────────────────────────────────
if is_pid_alive "$PID_DIR/uc.pid" && is_port_open "$UC_PORT"; then
  echo "UC server already running (PID $(cat "$PID_DIR/uc.pid"))"
else
  # Clean stale PID
  rm -f "$PID_DIR/uc.pid"

  # Check port collision
  if is_port_open "$UC_PORT"; then
    echo "ERROR: Port $UC_PORT already in use" >&2
    exit 1
  fi

  echo "Starting Unity Catalog server on port $UC_PORT..."
  # Clean H2 database for fresh start
  rm -rf "$UC_DIR/etc/db"/*
  mkdir -p "$UC_DIR/etc/db"

  cd "$UC_DIR"
  nohup bin/start-uc-server --port "$UC_PORT" \
    > "$LOG_DIR/uc.log" 2>&1 &
  SCRIPT_PID=$!
  cd "$REPO_DIR"

  wait_for_http "http://localhost:$UC_PORT/api/2.1/unity-catalog/catalogs" "UC API" 30

  # bin/start-uc-server spawns Java as a child — capture the actual Java PID
  UC_PID=$(pgrep -f "UnityCatalogServer" | head -1)
  if [ -n "$UC_PID" ]; then
    echo "$UC_PID" > "$PID_DIR/uc.pid"
  else
    echo "$SCRIPT_PID" > "$PID_DIR/uc.pid"
  fi
fi

# ── Bootstrap UC catalog + schemas ──────────────────────────────────────
echo "Bootstrapping UC catalog + schemas..."
cd "$UC_DIR"
bin/uc --server "http://localhost:$UC_PORT" \
  catalog create --name "$UC_CATALOG" \
  --storage_root "$UC_STORAGE" \
  --comment 'Main analytics catalog' 2>/dev/null || true
for schema in default analytics raw; do
  bin/uc --server "http://localhost:$UC_PORT" \
    schema create --catalog "$UC_CATALOG" --name "$schema" 2>/dev/null || true
done
cd "$REPO_DIR"

# ── Start Spark Thrift Server ───────────────────────────────────────────
if is_pid_alive "$PID_DIR/spark.pid" && is_port_open "$THRIFT_PORT"; then
  echo "Spark Thrift Server already running (PID $(cat "$PID_DIR/spark.pid"))"
else
  rm -f "$PID_DIR/spark.pid"

  if is_port_open "$THRIFT_PORT"; then
    echo "ERROR: Port $THRIFT_PORT already in use" >&2
    exit 1
  fi

  echo "Starting Spark Thrift Server on port $THRIFT_PORT..."
  "$SPARK_HOME_ORB/sbin/start-thriftserver.sh" \
    --master local[1] \
    --conf spark.sql.warehouse.dir="$SPARK_WAREHOUSE" \
    --hiveconf hive.server2.thrift.bind.host=127.0.0.1 \
    --hiveconf hive.server2.thrift.port="$THRIFT_PORT" \
    > "$LOG_DIR/spark-start.log" 2>&1

  # Thrift server runs as a daemon — find its PID
  sleep 2
  SPARK_PID=$(pgrep -f "HiveThriftServer2" | head -1)
  if [ -n "$SPARK_PID" ]; then
    echo "$SPARK_PID" > "$PID_DIR/spark.pid"
  fi

  wait_for_port "$THRIFT_PORT" "Spark Thrift Server" 60
fi

echo "Orb-native services started."
echo "  UC API:    http://localhost:$UC_PORT/api/2.1/unity-catalog/"
echo "  Thrift:    jdbc:hive2://127.0.0.1:$THRIFT_PORT"
echo "  Logs:      $LOG_DIR/"
echo "  PIDs:      $PID_DIR/"
