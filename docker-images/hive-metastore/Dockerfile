# =============================================================================
# Hive Metastore Dockerfile
# Base: apache/hive:3.1.3
# Build context: repo root (docker build -f docker-images/hive-metastore/Dockerfile .)
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

# SERVICE_NAME=metastore causes the base image entrypoint to:
#   1. Run schematool -initSchema (idempotent)
#   2. Start the Thrift metastore on port 9083
ENV SERVICE_NAME=metastore

EXPOSE 9083
