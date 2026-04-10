# =============================================================================
# Spark Master Dockerfile
# Base: bitnami/spark:3.4.1
# Build context: repo root (docker build -f docker-images/spark-master/Dockerfile .)
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

# SPARK_MODE=master is handled by the bitnami entrypoint
ENV SPARK_MODE=master

# Spark master port and Web UI port
EXPOSE 7077 8080
