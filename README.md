# Spark + MinIO + Delta Lake + Hive + Kyuubi on Kubernetes

## 项目概述

本项目将 [ion-bostanica/spark-minio-delta-lakehouse-docker](https://github.com/ion-bostanica/spark-minio-delta-lakehouse-docker) Docker Compose 项目改写为完整的 Kubernetes 集群部署方案，构建一个基于 Apache Spark + MinIO + Delta Lake + Hive + Kyuubi 的云原生 Data Lakehouse 平台。

## 集群环境

| 项目 | 内容 |
|------|------|
| K8s 版本 | v1.24.1 |
| 容器运行时 | containerd 1.6.33 |
| 存储类 | nfs-client（默认，支持动态供应） |
| VIP | 192.168.226.120 |
| Harbor | myharbor.com/bigdata |

## 组件版本

| 组件 | 版本 | 镜像 |
|------|------|------|
| Apache Spark | 3.4.1 | myharbor.com/bigdata/bitnami/spark:3.4.1 |
| Apache Hive | 3.1.3 | myharbor.com/bigdata/apache/hive:3.1.3 |
| Apache Kyuubi | 1.8.0 | myharbor.com/bigdata/apache/kyuubi:1.8.0-spark |
| Delta Lake | 2.4.0 | JAR 包方式 |
| MinIO | 已部署 | minio 命名空间（4副本 StatefulSet） |
| MySQL | 5.7 | bigdata 命名空间 |

## 部署架构

```
lakehouse 命名空间
├── hive-metastore     ──→ MySQL (bigdata ns) :3306
├── hive-server2       ──→ hive-metastore :9083
├── spark-master       ──→ MinIO sparkhistory bucket (History Server)
├── spark-worker-1     ──→ spark-master :7077
├── spark-worker-2     ──→ spark-master :7077
└── kyuubi             ──→ spark-master :7077, hive-metastore :9083
```

## 目录结构

```
lakehouse/
├── hadoop-libs/       # 依赖 JAR 包（通过 PVC 挂载）
│   ├── hive/
│   ├── spark/
│   ├── kyuubi/
│   └── mysql/
├── config/            # 配置文件（源文件，ConfigMap 引用）
│   ├── hive/hive-site.xml
│   ├── spark/spark-defaults.conf
│   └── kyuubi/kyuubi-defaults.conf
├── k8s/               # Kubernetes 部署文件
│   ├── 00-namespace.yaml
│   ├── base/          # PVC、Headless Service
│   ├── hive/          # Hive ConfigMap + MetaStore + Server2
│   ├── spark/         # Spark ConfigMap + Master + Workers
│   └── kyuubi/        # Kyuubi ConfigMap + Deployment
└── scripts/
    ├── deploy.sh      # 部署脚本
    ├── uninstall.sh   # 卸载脚本
    └── push_images.sh # 镜像推送脚本
```

## 快速开始

### 1. 准备 JAR 包

```bash
cd lakehouse/hadoop-libs

# Delta Lake
wget https://repo1.maven.org/maven2/io/delta/delta-core_2.12/2.4.0/delta-core_2.12-2.4.0.jar -P spark/
wget https://repo1.maven.org/maven2/io/delta/delta-storage/2.4.0/delta-storage-2.4.0.jar -P spark/

# Hadoop AWS
wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.6/hadoop-aws-3.3.6.jar -P spark/
cp spark/hadoop-aws-3.3.6.jar hive/

# AWS SDK
wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.271/aws-java-sdk-bundle-1.11.271.jar -P spark/
cp spark/aws-java-sdk-bundle-1.11.271.jar hive/

# MySQL JDBC
wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar -P mysql/

# Kyuubi
wget https://repo1.maven.org/maven2/org/apache/kyuubi/kyuubi-spark-connector-hive_2.12/1.8.0/kyuubi-spark-connector-hive_2.12-1.8.0.jar -P kyuubi/
wget https://repo1.maven.org/maven2/org/apache/kyuubi/kyuubi-extension-spark-3-4_2.12/1.8.0/kyuubi-extension-spark-3-4_2.12-1.8.0.jar -P kyuubi/
```

### 2. 推送镜像到 Harbor

```bash
cd lakehouse/scripts
chmod +x push_images.sh
./push_images.sh
```

### 3. 部署 Lakehouse

```bash
cd lakehouse/scripts
chmod +x deploy.sh

# 全量部署
./deploy.sh

# 或按需部署
./deploy.sh base     # 先部署基础资源
./deploy.sh hive     # 部署 Hive
./deploy.sh spark    # 部署 Spark
./deploy.sh kyuubi   # 部署 Kyuubi
```

### 4. 上传 JAR 包到 PVC

```bash
# 创建临时 Pod
kubectl run jar-uploader --image=busybox:1.35 --restart=Never -n lakehouse \
  --overrides='{"spec":{"volumes":[{"name":"libs","persistentVolumeClaim":{"claimName":"hadoop-libs-pvc"}}],"containers":[{"name":"jar-uploader","image":"busybox:1.35","command":["sleep","3600"],"volumeMounts":[{"name":"libs","mountPath":"/opt/hadoop-libs"}]}]}}'

# 等待就绪
kubectl wait pod/jar-uploader -n lakehouse --for=condition=Ready --timeout=60s

# 上传 JAR 包
kubectl cp ./lakehouse/hadoop-libs lakehouse/jar-uploader:/opt/

# 清理
kubectl delete pod jar-uploader -n lakehouse
```

### 5. 卸载

```bash
cd lakehouse/scripts
chmod +x uninstall.sh

./uninstall.sh        # 卸载组件（保留 Namespace 和 PVC）
./uninstall.sh --all  # 完全清除（包括 PVC 和 Namespace，谨慎使用）
```

## 访问地址

| 服务 | 地址 |
|------|------|
| Spark Master Web UI | http://192.168.226.120:30080 |
| Spark History Server | http://192.168.226.120:30180 |
| HiveServer2 (JDBC) | jdbc:hive2://192.168.226.120:30000 |
| HiveServer2 Web UI | http://192.168.226.120:30002 |
| Kyuubi JDBC | jdbc:hive2://192.168.226.120:30009 |
| Kyuubi REST API | http://192.168.226.120:30099 |

## Beeline 连接示例

```bash
# 连接 HiveServer2
beeline -u 'jdbc:hive2://192.168.226.120:30000' -n root

# 连接 Kyuubi
beeline -u 'jdbc:hive2://192.168.226.120:30009' -n root
```

## 跨命名空间通信

| 服务 | K8s DNS |
|------|---------|
| MinIO | minio.minio.svc.cluster.local:9000 |
| MySQL | mysql.bigdata.svc.cluster.local:3306 |
| Hive MetaStore | hive-metastore.lakehouse.svc.cluster.local:9083 |
| Spark Master | spark-master.lakehouse.svc.cluster.local:7077 |

## 关键设计决策

1. **StatefulSet for Spark**: 使用 StatefulSet 替代 Deployment，配合 `hostname` + `subdomain` 固定 Pod DNS 名称，解决 Worker → Master 注册时的 DNS 解析问题。

2. **SPARK_PUBLIC_DNS / SPARK_LOCAL_HOSTNAME**: 显式设置这两个环境变量，防止 Worker 向 Master 发送不可解析的 Pod IP。

3. **Headless Service**: 使用 `clusterIP: None` 的 Headless Service 确保 Pod 之间通过稳定 DNS 通信。

4. **本地 JAR 包**: 废弃 `spark.jars.packages` 在线下载，通过 PVC 挂载本地 JAR 包，消除网络依赖。

5. **ConfigMap 挂载配置**: 所有配置文件（hive-site.xml, spark-defaults.conf, kyuubi-defaults.conf）通过 ConfigMap 挂载，移除了原项目的 entrypoint.sh。