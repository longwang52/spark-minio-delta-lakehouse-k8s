#!/usr/bin/env bash
# =============================================================================
# deploy.sh - Spark-MinIO-Delta Lakehouse K8s 一键部署脚本
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NAMESPACE="lakehouse"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─────────────────────────────────────────────────────────────────────────────
# 前置检查
# ─────────────────────────────────────────────────────────────────────────────
check_prerequisites() {
  info "检查前置条件..."

  if ! command -v kubectl &>/dev/null; then
    error "kubectl 未安装或不在 PATH 中，请先安装 kubectl"
    exit 1
  fi

  if ! kubectl cluster-info &>/dev/null; then
    error "无法连接到 Kubernetes 集群，请检查 kubeconfig 配置"
    exit 1
  fi

  info "前置条件检查通过 ✓"
}

# ─────────────────────────────────────────────────────────────────────────────
# 部署函数
# ─────────────────────────────────────────────────────────────────────────────
deploy_namespace() {
  info "创建命名空间: ${NAMESPACE}"
  kubectl apply -f "${ROOT_DIR}/k8s/00-namespace.yaml"
}

deploy_base() {
  info "部署基础存储资源 (PVC)..."
  kubectl apply -f "${ROOT_DIR}/k8s/base/"
}

deploy_hive() {
  info "部署 MySQL（Hive 元数据库）..."
  kubectl apply -f "${ROOT_DIR}/k8s/hive/mysql.yaml"
  info "等待 MySQL 就绪..."
  kubectl rollout status deployment/mysql -n "${NAMESPACE}" --timeout=180s

  info "部署 Hive Metastore 和 HiveServer2..."
  kubectl apply -f "${ROOT_DIR}/k8s/hive/hive-configmap.yaml"
  kubectl apply -f "${ROOT_DIR}/k8s/hive/hive-metastore.yaml"
  kubectl apply -f "${ROOT_DIR}/k8s/hive/hive-server2.yaml"
  info "等待 Hive Metastore 就绪..."
  kubectl rollout status deployment/hive-metastore -n "${NAMESPACE}" --timeout=180s
}

deploy_spark() {
  info "部署 Spark 集群..."
  kubectl apply -f "${ROOT_DIR}/k8s/spark/"
  info "等待 Spark Master 就绪..."
  kubectl rollout status deployment/spark-master -n "${NAMESPACE}" --timeout=120s
  info "等待 Spark Worker 就绪..."
  kubectl rollout status deployment/spark-worker -n "${NAMESPACE}" --timeout=120s
}

deploy_kyuubi() {
  info "部署 Kyuubi SQL 网关..."
  kubectl apply -f "${ROOT_DIR}/k8s/kyuubi/"
  info "等待 Kyuubi 就绪..."
  kubectl rollout status deployment/kyuubi -n "${NAMESPACE}" --timeout=180s
}

# ─────────────────────────────────────────────────────────────────────────────
# 显示部署结果
# ─────────────────────────────────────────────────────────────────────────────
show_status() {
  info "部署完成！当前组件状态："
  echo ""
  kubectl get pods -n "${NAMESPACE}"
  echo ""
  kubectl get services -n "${NAMESPACE}"
  echo ""
  info "可通过以下方式访问服务："
  echo "  Spark Master UI: kubectl port-forward svc/spark-master 8080:8080 -n ${NAMESPACE}"
  echo "  Kyuubi JDBC:     kubectl port-forward svc/kyuubi 10009:10009 -n ${NAMESPACE}"
  echo "  HiveServer2:     kubectl port-forward svc/hive-server2 10000:10000 -n ${NAMESPACE}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 主流程
# ─────────────────────────────────────────────────────────────────────────────
main() {
  info "开始部署 Spark-MinIO-Delta Lakehouse..."
  check_prerequisites
  deploy_namespace
  deploy_base
  deploy_hive
  deploy_spark
  deploy_kyuubi
  show_status
  info "部署完成 🎉"
}

main "$@"
