#!/usr/bin/env bash
# ============================================================
# uninstall.sh - Lakehouse K8s 卸载脚本
#
# 用法:
#   ./uninstall.sh           - 卸载所有组件（保留 Namespace）
#   ./uninstall.sh --all     - 卸载所有组件（包括 Namespace 和 PVC）
#   ./uninstall.sh hive      - 仅卸载 Hive 相关组件
#   ./uninstall.sh spark     - 仅卸载 Spark 相关组件
#   ./uninstall.sh kyuubi    - 仅卸载 Kyuubi
#
# 注意:
#   --all 选项会删除 PVC，可能导致数据丢失！
#   请确认数据已备份后再使用 --all
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAKEHOUSE_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$LAKEHOUSE_DIR/k8s"

NAMESPACE="lakehouse"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BLUE}========== $* ==========${NC}"; }

# 删除资源（忽略不存在的错误）
delete_file() {
    local file="$1"
    if [ -f "$file" ]; then
        log_info "删除: $file"
        kubectl delete -f "$file" --ignore-not-found=true || true
    fi
}

# 卸载 Kyuubi
uninstall_kyuubi() {
    log_section "卸载 Kyuubi"
    delete_file "$K8S_DIR/kyuubi/kyuubi.yaml"
    delete_file "$K8S_DIR/kyuubi/kyuubi-configmap.yaml"
    log_info "Kyuubi 卸载完成"
}

# 卸载 Spark 组件
uninstall_spark() {
    log_section "卸载 Spark 组件"
    delete_file "$K8S_DIR/spark/spark-worker.yaml"
    delete_file "$K8S_DIR/spark/spark-master.yaml"
    delete_file "$K8S_DIR/spark/spark-configmap.yaml"
    log_info "Spark 组件卸载完成"
}

# 卸载 Hive 组件
uninstall_hive() {
    log_section "卸载 Hive 组件"
    delete_file "$K8S_DIR/hive/hive-server2.yaml"
    delete_file "$K8S_DIR/hive/hive-metastore.yaml"
    delete_file "$K8S_DIR/hive/hive-configmap.yaml"
    log_info "Hive 组件卸载完成"
}

# 卸载基础资源（不含 PVC）
uninstall_base() {
    log_section "卸载基础 Service 和 Headless Service"
    delete_file "$K8S_DIR/base/spark-headless-service.yaml"
    log_info "基础 Service 卸载完成"
}

# 删除 PVC（危险操作，需确认）
delete_pvcs() {
    log_warn "即将删除 PVC，这将导致持久化数据丢失！"
    read -r -p "确认删除 PVC？[y/N] " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        log_info "删除 PVC..."
        kubectl delete pvc hadoop-libs-pvc spark-history-cache-pvc hive-warehouse-pvc \
            -n "$NAMESPACE" --ignore-not-found=true || true
        log_info "PVC 已删除"
    else
        log_info "跳过 PVC 删除"
    fi
}

# 删除 Namespace（最终清理）
delete_namespace() {
    log_warn "即将删除 Namespace: $NAMESPACE"
    read -r -p "确认删除 Namespace $NAMESPACE（将清除其中所有资源）？[y/N] " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        kubectl delete ns "$NAMESPACE" --ignore-not-found=true || true
        log_info "Namespace $NAMESPACE 已删除"
    else
        log_info "跳过 Namespace 删除"
    fi
}

# 全量卸载（保留 Namespace 和 PVC）
uninstall_all() {
    log_section "开始卸载所有 Lakehouse 组件"

    uninstall_kyuubi
    uninstall_spark
    uninstall_hive
    uninstall_base

    log_section "卸载完成（Namespace 和 PVC 已保留）"
    echo ""
    log_info "如需完全清除，请运行: $0 --all"
    echo ""
}

# 完全清除（包括 PVC 和 Namespace）
uninstall_everything() {
    log_section "完全清除所有 Lakehouse 资源"

    uninstall_kyuubi
    uninstall_spark
    uninstall_hive
    uninstall_base
    delete_pvcs
    delete_namespace

    log_section "完全清除完成"
}

# 主入口
main() {
    local component="${1:-all}"

    case "$component" in
        all)        uninstall_all ;;
        --all)      uninstall_everything ;;
        hive)       uninstall_hive ;;
        spark)      uninstall_spark ;;
        kyuubi)     uninstall_kyuubi ;;
        base)       uninstall_base ;;
        *)
            log_error "未知选项: $component"
            echo "用法: $0 [all|--all|hive|spark|kyuubi|base]"
            exit 1
            ;;
    esac
}

main "$@"
