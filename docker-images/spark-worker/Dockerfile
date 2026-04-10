# =============================================================================
# Spark Worker Dockerfile
# Base: bitnami/spark:3.4.1
# Build context: repo root (docker build -f docker-images/spark-worker/Dockerfile .)
# =============================================================================
FROM bitnami/spark:3.4.1

USER root

# ---------------------------------------------------------------------------
# Copy S3A JARs (must exist in hadoop-libs/ before building)
# ---------------------------------------------------------------------------
COPY hadoop-libs/hadoop-aws-3.1.0.jar           /opt/bitnami/spark/jars/
COPY hadoop-libs/aws-java-sdk-bundle-1.11.271.jar /opt/bitnami/spark/jars/

# ---------------------------------------------------------------------------
# Embed configuration files into the image
# ---------------------------------------------------------------------------
COPY configs/spark-defaults.conf /opt/bitnami/spark/conf/spark-defaults.conf
COPY configs/hive-site.xml       /opt/bitnami/spark/conf/hive-site.xml

# ---------------------------------------------------------------------------
# Run as the default bitnami non-root user (1001)
# ---------------------------------------------------------------------------
USER 1001

# SPARK_MODE=worker and SPARK_MASTER_URL are handled by the bitnami entrypoint
# SPARK_MASTER_URL should be set in the k8s Deployment env vars, but
# default value is provided here for documentation purposes.
ENV SPARK_MODE=worker
ENV SPARK_MASTER_URL=spark://spark-master.lakehouse.svc.cluster.local:7077

# Worker Web UI port
EXPOSE 8081
