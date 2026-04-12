#!/usr/bin/env bash
# ============================================================
# deploy.sh - Lakehouse K8s 全量部署脚本
#
# 用法:
#   ./deploy.sh              - 全量部署所有组件
#   ./deploy.sh hive         - 仅部署 Hive 相关组件
#   ./deploy.sh spark        - 仅部署 Spark 相关组件
#   ./deploy.sh kyuubi       - 仅部署 Kyuubi
#   ./deploy.sh base         - 仅部署基础资源（Namespace, PVC, Service）
#
# 前提条件:
#   1. kubectl 已配置并连接到目标集群
#   2. Harbor 镜像已推送（或先执行 push_images.sh）
#   3. hadoop-libs PVC 中已预先放置好 JAR 包
#      参考脚本末尾的 JAR 包预置说明
# ============================================================

set -euo pipefail

# 脚本所在目录（绝对路径）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAKEHOUSE_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$LAKEHOUSE_DIR/k8s"

# 命名空间
NAMESPACE="lakehouse"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BLUE}========== $* ==========${NC}"; }

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl 未找到，请先安装并配置 kubectl"
        exit 1
    fi
    log_info "kubectl 版本: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# 应用 YAML 文件
apply_file() {
    local file="$1"
    log_info "应用: $file"
    kubectl apply -f "$file"
}

# 等待 Deployment 就绪
wait_deployment() {
    local name="$1"
    local timeout="${2:-300}"
    log_info "等待 Deployment/$name 就绪（超时: ${timeout}s）..."
    kubectl rollout status deployment/"$name" -n "$NAMESPACE" --timeout="${timeout}s" || {
        log_warn "Deployment/$name 未能在 ${timeout}s 内就绪，继续部署..."
    }
}

# 等待 StatefulSet 就绪
wait_statefulset() {
    local name="$1"
    local timeout="${2:-300}"
    log_info "等待 StatefulSet/$name 就绪（超时: ${timeout}s）..."
    kubectl rollout status statefulset/"$name" -n "$NAMESPACE" --timeout="${timeout}s" || {
        log_warn "StatefulSet/$name 未能在 ${timeout}s 内就绪，继续部署..."
    }
}

# 部署基础资源
deploy_base() {
    log_section "部署基础资源（Namespace / PVC / Headless Service）"

    # Namespace
    apply_file "$K8S_DIR/00-namespace.yaml"

    # 等待 Namespace 创建
    kubectl get ns "$NAMESPACE" &>/dev/null || sleep 3

    # Base 资源
    apply_file "$K8S_DIR/base/pvc.yaml"
    apply_file "$K8S_DIR/base/spark-headless-service.yaml"

    log_info "基础资源部署完成"
}

# 部署 Hive 组件
deploy_hive() {
    log_section "部署 Hive 组件（MetaStore + Server2）"

    apply_file "$K8S_DIR/hive/hive-configmap.yaml"
    apply_file "$K8S_DIR/hive/hive-metastore.yaml"

    # 等待 MetaStore 就绪后再部署 Server2
    wait_deployment "hive-metastore" 300

    apply_file "$K8S_DIR/hive/hive-server2.yaml"
    wait_deployment "hive-server2" 300

    log_info "Hive 组件部署完成"
}

# 部署 Spark 组件
deploy_spark() {
    log_section "部署 Spark 组件（Master + Worker-1 + Worker-2）"

    apply_file "$K8S_DIR/spark/spark-configmap.yaml"
    apply_file "$K8S_DIR/spark/spark-master.yaml"

    # 等待 Master 就绪
    wait_statefulset "spark-master" 300

    # 部署 Workers
    apply_file "$K8S_DIR/spark/spark-worker.yaml"
    wait_statefulset "spark-worker-1" 300
    wait_statefulset "spark-worker-2" 300

    log_info "Spark 组件部署完成"
}

# 部署 Kyuubi
deploy_kyuubi() {
    log_section "部署 Kyuubi"

    apply_file "$K8S_DIR/kyuubi/kyuubi-configmap.yaml"
    apply_file "$K8S_DIR/kyuubi/kyuubi.yaml"
    wait_deployment "kyuubi" 300

    log_info "Kyuubi 部署完成"
}

# 全量部署
deploy_all() {
    log_section "开始全量部署 Lakehouse"

    deploy_base
    deploy_hive
    deploy_spark
    deploy_kyuubi

    log_section "全量部署完成"
    print_access_info
}

# 打印访问信息
print_access_info() {
    log_section "访问信息"
    echo ""
    echo "  Spark Master Web UI:    http://192.168.226.120:30080"
    echo "  Spark History Server:   http://192.168.226.120:30180"
    echo "  HiveServer2 (JDBC):     jdbc:hive2://192.168.226.120:30000"
    echo "  HiveServer2 Web UI:     http://192.168.226.120:30002"
    echo "  Kyuubi (JDBC):          jdbc:hive2://192.168.226.120:30009"
    echo "  Kyuubi REST API:        http://192.168.226.120:30099"
    echo ""
    echo "  Beeline 连接示例:"
    echo "    beeline -u 'jdbc:hive2://192.168.226.120:30000' -n root"
    echo "    beeline -u 'jdbc:hive2://192.168.226.120:30009' -n root"
    echo ""
    echo "  查看所有 Pod 状态:"
    echo "    kubectl get pods -n $NAMESPACE"
    echo ""
}

# ============================================================
# JAR 包预置说明
# 在 PVC 挂载之前，需要先创建一个临时 Pod 将 JAR 包上传到 PVC
# 执行以下步骤:
#
# 1. 创建 PVC（已包含在 base 部署中）
# 2. 创建临时 Pod 挂载 PVC:
#    kubectl run jar-uploader --image=busybox:1.35 \
#      --restart=Never -n lakehouse \
#      --overrides='{"spec":{"volumes":[{"name":"libs","persistentVolumeClaim":{"claimName":"hadoop-libs-pvc"}}],"containers":[{"name":"jar-uploader","image":"busybox:1.35","command":["sleep","3600"],"volumeMounts":[{"name":"libs","mountPath":"/opt/hadoop-libs"}]}]}}' \
#      -- sleep 3600
# 3. 上传 JAR 包（注意：不加尾部斜杠，将整个 hadoop-libs 目录复制到 /opt/hadoop-libs/）:
#    kubectl cp ./hadoop-libs lakehouse/jar-uploader:/opt/
# 4. 删除临时 Pod:
#    kubectl delete pod jar-uploader -n lakehouse
# ============================================================

# 主入口
main() {
    check_kubectl

    local component="${1:-all}"

    case "$component" in
        all)        deploy_all ;;
        base)       deploy_base ;;
        hive)       deploy_hive ;;
        spark)      deploy_spark ;;
        kyuubi)     deploy_kyuubi ;;
        info)       print_access_info ;;
        *)
            log_error "未知组件: $component"
            echo "用法: $0 [all|base|hive|spark|kyuubi|info]"
            exit 1
            ;;
    esac
}

main "$@"
