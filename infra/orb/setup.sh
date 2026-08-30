#!/usr/bin/env bash
# Install all dependencies for Orb-native Spark + Delta + Unity Catalog execution.
# Idempotent: skips steps already completed. Cached in ~/.local/share/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Versions (pinned, must match docker-compose.yml) ────────────────────
JAVA_VERSION="17"
SPARK_VERSION="4.1.1"
DELTA_VERSION="4.3.0"
UC_VERSION="0.5.0"

# ── Directories ──────────────────────────────────────────────────────────
SHARE_DIR="$HOME/.local/share"
JAVA_HOME_ORB="$SHARE_DIR/java-$JAVA_VERSION"
SPARK_HOME_ORB="$SHARE_DIR/spark-$SPARK_VERSION"
UC_DIR="$SHARE_DIR/unitycatalog-$UC_VERSION"

echo "=== Orb-native setup: $(date) ==="

# ── 1. Java 17 (Temurin) ────────────────────────────────────────────────
if [ ! -f "$JAVA_HOME_ORB/bin/java" ]; then
  echo "Installing Temurin JDK $JAVA_VERSION..."
  curl -sL "https://api.adoptium.net/v3/binary/latest/${JAVA_VERSION}/ga/linux/x64/jdk/hotspot/normal/eclipse" \
    -o /tmp/jdk${JAVA_VERSION}.tar.gz
  mkdir -p "$JAVA_HOME_ORB"
  tar -xzf /tmp/jdk${JAVA_VERSION}.tar.gz -C "$JAVA_HOME_ORB" --strip-components=1
  rm -f /tmp/jdk${JAVA_VERSION}.tar.gz
else
  echo "Java $JAVA_VERSION already installed"
fi

export JAVA_HOME="$JAVA_HOME_ORB"
export PATH="$JAVA_HOME/bin:$PATH"

# ── 2. Spark ────────────────────────────────────────────────────────────
if [ ! -f "$SPARK_HOME_ORB/bin/spark-submit" ]; then
  echo "Downloading Spark $SPARK_VERSION..."
  curl -sL "https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop3.tgz" \
    -o /tmp/spark.tgz
  mkdir -p "$SPARK_HOME_ORB"
  tar -xzf /tmp/spark.tgz -C "$SPARK_HOME_ORB" --strip-components=1
  rm -f /tmp/spark.tgz
else
  echo "Spark $SPARK_VERSION already installed"
fi

# ── 3. Unity Catalog (build from source) ────────────────────────────────
if [ ! -f "$UC_DIR/server/target/unitycatalog-server-$UC_VERSION.jar" ]; then
  echo "Building Unity Catalog v$UC_VERSION from source..."
  rm -rf /tmp/uc-build
  git clone --depth 1 --branch "v$UC_VERSION" \
    https://github.com/unitycatalog/unitycatalog.git /tmp/uc-build
  (cd /tmp/uc-build && build/sbt -info clean package)
  rm -rf "$UC_DIR"
  mv /tmp/uc-build "$UC_DIR"
  # Fix classpath paths from /tmp/uc-build to permanent location
  find "$UC_DIR" -name "classpath" -exec sed -i "s|/tmp/uc-build|$UC_DIR|g" {} \;
else
  echo "Unity Catalog v$UC_VERSION already built"
fi

# ── 4. Resolve Maven jars into Spark classpath ──────────────────────────
# Delta + UC connector jars must be on $SPARK_HOME/jars for Thrift Server
# classloader (same workaround as Docker entrypoint.sh).
UC_SPARK_JAR="$SPARK_HOME_ORB/jars/io.unitycatalog_unitycatalog-spark_4.1_2.13-$UC_VERSION.jar"
if [ ! -f "$UC_SPARK_JAR" ]; then
  echo "Resolving Maven packages (Delta + UC connector)..."
  PACKAGES="io.delta:delta-spark_4.1_2.13:${DELTA_VERSION},io.unitycatalog:unitycatalog-spark_4.1_2.13:${UC_VERSION},io.unitycatalog:unitycatalog-client:${UC_VERSION}"
  "$SPARK_HOME_ORB/bin/spark-submit" \
    --packages "$PACKAGES" \
    --master local[0] \
    --class org.apache.spark.SparkEnv \
    /dev/null 2>&1 || true   # fails at class load — jars already downloaded

  IVY_JARS="$HOME/.ivy2.5.2/jars"
  if [ -d "$IVY_JARS" ]; then
    cp -n "$IVY_JARS"/*.jar "$SPARK_HOME_ORB/jars/" 2>/dev/null || true
  fi
  echo "Maven jars resolved"
else
  echo "Maven jars already present"
fi

# ── 5. Install Spark config for orb ─────────────────────────────────────
cp "$SCRIPT_DIR/spark-defaults.conf" "$SPARK_HOME_ORB/conf/spark-defaults.conf"

# ── 6. Python dependencies (uv sync) ────────────────────────────────────
echo "Syncing Python dependencies..."
cd "$REPO_DIR"
export PATH="$HOME/.local/bin:$PATH"
uv sync

# ── 7. Env file ─────────────────────────────────────────────────────────
if [ -f ".env.example" ] && [ ! -f ".env.local" ]; then
  cp .env.example .env.local
fi

echo "=== Orb-native setup complete: $(date) ==="
