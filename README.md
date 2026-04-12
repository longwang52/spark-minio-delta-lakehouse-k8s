# spark-minio-delta-lakehouse-k8s

Kubernetes rewrite of `ion-bostanica/spark-minio-delta-lakehouse-docker`.

## Components

- MinIO
- PostgreSQL
- Hive Metastore + HiveServer2
- Spark Master + 2 Workers
- Kyuubi
- MinIO bootstrap Job (`wba` bucket)

## Cluster profile (example)

Use your own values in production. The target environment used for this migration was:

- API Server: `https://cluster-endpoint:6443`
- Hosts:
  - `192.168.226.113 k8s-master-168-226-113`
  - `192.168.226.114 k8s-node1-168-226-114`
  - `192.168.226.115 k8s-node2-168-226-115`
  - `192.168.226.116 k8s-master2-168-226-116`
  - `192.168.226.120 cluster-endpoint`
  - `192.168.226.120 myharbor.com`

## Deploy

Before deployment, update default credentials in `k8s/01-secrets-configmaps.yaml`.

```bash
kubectl apply -k k8s/
```

Check status:

```bash
kubectl -n lakehouse get pods,svc,job
```

## Exposed NodePorts

- MinIO API: `30900`
- MinIO Console: `30901`
- Spark UI: `30080`
- Kyuubi JDBC: `31009`
- Kyuubi UI: `31099`

## Run sample Spark job

1. Upload `test-data/people-100.csv` to MinIO path `wba/test-data/people-100.csv`.
2. Run:

```bash
SPARK_MASTER_POD=$(kubectl -n lakehouse get pod -l app=spark-master -o jsonpath='{.items[0].metadata.name}')
kubectl -n lakehouse exec -it "$SPARK_MASTER_POD" -- /opt/bitnami/spark/bin/spark-submit /opt/spark-apps/csv_to_delta.py
```

## Cleanup

```bash
kubectl delete -k k8s/
```
