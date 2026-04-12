# hadoop-libs

本目录存放所有依赖 JAR 包，通过 PVC 挂载到 Spark、Hive、Kyuubi 容器中。

## 目录结构

```
hadoop-libs/
├── hive/       # Hive 相关 JAR 包（如 hadoop-aws 等）
├── spark/      # Spark 相关 JAR 包（delta-core, hadoop-aws, aws-java-sdk-bundle）
├── kyuubi/     # Kyuubi 相关 JAR 包（kyuubi-spark-connector-hive 等）
└── mysql/      # MySQL JDBC 驱动
```

## 所需 JAR 包列表

### spark/

| JAR 包 | 版本 | 说明 |
|--------|------|------|
| `delta-core_2.12-2.4.0.jar` | 2.4.0 | Delta Lake Core（Scala 2.12） |
| `delta-storage-2.4.0.jar` | 2.4.0 | Delta Lake Storage |
| `hadoop-aws-3.3.6.jar` | 3.3.6 | Hadoop AWS S3A 支持 |
| `aws-java-sdk-bundle-1.11.271.jar` | 1.11.271 | AWS Java SDK |

### hive/

| JAR 包 | 版本 | 说明 |
|--------|------|------|
| `hadoop-aws-3.3.6.jar` | 3.3.6 | Hadoop AWS S3A 支持 |
| `aws-java-sdk-bundle-1.11.271.jar` | 1.11.271 | AWS Java SDK |

### kyuubi/

| JAR 包 | 版本 | 说明 |
|--------|------|------|
| `kyuubi-spark-connector-hive_2.12-1.8.0.jar` | 1.8.0 | Kyuubi Hive 连接器 |
| `kyuubi-extension-spark-3-4_2.12-1.8.0.jar` | 1.8.0 | Kyuubi Spark 3.4 扩展 |

### mysql/

| JAR 包 | 版本 | 说明 |
|--------|------|------|
| `mysql-connector-java-5.1.49.jar` | 5.1.49 | MySQL JDBC 驱动 |

## 下载方式

```bash
# Delta Lake Core
wget https://repo1.maven.org/maven2/io/delta/delta-core_2.12/2.4.0/delta-core_2.12-2.4.0.jar -P spark/
wget https://repo1.maven.org/maven2/io/delta/delta-storage/2.4.0/delta-storage-2.4.0.jar -P spark/

# Hadoop AWS
wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.6/hadoop-aws-3.3.6.jar -P spark/
cp spark/hadoop-aws-3.3.6.jar hive/

# AWS Java SDK
wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.271/aws-java-sdk-bundle-1.11.271.jar -P spark/
cp spark/aws-java-sdk-bundle-1.11.271.jar hive/

# MySQL JDBC
wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar -P mysql/

# Kyuubi
wget https://repo1.maven.org/maven2/org/apache/kyuubi/kyuubi-spark-connector-hive_2.12/1.8.0/kyuubi-spark-connector-hive_2.12-1.8.0.jar -P kyuubi/
wget https://repo1.maven.org/maven2/org/apache/kyuubi/kyuubi-extension-spark-3-4_2.12/1.8.0/kyuubi-extension-spark-3-4_2.12-1.8.0.jar -P kyuubi/
```

## 上传 JAR 包到 PVC

```bash
# 1. 创建临时 Pod 挂载 PVC
kubectl run jar-uploader --image=busybox:1.35 \
  --restart=Never -n lakehouse \
  --overrides='{
    "spec": {
      "volumes": [{"name":"libs","persistentVolumeClaim":{"claimName":"hadoop-libs-pvc"}}],
      "containers": [{
        "name": "jar-uploader",
        "image": "busybox:1.35",
        "command": ["sleep","3600"],
        "volumeMounts": [{"name":"libs","mountPath":"/opt/hadoop-libs"}]
      }]
    }
  }'

# 2. 等待 Pod 就绪
kubectl wait pod/jar-uploader -n lakehouse --for=condition=Ready --timeout=60s

# 3. 上传 JAR 包
kubectl cp ./hadoop-libs lakehouse/jar-uploader:/opt/

# 4. 验证
kubectl exec -n lakehouse jar-uploader -- ls -la /opt/hadoop-libs/spark/

# 5. 删除临时 Pod
kubectl delete pod jar-uploader -n lakehouse
```
