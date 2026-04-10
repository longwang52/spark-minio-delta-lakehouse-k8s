# Spark Minio Delta Lakehouse K8s Project Structure

This project implements a Delta Lakehouse architecture using Apache Spark, Minio for object storage, and Kubernetes for orchestration.

## Directory Structure
```
/.
├── docker
│   ├── spark
│   │   └── Dockerfile
│   └── minio
│       └── Dockerfile
├── kubernetes
│   ├── deployment
│   │   └── spark-deployment.yaml
│   ├── service
│   │   └── minio-service.yaml
│   └── config
│       └── minio-config.yaml
└── scripts
    ├── start-spark.sh
    └── stop-spark.sh
```

## Dockerfiles
- **`docker/spark/Dockerfile`**: Dockerfile for building the Spark container.
- **`docker/minio/Dockerfile`**: Dockerfile for building the Minio container.

## Kubernetes Manifests
- **`kubernetes/deployment/spark-deployment.yaml`**: Deployment manifest for Spark.
- **`kubernetes/service/minio-service.yaml`**: Service manifest for Minio.
- **`kubernetes/config/minio-config.yaml`**: Config map for Minio.

## Scripts
- **`scripts/start-spark.sh`**: Script to start the Spark application.
- **`scripts/stop-spark.sh`**: Script to stop the Spark application.