#!/usr/bin/env bash
# Stop Unity Catalog + Spark Thrift Server.
# Kills by PID, waits, then SIGKILL if needed. No orphan processes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

SHARE_DIR="$HOME/.local/share"
SPARK_HOME_ORB="$SHARE_DIR/spark-4.1.1"
PID_DIR="$REPO_DIR/.orb-runtime/pids"
THRIFT_PORT="${THRIFT_PORT:-10000}"

export JAVA_HOME="$SHARE_DIR/java-17"
export PATH="$JAVA_HOME/bin:$PATH"
export SPARK_HOME="$SPARK_HOME_ORB"

# ── Stop Spark Thrift Server ─────────────────────────────────────────────
if [ -f "$PID_DIR/spark.pid" ]; then
  SPARK_PID=$(cat "$PID_DIR/spark.pid")
  if kill -0 "$SPARK_PID" 2>/dev/null; then
    echo "Stopping Spark Thrift Server (PID $SPARK_PID)..."
    "$SPARK_HOME_ORB/sbin/stop-thriftserver.sh" 2>/dev/null || true
    # Wait up to 10s for graceful shutdown
    for i in $(seq 1 10); do
      kill -0 "$SPARK_PID" 2>/dev/null || break
      sleep 1
    done
    # Force kill if still alive
    if kill -0 "$SPARK_PID" 2>/dev/null; then
      echo "Force killing Spark (PID $SPARK_PID)..."
      kill -9 "$SPARK_PID" 2>/dev/null || true
    fi
    echo "Spark stopped"
  else
    echo "Spark PID $SPARK_PID not running"
  fi
  rm -f "$PID_DIR/spark.pid"
else
  # Fallback: try stop-thriftserver even without PID file
  "$SPARK_HOME_ORB/sbin/stop-thriftserver.sh" 2>/dev/null || true
fi

# Also kill any orphaned Thrift server processes
pkill -f "HiveThriftServer2" 2>/dev/null || true

# ── Stop Unity Catalog ──────────────────────────────────────────────────
if [ -f "$PID_DIR/uc.pid" ]; then
  UC_PID=$(cat "$PID_DIR/uc.pid")
  if kill -0 "$UC_PID" 2>/dev/null; then
    echo "Stopping Unity Catalog (PID $UC_PID)..."
    kill "$UC_PID" 2>/dev/null || true
    for i in $(seq 1 10); do
      kill -0 "$UC_PID" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "$UC_PID" 2>/dev/null; then
      echo "Force killing UC (PID $UC_PID)..."
      kill -9 "$UC_PID" 2>/dev/null || true
    fi
    echo "UC stopped"
  else
    echo "UC PID $UC_PID not running"
  fi
  rm -f "$PID_DIR/uc.pid"
else
  echo "No UC PID file found"
fi

# Always clean up any orphaned UC processes (start-uc-server script may
# spawn Java as a child that survives killing the parent)
pkill -f "UnityCatalogServer" 2>/dev/null || true

# ── Wait for ports to be released ────────────────────────────────────────
for port in "$THRIFT_PORT" 8090; do
  for i in $(seq 1 5); do
    ss -tlnp 2>/dev/null | grep -q ":$port " || break
    sleep 1
  done
done

echo "Orb-native services stopped."
