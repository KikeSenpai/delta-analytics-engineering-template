# Spark 4.1.1 + Delta 4.3.0 base, plus pinned Unity Catalog and S3A connector jars.
#
# Jars are baked into $SPARK_HOME/jars at build time: the Spark 4.x Thrift Server
# runs queries in a per-session classloader (ArtifactManager) that does not see
# --packages jars, and baking avoids re-downloading the AWS SDK bundle on every start.
FROM deltaio/delta-docker:4.3.0

# hadoop-aws must match the image's hadoop-client 3.4.2; it pulls the matching AWS SDK v2 bundle.
ARG PACKAGES="io.delta:delta-spark_4.1_2.13:4.3.0,io.unitycatalog:unitycatalog-spark_4.1_2.13:0.5.0,io.unitycatalog:unitycatalog-client:0.5.0,org.apache.hadoop:hadoop-aws:3.4.2"

USER root
# spark-submit resolves --packages, then fails on the dummy class; only the resolved jars matter.
# Ivy names jars <group>_<artifact>-<version>.jar. Artifacts Spark already ships (jackson,
# log4j, parquet, hadoop-client, ...) are skipped so the image keeps one version of each.
RUN "$SPARK_HOME/bin/spark-submit" --packages "$PACKAGES" --conf spark.jars.ivy=/tmp/ivy \
        --class org.apache.spark.SparkEnv /dev/null > /tmp/resolve.log 2>&1 || true; \
    ls /tmp/ivy/jars/org.apache.hadoop_hadoop-aws-3.4.2.jar \
       /tmp/ivy/jars/io.unitycatalog_unitycatalog-spark_4.1_2.13-0.5.0.jar \
       || { cat /tmp/resolve.log; exit 1; }; \
    for jar in /tmp/ivy/jars/*.jar; do \
      name="${jar##*/}"; name="${name#*_}"; \
      artifact="$(echo "$name" | sed 's/-[0-9].*\.jar$//')"; \
      if ls "$SPARK_HOME/jars/$artifact"-[0-9]*.jar > /dev/null 2>&1; then echo "skip $name (bundled)"; \
      else cp "$jar" "$SPARK_HOME/jars/$name" && echo "add  $name"; fi; \
    done; \
    rm -rf /tmp/ivy /tmp/resolve.log
USER NBuser

# Run the Thrift Server in the foreground so `docker logs` shows the Spark driver log.
ENV SPARK_NO_DAEMONIZE=true SPARK_LOG_DIR=/tmp/spark-logs
ENTRYPOINT []
CMD ["/opt/spark/sbin/start-thriftserver.sh", "--master", "local[2]", \
     "--hiveconf", "hive.server2.thrift.bind.host=0.0.0.0", \
     "--hiveconf", "hive.server2.thrift.port=10000"]
