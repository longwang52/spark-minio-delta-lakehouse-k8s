# Spark-MinIO-Delta Lakehouse on Kubernetes

一个基于 Kubernetes 的完整数据湖仓一体化部署方案，集成 Apache Spark、MinIO（S3 兼容对象存储）、Delta Lake、Apache Hive Metastore 以及 Apache Kyuubi。

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌────────────────┐  │
│  │   Kyuubi    │───▶│    Spark    │───▶│     MinIO      │  │
│  │  (SQL GW)   │    │  (Cluster) │    │  (Object Store)│  │
│  └─────────────┘    └──────┬──────┘    └────────────────┘  │
│                            │                                │
│                     ┌──────▼──────┐                        │
│                     │    Hive     │                        │
│                     │  Metastore  │                        │
│                     └─────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| Apache Spark | 3.5.x | 分布式计算引擎 |
| Delta Lake | 3.x | 开放式数据格式 |
| MinIO | Latest | S3 兼容对象存储 |
| Apache Hive Metastore | 3.1.x | 元数据管理 |
| Apache Kyuubi | 1.8.x | SQL 网关 / JDBC 接口 |
| Kubernetes | 1.24+ | 容器编排平台 |

## 项目结构

```
├── README.md                    # 项目文档
├── CONFIG_GUIDE.md              # 配置指南
├── .gitignore                   # Git 忽略文件
├── config/                      # 配置文件
│   ├── hive/
│   │   └── hive-site.xml        # Hive Metastore 配置
│   ├── spark/
│   │   ├── spark-defaults.conf  # Spark 默认配置
│   │   └── hive-site.xml        # Spark 使用的 Hive 配置
│   └── kyuubi/
│       └── kyuubi-defaults.conf # Kyuubi 配置
├── k8s/                         # Kubernetes 部署文件
│   ├── 00-namespace.yaml        # 命名空间定义
│   ├── base/
│   │   └── pvc.yaml             # 持久化存储声明
│   ├── hive/
│   │   ├── hive-configmap.yaml  # Hive ConfigMap
│   │   ├── hive-metastore.yaml  # Hive Metastore 部署
│   │   └── hive-server2.yaml    # HiveServer2 部署
│   ├── spark/
│   │   ├── spark-configmap.yaml # Spark ConfigMap
│   │   ├── spark-master.yaml    # Spark Master 部署
│   │   └── spark-worker.yaml    # Spark Worker 部署
│   └── kyuubi/
│       ├── kyuubi-configmap.yaml # Kyuubi ConfigMap
│       └── kyuubi.yaml           # Kyuubi 部署
├── scripts/                     # 运维脚本
│   ├── deploy.sh                # 一键部署脚本
│   ├── uninstall.sh             # 卸载脚本
│   └── validate.sh              # 验证脚本
└── hadoop-libs/                 # Hadoop/S3 JAR 包目录
    └── .gitkeep
```

## 前置要求

- Kubernetes 集群 (1.24+)
- `kubectl` 已配置并连接到集群
- MinIO 已部署或可访问的 S3 兼容存储
- 足够的集群资源（建议至少 8 CPU，16GB 内存）

## 快速开始

### 1. 准备 Hadoop JAR 包

将以下 JAR 包放置到 `hadoop-libs/` 目录并挂载到各组件：

- `hadoop-aws-3.3.x.jar`
- `aws-java-sdk-bundle-1.12.x.jar`

### 2. 修改配置

参考 [CONFIG_GUIDE.md](CONFIG_GUIDE.md) 修改配置文件中的 MinIO 连接信息、数据库密码等敏感参数。

### 3. 部署

```bash
# 一键部署所有组件
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# 或手动逐步部署
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/base/pvc.yaml
kubectl apply -f k8s/hive/
kubectl apply -f k8s/spark/
kubectl apply -f k8s/kyuubi/
```

### 4. 验证部署

```bash
chmod +x scripts/validate.sh
./scripts/validate.sh
```

### 5. 卸载

```bash
chmod +x scripts/uninstall.sh
./scripts/uninstall.sh
```

## 访问服务

部署完成后可通过以下方式访问各服务：

| 服务 | 类型 | 端口 |
|------|------|------|
| Spark Master UI | NodePort/LoadBalancer | 8080 |
| Spark History Server | NodePort/LoadBalancer | 18080 |
| Kyuubi JDBC | NodePort/LoadBalancer | 10009 |
| HiveServer2 | ClusterIP | 10000 |

## 配置说明

详细配置说明请参考 [CONFIG_GUIDE.md](CONFIG_GUIDE.md)。

## 注意事项

1. **生产环境**：请修改所有默认密码和 AccessKey/SecretKey
2. **存储**：`hadoop-libs/` 中的 JAR 文件不纳入版本控制，需手动添加
3. **资源限制**：根据实际工作负载调整 Kubernetes 资源 requests/limits
4. **网络策略**：根据安全要求配置 NetworkPolicy

## 许可证

Apache License 2.0
