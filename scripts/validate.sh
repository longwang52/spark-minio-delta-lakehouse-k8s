#!/usr/bin/env bash
# =============================================================================
# validate.sh - Spark-MinIO-Delta Lakehouse K8s 部署验证脚本
# =============================================================================

set -euo pipefail

NAMESPACE="lakehouse"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
pass()   { echo -e "${GREEN}[PASS]${NC} $*"; }
fail()   { echo -e "${RED}[FAIL]${NC} $*"; FAILED=$((FAILED + 1)); }

FAILED=0

# ─────────────────────────────────────────────────────────────────────────────
# 检查 Pod 状态
# ─────────────────────────────────────────────────────────────────────────────
check_pod() {
  local name="$1"
  local label_selector="$2"
  local ready
  ready=$(kubectl get pods -n "${NAMESPACE}" -l "${label_selector}" \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')

  if [[ "${ready}" -gt 0 ]]; then
    pass "Pod ${name} 运行中 (${ready} 个实例)"
  else
    fail "Pod ${name} 未就绪"
    kubectl get pods -n "${NAMESPACE}" -l "${label_selector}" 2>/dev/null || true
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 检查 Service 状态
# ─────────────────────────────────────────────────────────────────────────────
check_service() {
  local name="$1"
  if kubectl get service "${name}" -n "${NAMESPACE}" &>/dev/null; then
    pass "Service ${name} 存在"
  else
    fail "Service ${name} 不存在"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 检查 TCP 端口连通性（需要 kubectl port-forward）
# ─────────────────────────────────────────────────────────────────────────────
check_port() {
  local svc="$1"
  local port="$2"
  local name="$3"

  # 启动 port-forward
  kubectl port-forward "svc/${svc}" "${port}:${port}" -n "${NAMESPACE}" &>/dev/null &
  local pf_pid=$!
  sleep 3

  if nc -z 127.0.0.1 "${port}" &>/dev/null; then
    pass "${name} 端口 ${port} 可达"
  else
    warn "${name} 端口 ${port} 暂不可达（服务可能仍在启动中）"
  fi

  kill "${pf_pid}" 2>/dev/null || true
  wait "${pf_pid}" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# 主验证流程
# ─────────────────────────────────────────────────────────────────────────────
main() {
  info "开始验证 Spark-MinIO-Delta Lakehouse 部署..."
  echo ""

  # 检查命名空间
  if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
    pass "命名空间 ${NAMESPACE} 存在"
  else
    fail "命名空间 ${NAMESPACE} 不存在"
    exit 1
  fi

  echo ""
  info "检查 Pod 状态..."
  check_pod "Hive Metastore"  "app=hive,component=metastore"
  check_pod "Hive Server2"    "app=hive,component=server2"
  check_pod "Spark Master"    "app=spark,component=master"
  check_pod "Spark Worker"    "app=spark,component=worker"
  check_pod "Kyuubi"          "app=kyuubi"

  echo ""
  info "检查 Service 状态..."
  check_service "hive-metastore"
  check_service "hive-server2"
  check_service "spark-master"
  check_service "spark-worker"
  check_service "kyuubi"

  echo ""
  info "检查端口连通性..."
  check_port "spark-master" 8080 "Spark Master UI"
  check_port "kyuubi"       10009 "Kyuubi JDBC"

  echo ""
  info "当前所有 Pod 状态："
  kubectl get pods -n "${NAMESPACE}" -o wide

  echo ""
  if [[ "${FAILED}" -eq 0 ]]; then
    info "所有检查通过 🎉"
  else
    error "${FAILED} 个检查失败，请查看上面的输出排查问题"
    exit 1
  fi
}

main "$@"
