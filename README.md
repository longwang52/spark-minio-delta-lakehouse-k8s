# spark-minio-delta-lakehouse-k8s

将 `ion-bostanica/spark-minio-delta-lakehouse-docker` 改写为 Kubernetes 部署版本，覆盖以下组件：

- MinIO（对象存储）
- PostgreSQL（Hive Metastore 元数据库）
- Hive Metastore + HiveServer2
- Spark Master + 2 Worker
- Kyuubi（SQL Gateway）
- MinIO bucket 初始化 Job（自动创建 `wba`）

## 集群信息

- API Server: `https://cluster-endpoint:6443`
- 集群 VIP: `192.168.226.120`
- Hosts:
  - `192.168.226.113 k8s-master-168-226-113`
  - `192.168.226.114 k8s-node1-168-226-114`
  - `192.168.226.115 k8s-node2-168-226-115`
  - `192.168.226.116 k8s-master2-168-226-116`
  - `192.168.226.120 cluster-endpoint`
  - `192.168.226.120 myharbor.com`

## 目录结构

- `k8s/00-namespace.yaml`
- `k8s/01-secrets-configmaps.yaml`
- `k8s/02-storage.yaml`
- `k8s/03-minio.yaml`
- `k8s/04-postgres.yaml`
- `k8s/05-hive.yaml`
- `k8s/06-spark.yaml`
- `k8s/07-kyuubi.yaml`
- `k8s/kustomization.yaml`

## 部署

```bash
kubectl apply -k k8s/
```

检查状态：

```bash
kubectl -n lakehouse get pods
kubectl -n lakehouse get svc
kubectl -n lakehouse get job
```

## 访问入口

默认开放了 NodePort：

- MinIO S3 API: `30900`
- MinIO Console: `30901`
- Spark Master UI: `30080`
- Kyuubi JDBC: `31009`
- Kyuubi UI: `31099`

示例（MinIO 控制台）：

- `http://<任意节点IP>:30901`
- 用户名：`accesskey`
- 密码：`secretkey`

## 运行 Spark 示例任务

先上传测试文件到 MinIO：

- bucket: `wba`
- object: `test-data/people-100.csv`

在 Spark Master Pod 里执行：

```bash
SPARK_MASTER_POD=$(kubectl -n lakehouse get pod -l app=spark-master -o jsonpath='{.items[0].metadata.name}')
kubectl -n lakehouse exec -it "$SPARK_MASTER_POD" -- /opt/bitnami/spark/bin/spark-submit /opt/spark-apps/csv_to_delta.py
```

## 清理

```bash
kubectl delete -k k8s/
```

如需保留 PVC 数据，请先编辑 `k8s/02-storage.yaml` 对应资源策略后再清理。
