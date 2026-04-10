#!/usr/bin/env bash
# =============================================================================
# build.sh - Build all Docker images for the Delta Lakehouse stack
#
# Usage:
#   ./build.sh [REGISTRY_PREFIX]
#
# Examples:
#   ./build.sh                        # builds images with local tags
#   ./build.sh myregistry.local:5000  # tags and pushes to private registry
#
# Prerequisites:
#   - hadoop-libs/hadoop-aws-3.1.0.jar
#   - hadoop-libs/aws-java-sdk-bundle-1.11.271.jar
# =============================================================================

set -euo pipefail

REGISTRY_PREFIX="${1:-}"
TAG_PREFIX="${REGISTRY_PREFIX:+${REGISTRY_PREFIX}/}"

# ---------------------------------------------------------------------------
# Verify required JARs exist
# ---------------------------------------------------------------------------
REQUIRED_JARS=(
    "hadoop-libs/hadoop-aws-3.1.0.jar"
    "hadoop-libs/aws-java-sdk-bundle-1.11.271.jar"
)

echo "==> Checking required JARs..."
for jar in "${REQUIRED_JARS[@]}"; do
    if [ ! -f "$jar" ]; then
        echo "ERROR: Required JAR not found: $jar"
        echo "Please place the JAR files in the hadoop-libs/ directory."
        exit 1
    fi
    echo "  OK: $jar"
done

# ---------------------------------------------------------------------------
# Build images
# ---------------------------------------------------------------------------
echo ""
echo "==> Building Docker images (build context: $(pwd))"

docker build \
    -f docker-images/hive-metastore/Dockerfile \
    -t "${TAG_PREFIX}hive-metastore:3.1.3" \
    .
echo "  Built: ${TAG_PREFIX}hive-metastore:3.1.3"

docker build \
    -f docker-images/hive-server/Dockerfile \
    -t "${TAG_PREFIX}hive-server:3.1.3" \
    .
echo "  Built: ${TAG_PREFIX}hive-server:3.1.3"

docker build \
    -f docker-images/spark-master/Dockerfile \
    -t "${TAG_PREFIX}spark-master:3.4.1" \
    .
echo "  Built: ${TAG_PREFIX}spark-master:3.4.1"

docker build \
    -f docker-images/spark-worker/Dockerfile \
    -t "${TAG_PREFIX}spark-worker:3.4.1" \
    .
echo "  Built: ${TAG_PREFIX}spark-worker:3.4.1"

docker build \
    -f docker-images/kyuubi/Dockerfile \
    -t "${TAG_PREFIX}kyuubi:1.8.0" \
    .
echo "  Built: ${TAG_PREFIX}kyuubi:1.8.0"

# ---------------------------------------------------------------------------
# Push if registry prefix provided
# ---------------------------------------------------------------------------
if [ -n "$REGISTRY_PREFIX" ]; then
    echo ""
    echo "==> Pushing images to registry: $REGISTRY_PREFIX"
    docker push "${TAG_PREFIX}hive-metastore:3.1.3"
    docker push "${TAG_PREFIX}hive-server:3.1.3"
    docker push "${TAG_PREFIX}spark-master:3.4.1"
    docker push "${TAG_PREFIX}spark-worker:3.4.1"
    docker push "${TAG_PREFIX}kyuubi:1.8.0"
fi

echo ""
echo "==> All images built successfully."
echo ""
echo "If using a private registry, update the image names in k8s/*.yaml"
echo "and set imagePullPolicy appropriately."
