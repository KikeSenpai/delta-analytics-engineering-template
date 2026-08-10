#!/usr/bin/env bash
set -e

DELTA_VERSION="${DELTA_SPARK_VERSION:-4.1.0}"

# Start Spark Thrift Server with Delta Lake support
# Delta jars are fetched from Maven via --packages on first run (cached after)
"$SPARK_HOME/sbin/start-thriftserver.sh" \
  --packages "io.delta:delta-spark_2.13:${DELTA_VERSION}" \
  --master local[2] \
  --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
  --hiveconf hive.server2.thrift.port=10000

# Keep container alive — thrift server runs in background
sleep infinity
