#!/usr/bin/env bash
set -e

DELTA_VERSION="${DELTA_SPARK_VERSION:-4.3.0}"
UC_VERSION="${UC_VERSION:-0.5.0}"

# Ensure log/work directories exist (delta-docker image runs as non-root NBuser)
export SPARK_LOG_DIR=/tmp/spark-logs
export SPARK_WORK_DIR=/tmp/spark-work
mkdir -p "$SPARK_LOG_DIR" "$SPARK_WORK_DIR"

# ── Phase 1: Resolve Maven packages into /tmp/jars ──────────────────────
# Spark 4.x Thrift Server uses a per-query classloader (ArtifactManager) that
# does NOT inherit --packages jars from the driver classpath.  To work around
# this, we resolve the jars first, then copy them into $SPARK_HOME/jars/ so
# they become part of the default Spark classpath that every classloader sees.
PACKAGES="io.delta:delta-spark_4.1_2.13:${DELTA_VERSION},io.unitycatalog:unitycatalog-spark_4.1_2.13:${UC_VERSION},io.unitycatalog:unitycatalog-client:${UC_VERSION}"
IVY_HOME="/tmp"  # matches spark.driver.extraJavaOptions in spark-defaults.conf
JAR_DIR="/tmp/jars"

if [ ! -d "$JAR_DIR" ] || [ -z "$(ls -A "$JAR_DIR" 2>/dev/null)" ]; then
  echo "[entrypoint] Resolving Maven packages: $PACKAGES"
  "$SPARK_HOME/bin/spark-submit" \
    --packages "$PACKAGES" \
    --master local[0] \
    --class org.apache.spark.SparkEnv \
    /dev/null 2>&1 || true   # will fail at class load — jars are already downloaded
fi

# ── Phase 2: Copy resolved jars into $SPARK_HOME/jars ───────────────────
if [ -d "$JAR_DIR" ]; then
  echo "[entrypoint] Copying $(ls "$JAR_DIR"/*.jar 2>/dev/null | wc -l) jars into SPARK_HOME/jars"
  cp -n "$JAR_DIR"/*.jar "$SPARK_HOME/jars/" 2>/dev/null || true
fi

# ── Phase 3: Start Spark Thrift Server ──────────────────────────────────
# No --packages here — jars are already on the classpath via $SPARK_HOME/jars.
"$SPARK_HOME/sbin/start-thriftserver.sh" \
  --master local[2] \
  --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
  --hiveconf hive.server2.thrift.port=10000

# Keep container alive — thrift server runs in background
sleep infinity
