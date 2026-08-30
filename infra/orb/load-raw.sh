#!/usr/bin/env bash
# Load CSV files from data/ into prod.raw as Delta tables (Orb-native).
# Uses local beeline — no Docker. Backtick-quotes table identifiers so
# reserved SQL words (e.g. order) work as table names.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

SHARE_DIR="$HOME/.local/share"
SPARK_HOME_ORB="$SHARE_DIR/spark-4.1.1"
THRIFT_PORT="${THRIFT_PORT:-10000}"
RAW_DIR="$REPO_DIR/.orb-runtime/raw-data"

export JAVA_HOME="$SHARE_DIR/java-17"
export PATH="$JAVA_HOME/bin:$PATH"

BEELINE="$SPARK_HOME_ORB/bin/beeline -u jdbc:hive2://127.0.0.1:$THRIFT_PORT"

csv_files=$(ls "$REPO_DIR"/data/*.csv 2>/dev/null || true)
if [ -z "$csv_files" ]; then
  echo "No CSV files found in data/"
  echo "Place raw CSV files in the data/ directory first. See data/README.md"
  exit 1
fi

# Stage CSVs to a local directory accessible by Spark
mkdir -p "$RAW_DIR"
cp "$REPO_DIR"/data/*.csv "$RAW_DIR/"

for csv_file in $csv_files; do
  table_name=$(basename "$csv_file" .csv)
  echo "Loading $csv_file → prod.raw.$table_name"
  $BEELINE \
    -e "CREATE OR REPLACE TEMPORARY VIEW raw_csv_input USING CSV OPTIONS (path '$RAW_DIR/${table_name}.csv', header 'true', inferSchema 'true'); DROP TABLE IF EXISTS prod.raw.\`${table_name}\`; CREATE TABLE prod.raw.\`${table_name}\` USING DELTA AS SELECT * FROM raw_csv_input; DROP VIEW raw_csv_input" \
    2>&1 | tail -5
done

echo "Raw data loaded into prod.raw"
