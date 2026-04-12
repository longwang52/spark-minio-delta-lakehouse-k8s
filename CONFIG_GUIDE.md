# 配置指南

本文档详细说明项目中各配置文件的参数含义及修改方法。

## 目录

- [MinIO 配置](#minio-配置)
- [Hive Metastore 配置](#hive-metastore-配置)
- [Spark 配置](#spark-配置)
- [Kyuubi 配置](#kyuubi-配置)
- [Kubernetes 资源配置](#kubernetes-资源配置)

---

## MinIO 配置

在以下文件中配置 MinIO 连接信息：

- `config/hive/hive-site.xml`
- `config/spark/hive-site.xml`
- `config/spark/spark-defaults.conf`

### 关键参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `fs.s3a.endpoint` | MinIO 服务地址 | `http://minio:9000` |
| `fs.s3a.access.key` | MinIO Access Key | `minioadmin` |
| `fs.s3a.secret.key` | MinIO Secret Key | `minioadmin` |
| `fs.s3a.path.style.access` | 使用路径风格访问 | `true` |

> ⚠️ **重要**：生产环境请务必修改默认的 Access Key 和 Secret Key。

---

## Hive Metastore 配置

配置文件：`config/hive/hive-site.xml`

### 数据库连接

Hive Metastore 使用 PostgreSQL 作为元数据存储。

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `javax.jdo.option.ConnectionURL` | 数据库连接 URL | `jdbc:postgresql://postgres:5432/metastore` |
| `javax.jdo.option.ConnectionUserName` | 数据库用户名 | `hive` |
| `javax.jdo.option.ConnectionPassword` | 数据库密码 | `hive123` |

> ⚠️ **重要**：生产环境请修改数据库密码，并考虑使用 Kubernetes Secret 管理。

### 仓库路径

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `hive.metastore.warehouse.dir` | 数据仓库路径 | `s3a://warehouse/` |

---

## Spark 配置

配置文件：`config/spark/spark-defaults.conf`

### Delta Lake

| 参数 | 说明 |
|------|------|
| `spark.sql.extensions` | 启用 Delta Lake SQL 扩展 |
| `spark.sql.catalog.spark_catalog` | 使用 Delta Lake Catalog |

### S3/MinIO 访问

| 参数 | 说明 |
|------|------|
| `spark.hadoop.fs.s3a.endpoint` | MinIO 服务地址 |
| `spark.hadoop.fs.s3a.access.key` | MinIO Access Key |
| `spark.hadoop.fs.s3a.secret.key` | MinIO Secret Key |

### Hive 集成

| 参数 | 说明 |
|------|------|
| `spark.sql.hive.metastore.uris` | Hive Metastore Thrift URI |
| `spark.sql.warehouse.dir` | 数据仓库路径 |

---

## Kyuubi 配置

配置文件：`config/kyuubi/kyuubi-defaults.conf`

### 运行模式

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `kyuubi.engine.type` | 引擎类型 | `SPARK_SQL` |
| `kyuubi.engine.share.level` | 引擎共享级别 | `SERVER`（资源共享）或 `USER`（隔离） |

### Spark on Kubernetes

| 参数 | 说明 |
|------|------|
| `spark.master` | Kubernetes API Server 地址 |
| `spark.kubernetes.container.image` | Spark 容器镜像 |
| `spark.kubernetes.namespace` | Kubernetes 命名空间 |

---

## Kubernetes 资源配置

### 命名空间

所有组件默认部署到 `lakehouse` 命名空间。

### 存储（PVC）

配置文件：`k8s/base/pvc.yaml`

| PVC 名称 | 用途 | 默认大小 |
|----------|------|----------|
| `spark-logs-pvc` | Spark 事件日志 | 10Gi |
| `hive-metastore-pvc` | Hive 元数据（可选本地存储） | 5Gi |

### 资源限制

根据实际工作负载调整各组件的资源配置：

**Spark Master**
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

**Spark Worker**
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

**Kyuubi**
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

---

## 使用 Kubernetes Secret 管理敏感信息

建议将密码、密钥等敏感信息存储在 Kubernetes Secret 中：

```bash
# 创建 MinIO 凭证 Secret
kubectl create secret generic minio-credentials \
  --from-literal=access-key=your-access-key \
  --from-literal=secret-key=your-secret-key \
  -n lakehouse

# 创建数据库密码 Secret
kubectl create secret generic hive-db-credentials \
  --from-literal=username=hive \
  --from-literal=password=your-secure-password \
  -n lakehouse
```

然后在部署文件中通过环境变量引用 Secret：

```yaml
env:
  - name: MINIO_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: minio-credentials
        key: access-key
```
