# =============================================================================
# Hive Server (HiveServer2) Dockerfile
# Base: apache/hive:3.1.3
# Build context: repo root (docker build -f docker-images/hive-server/Dockerfile .)
# =============================================================================
FROM apache/hive:3.1.3

USER root

# ---------------------------------------------------------------------------
# Copy S3A JARs (must exist in hadoop-libs/ before building)
# ---------------------------------------------------------------------------
COPY hadoop-libs/hadoop-aws-3.1.0.jar           /opt/hive/lib/
COPY hadoop-libs/aws-java-sdk-bundle-1.11.271.jar /opt/hive/lib/

# ---------------------------------------------------------------------------
# Embed hive-site.xml into the image
# ---------------------------------------------------------------------------
COPY configs/hive-site.xml /opt/hive/conf/hive-site.xml

# ---------------------------------------------------------------------------
# Run as the hive user defined in base image
# ---------------------------------------------------------------------------
USER hive

# SERVICE_NAME=hiveserver2 causes the base image entrypoint to start HiveServer2
ENV SERVICE_NAME=hiveserver2

# Thrift binary port and Web UI port
EXPOSE 10000 10002
