# =============================================================================
# Apache Kyuubi Dockerfile
# Kyuubi 1.8.0 installed on top of bitnami/spark:3.4.1
# Build context: repo root (docker build -f docker-images/kyuubi/Dockerfile .)
# =============================================================================
FROM bitnami/spark:3.4.1

USER root

# ---------------------------------------------------------------------------
# Install system dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget procps && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Download and install Apache Kyuubi 1.8.0
# ---------------------------------------------------------------------------
ARG KYUUBI_VERSION=1.8.0
ARG KYUUBI_DIST=apache-kyuubi-${KYUUBI_VERSION}-bin

RUN wget -q \
    "https://archive.apache.org/dist/kyuubi/kyuubi-${KYUUBI_VERSION}/${KYUUBI_DIST}.tgz" \
    -O /tmp/kyuubi.tgz && \
    tar -xzf /tmp/kyuubi.tgz -C /opt && \
    ln -s /opt/${KYUUBI_DIST} /opt/kyuubi && \
    rm /tmp/kyuubi.tgz

ENV KYUUBI_HOME=/opt/kyuubi
ENV SPARK_HOME=/opt/bitnami/spark

# ---------------------------------------------------------------------------
# Copy S3A JARs into Spark jars directory
# (must exist in hadoop-libs/ before building)
# ---------------------------------------------------------------------------
COPY hadoop-libs/hadoop-aws-3.1.0.jar           /opt/bitnami/spark/jars/
COPY hadoop-libs/aws-java-sdk-bundle-1.11.271.jar /opt/bitnami/spark/jars/

# ---------------------------------------------------------------------------
# Embed configuration files into the image
# ---------------------------------------------------------------------------
COPY configs/kyuubi-defaults.conf /opt/kyuubi/conf/kyuubi-defaults.conf
COPY configs/hive-site.xml        /opt/kyuubi/conf/hive-site.xml
COPY configs/spark-defaults.conf  /opt/bitnami/spark/conf/spark-defaults.conf
COPY configs/hive-site.xml        /opt/bitnami/spark/conf/hive-site.xml

# ---------------------------------------------------------------------------
# Fix permissions
# ---------------------------------------------------------------------------
RUN chown -R 1001:1001 /opt/kyuubi /opt/bitnami/spark/conf

USER 1001

# Thrift binary port and REST API port
EXPOSE 10009 10099 4040

CMD ["/opt/kyuubi/bin/kyuubi", "run"]
