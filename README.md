# Spark Minio Delta Lakehouse on Kubernetes

A production-ready Delta Lakehouse stack deployed on a 4-node HA Kubernetes cluster.

| Component        | Version          | Image                              |
|-----------------|------------------|------------------------------------|
| Apache Hive     | 3.1.3            | `apache/hive:3.1.3` (custom)       |
| Apache Spark    | 3.4.1            | `bitnami/spark:3.4.1` (custom)     |
| Apache Kyuubi   | 1.8.0            | `bitnami/spark:3.4.1` + kyuubi     |
| PostgreSQL      | 10               | `postgres:10`                      |
| MinIO           | pre-deployed     | `minio` namespace (`minio.minio:9000`) |

**Kubernetes Cluster**: v1.24.1 — 1 control-plane node + 1 backup control-plane node + 2 workers  
**Namespace**: `lakehouse`  
**MinIO buckets**: `warehouse` (table storage), `sparkhistory` (event logs)

---

## Directory Structure

```
.
├── build.sh                          # Helper script to build all Docker images
├── configs/
│   ├── hive-site.xml                 # Hive + S3A/MinIO + PostgreSQL config (embedded in images)
│   ├── spark-defaults.conf           # Spark cluster, S3A, Delta Lake config (embedded in images)
│   └── kyuubi-defaults.conf          # Kyuubi server + Spark engine config (embedded in image)
├── docker-images/
│   ├── hive-metastore/Dockerfile     # apache/hive:3.1.3 + S3A JARs + hive-site.xml
│   ├── hive-server/Dockerfile        # apache/hive:3.1.3 + S3A JARs + hive-site.xml
│   ├── spark-master/Dockerfile       # bitnami/spark:3.4.1 + S3A JARs + configs
│   ├── spark-worker/Dockerfile       # bitnami/spark:3.4.1 + S3A JARs + configs
│   └── kyuubi/Dockerfile             # bitnami/spark:3.4.1 + kyuubi 1.8.0 + configs
├── hadoop-libs/                      # Place JARs here before building images
│   ├── hadoop-aws-3.1.0.jar          # (you provide)
│   └── aws-java-sdk-bundle-1.11.271.jar  # (you provide)
├── k8s/
│   ├── namespace.yaml
│   ├── postgresql/
│   │   ├── statefulset.yaml          # postgres:10 StatefulSet with PVC
│   │   └── service.yaml              # ClusterIP
│   ├── hive-metastore/
│   │   ├── deployment.yaml
│   │   └── service.yaml              # ClusterIP (port 9083)
│   ├── hive-server/
│   │   ├── deployment.yaml
│   │   └── service.yaml              # NodePort 30002 (Web UI)
│   ├── spark-master/
│   │   ├── deployment.yaml
│   │   └── service.yaml              # NodePort 30080 (Web UI), ClusterIP + headless
│   ├── spark-worker/
│   │   ├── deployment.yaml           # 2 replicas with anti-affinity
│   │   └── service.yaml              # NodePort 30081 (Web UI)
│   ├── spark-history/
│   │   ├── deployment.yaml
│   │   └── service.yaml              # NodePort 30180 (Web UI)
│   └── kyuubi/
│       ├── deployment.yaml
│       └── service.yaml              # NodePort 30009 (Thrift), 30099 (REST)
├── spark-apps/
│   └── delta_lake_demo.py            # Sample Delta Lake read/write/merge demo
└── README.md
```

---

## Prerequisites

1. **Kubernetes cluster** v1.24.1 or later with `kubectl` configured.
2. **MinIO** already deployed in the `minio` namespace with:
   - Buckets created: `warehouse`, `sparkhistory`
   - Credentials: `admin` / `admin12345`
   - Service accessible as `minio.minio:9000`
3. **Docker** (or compatible runtime) available on your build machine.
4. **Private container registry** (optional) or configure k8s nodes to pull images locally.

### Required JARs

Place these JARs in `hadoop-libs/` **before** building Docker images.  
Do **not** run `mvn` or `wget` — the files are assumed to exist locally.

| JAR | Purpose |
|-----|---------|
| `hadoop-aws-3.1.0.jar` | S3A filesystem for Hadoop/Hive |
| `aws-java-sdk-bundle-1.11.271.jar` | AWS SDK (MinIO-compatible) |

### Delta Lake JARs (optional but recommended)

The `bitnami/spark:3.4.1` image does not include Delta Lake JARs.  
To enable Delta Lake features, choose **one** of:

- **Option A (recommended for air-gapped clusters)**: Place Delta JARs in `hadoop-libs/` and add `COPY` lines in the relevant Dockerfiles:
  ```
  delta-core_2.12-2.4.0.jar
  delta-storage-2.4.0.jar
  ```

- **Option B (requires internet)**: Uncomment `spark.jars.packages` in `configs/spark-defaults.conf`.

---

## Step-by-Step Deployment

### 1. Prepare JARs

```bash
# Place JARs in hadoop-libs/ (obtained from your artifact repository)
ls -la hadoop-libs/
# hadoop-aws-3.1.0.jar
# aws-java-sdk-bundle-1.11.271.jar
```

### 2. Build Docker Images

Build from the **repository root** so all Dockerfiles can access `hadoop-libs/` and `configs/`.

```bash
# Build all images (local tags)
chmod +x build.sh
./build.sh

# OR build with registry prefix and push
./build.sh myregistry.local:5000
```

Individual builds (if needed):
```bash
docker build -f docker-images/hive-metastore/Dockerfile -t hive-metastore:3.1.3 .
docker build -f docker-images/hive-server/Dockerfile    -t hive-server:3.1.3    .
docker build -f docker-images/spark-master/Dockerfile   -t spark-master:3.4.1   .
docker build -f docker-images/spark-worker/Dockerfile   -t spark-worker:3.4.1   .
docker build -f docker-images/kyuubi/Dockerfile         -t kyuubi:1.8.0         .
```

> **Using a private registry**: After building and pushing, update the `image:` field in each `k8s/*/deployment.yaml` to include your registry prefix. Also set `imagePullPolicy: Always` or configure an `imagePullSecret`.

> **Using local images (no registry)**: If your k8s nodes can access the local Docker daemon (e.g., `kind`, `minikube`, or nodes with `containerd`), load images directly:
> ```bash
> # For containerd-based clusters (each worker node):
> docker save spark-master:3.4.1 | ssh worker01 "ctr images import -"
> ```

### 3. Create Namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

### 4. Deploy PostgreSQL

```bash
kubectl apply -f k8s/postgresql/statefulset.yaml
kubectl apply -f k8s/postgresql/service.yaml

# Wait for PostgreSQL to be ready
kubectl rollout status statefulset/postgresql -n lakehouse
```

> **Storage**: By default, the PVC uses the cluster's default StorageClass.  
> Edit `k8s/postgresql/statefulset.yaml` and uncomment `storageClassName` if needed.

### 5. Deploy Hive Metastore

```bash
kubectl apply -f k8s/hive-metastore/deployment.yaml
kubectl apply -f k8s/hive-metastore/service.yaml

# Wait (includes schema init via schematool on first start — takes ~60s)
kubectl rollout status deployment/hive-metastore -n lakehouse
```

### 6. Deploy HiveServer2

```bash
kubectl apply -f k8s/hive-server/deployment.yaml
kubectl apply -f k8s/hive-server/service.yaml
kubectl rollout status deployment/hive-server -n lakehouse
```

### 7. Deploy Spark Master

```bash
kubectl apply -f k8s/spark-master/deployment.yaml
kubectl apply -f k8s/spark-master/service.yaml
kubectl rollout status deployment/spark-master -n lakehouse
```

### 8. Deploy Spark Workers (2 replicas)

```bash
kubectl apply -f k8s/spark-worker/deployment.yaml
kubectl apply -f k8s/spark-worker/service.yaml
kubectl rollout status deployment/spark-worker -n lakehouse
```

### 9. Deploy Spark History Server

```bash
kubectl apply -f k8s/spark-history/deployment.yaml
kubectl apply -f k8s/spark-history/service.yaml
```

### 10. Deploy Kyuubi

```bash
kubectl apply -f k8s/kyuubi/deployment.yaml
kubectl apply -f k8s/kyuubi/service.yaml
kubectl rollout status deployment/kyuubi -n lakehouse
```

### Deploy Everything at Once

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgresql/
kubectl rollout status statefulset/postgresql -n lakehouse
kubectl apply -f k8s/hive-metastore/
kubectl rollout status deployment/hive-metastore -n lakehouse
kubectl apply -f k8s/hive-server/
kubectl apply -f k8s/spark-master/
kubectl apply -f k8s/spark-worker/
kubectl apply -f k8s/spark-history/
kubectl apply -f k8s/kyuubi/
```

---

## Verification

```bash
# Check all pods are Running
kubectl get pods -n lakehouse

# Expected output (all Running):
# NAME                              READY   STATUS    RESTARTS   AGE
# postgresql-0                      1/1     Running   0          5m
# hive-metastore-xxxxx-xxxxx        1/1     Running   0          4m
# hive-server-xxxxx-xxxxx           1/1     Running   0          3m
# spark-master-xxxxx-xxxxx          1/1     Running   0          3m
# spark-worker-xxxxx-xxxxx          1/1     Running   0          2m
# spark-worker-xxxxx-yyyyy          1/1     Running   0          2m
# spark-history-xxxxx-xxxxx         1/1     Running   0          2m
# kyuubi-xxxxx-xxxxx                1/1     Running   0          1m
```

---

## Web UIs (NodePort Access)

Replace `<NODE_IP>` with any worker node IP (e.g., `192.168.226.113`).

| Service               | URL                            | NodePort |
|-----------------------|--------------------------------|----------|
| Spark Master UI       | `http://<NODE_IP>:30080`       | 30080    |
| Spark Worker UI       | `http://<NODE_IP>:30081`       | 30081    |
| Spark History Server  | `http://<NODE_IP>:30180`       | 30180    |
| HiveServer2 Web UI    | `http://<NODE_IP>:30002`       | 30002    |
| HiveServer2 Thrift    | `<NODE_IP>:30000`              | 30000    |
| Kyuubi REST API       | `http://<NODE_IP>:30099`       | 30099    |

---

## Connecting via Beeline (JDBC)

```bash
# Connect to HiveServer2 (NodePort 30000 maps to Thrift port 10000)
beeline -u "jdbc:hive2://<NODE_IP>:30000/"

# Connect to Kyuubi (Thrift NodePort 30009)
beeline -u "jdbc:hive2://<NODE_IP>:30009/"
```

---

## Running the Demo Application

Copy the demo script to a Spark pod and submit:

```bash
# Copy to spark-master pod
kubectl cp spark-apps/delta_lake_demo.py \
    lakehouse/$(kubectl get pod -n lakehouse -l app=spark-master -o jsonpath='{.items[0].metadata.name}'):/tmp/

# Submit the job
kubectl exec -n lakehouse \
    $(kubectl get pod -n lakehouse -l app=spark-master -o jsonpath='{.items[0].metadata.name}') -- \
    /opt/bitnami/spark/bin/spark-submit \
    --master spark://spark-master.lakehouse.svc.cluster.local:7077 \
    /tmp/delta_lake_demo.py
```

---

## Service DNS (Internal)

| Service               | DNS                                                   | Port  |
|-----------------------|-------------------------------------------------------|-------|
| PostgreSQL            | `postgresql.lakehouse.svc.cluster.local`              | 5432  |
| Hive Metastore        | `hive-metastore.lakehouse.svc.cluster.local`          | 9083  |
| HiveServer2           | `hive-server.lakehouse.svc.cluster.local`             | 10000 |
| Spark Master          | `spark-master.lakehouse.svc.cluster.local`            | 7077  |
| MinIO (ext namespace) | `minio.minio`                                         | 9000  |

---

## Configuration Reference

All configuration is embedded in Docker images at build time.

| File | Location in Image | Embedded In |
|------|--------------------|-------------|
| `configs/hive-site.xml` | `/opt/hive/conf/hive-site.xml` | hive-metastore, hive-server |
| `configs/hive-site.xml` | `/opt/bitnami/spark/conf/hive-site.xml` | spark-master, spark-worker, kyuubi |
| `configs/spark-defaults.conf` | `/opt/bitnami/spark/conf/spark-defaults.conf` | spark-master, spark-worker, kyuubi |
| `configs/kyuubi-defaults.conf` | `/opt/kyuubi/conf/kyuubi-defaults.conf` | kyuubi |

To change configuration, edit the relevant file in `configs/`, rebuild the affected image(s), and redeploy.

---

## Teardown

```bash
# Delete all resources in the lakehouse namespace
kubectl delete namespace lakehouse
```

---

## Troubleshooting

**Hive Metastore fails to start**:
```bash
kubectl logs -n lakehouse deployment/hive-metastore
# Check PostgreSQL connectivity and schema initialization
```

**Spark worker not connecting to master**:
```bash
kubectl logs -n lakehouse deployment/spark-worker
# Verify spark-master service is reachable
kubectl exec -n lakehouse deployment/spark-worker -- \
    nc -zv spark-master.lakehouse.svc.cluster.local 7077
```

**S3A / MinIO access errors**:
```bash
# Verify MinIO is reachable from lakehouse namespace
kubectl exec -n lakehouse deployment/spark-master -- \
    curl -I http://minio.minio:9000/minio/health/live
```

**PVC not binding**:
```bash
kubectl get pvc -n lakehouse
kubectl describe pvc postgresql-data-postgresql-0 -n lakehouse
# Ensure a default StorageClass is configured, or set storageClassName in statefulset.yaml
```