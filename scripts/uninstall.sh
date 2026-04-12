#!/usr/bin/env bash
# =============================================================================
# uninstall.sh - Spark-MinIO-Delta Lakehouse K8s 卸载脚本
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

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─────────────────────────────────────────────────────────────────────────────
# 确认卸载
# ─────────────────────────────────────────────────────────────────────────────
confirm_uninstall() {
  warn "此操作将删除命名空间 '${NAMESPACE}' 中的所有资源！"
  warn "PVC 中的数据可能会丢失（取决于 StorageClass 的 reclaim policy）"
  echo ""
  read -r -p "确认卸载？输入 'yes' 继续: " confirm
  if [[ "${confirm}" != "yes" ]]; then
    info "卸载已取消"
    exit 0
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 卸载组件
# ─────────────────────────────────────────────────────────────────────────────
uninstall_kyuubi() {
  info "卸载 Kyuubi..."
  kubectl delete -f "${ROOT_DIR}/k8s/kyuubi/" --ignore-not-found=true
}

uninstall_spark() {
  info "卸载 Spark..."
  kubectl delete -f "${ROOT_DIR}/k8s/spark/" --ignore-not-found=true
}

uninstall_hive() {
  info "卸载 Hive..."
  kubectl delete -f "${ROOT_DIR}/k8s/hive/" --ignore-not-found=true
}

uninstall_base() {
  info "卸载基础资源 (PVC)..."
  kubectl delete -f "${ROOT_DIR}/k8s/base/" --ignore-not-found=true
}

uninstall_namespace() {
  info "删除命名空间: ${NAMESPACE}"
  kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true
}

# ─────────────────────────────────────────────────────────────────────────────
# 主流程
# ─────────────────────────────────────────────────────────────────────────────
main() {
  info "开始卸载 Spark-MinIO-Delta Lakehouse..."

  if ! command -v kubectl &>/dev/null; then
    error "kubectl 未安装或不在 PATH 中"
    exit 1
  fi

  confirm_uninstall

  uninstall_kyuubi
  uninstall_spark
  uninstall_hive
  uninstall_base
  uninstall_namespace

  info "卸载完成 ✓"
}

main "$@"
