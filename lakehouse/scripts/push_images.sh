#!/usr/bin/env bash
# ============================================================
# push_images.sh - Harbor 镜像推送脚本
#
# 将原始镜像推送到私有 Harbor 仓库
# Harbor: myharbor.com/bigdata
#
# 用法:
#   ./push_images.sh           - 推送所有镜像
#   ./push_images.sh spark     - 仅推送 Spark 镜像
#   ./push_images.sh hive      - 仅推送 Hive 镜像
#   ./push_images.sh kyuubi    - 仅推送 Kyuubi 镜像
#
# 前提条件:
#   1. Docker 已安装并运行
#   2. 已登录 Harbor: docker login myharbor.com
#   3. 网络可访问原始镜像源（DockerHub / Apache 官方）
# ============================================================

set -euo pipefail

# Harbor 地址
HARBOR_HOST="myharbor.com"
HARBOR_PROJECT="bigdata"
HARBOR_REGISTRY="${HARBOR_HOST}/${HARBOR_PROJECT}"

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

# 镜像定义
# 格式: "源镜像:标签 目标镜像名:标签"
SPARK_IMAGE_SRC="bitnami/spark:3.4.1"
SPARK_IMAGE_DST="${HARBOR_REGISTRY}/bitnami/spark:3.4.1"

HIVE_IMAGE_SRC="apache/hive:3.1.3"
HIVE_IMAGE_DST="${HARBOR_REGISTRY}/apache/hive:3.1.3"

KYUUBI_IMAGE_SRC="apache/kyuubi:1.8.0-spark"
KYUUBI_IMAGE_DST="${HARBOR_REGISTRY}/apache/kyuubi:1.8.0-spark"

# 拉取并推送单个镜像
push_image() {
    local src="$1"
    local dst="$2"

    log_info "拉取镜像: $src"
    docker pull "$src"

    log_info "标记镜像: $src -> $dst"
    docker tag "$src" "$dst"

    log_info "推送镜像: $dst"
    docker push "$dst"

    log_info "镜像推送成功: $dst"
}

# 推送 Spark 镜像
push_spark() {
    log_section "推送 Spark 镜像"
    push_image "$SPARK_IMAGE_SRC" "$SPARK_IMAGE_DST"
}

# 推送 Hive 镜像
push_hive() {
    log_section "推送 Hive 镜像"
    push_image "$HIVE_IMAGE_SRC" "$HIVE_IMAGE_DST"
}

# 推送 Kyuubi 镜像
push_kyuubi() {
    log_section "推送 Kyuubi 镜像"
    push_image "$KYUUBI_IMAGE_SRC" "$KYUUBI_IMAGE_DST"
}

# 推送所有镜像
push_all() {
    log_section "推送所有 Lakehouse 镜像到 $HARBOR_REGISTRY"

    # 检查 Docker 是否运行
    if ! docker info &>/dev/null; then
        log_error "Docker 未运行或无权限"
        exit 1
    fi

    # 检查是否已登录 Harbor
    log_info "检查 Harbor 登录状态..."
    if ! docker login "$HARBOR_HOST" 2>/dev/null; then
        log_warn "未登录 Harbor，尝试登录..."
        read -r -p "Harbor 用户名: " harbor_user
        read -r -s -p "Harbor 密码: " harbor_pass
        echo ""
        docker login "$HARBOR_HOST" -u "$harbor_user" -p "$harbor_pass"
    fi

    push_spark
    push_hive
    push_kyuubi

    log_section "所有镜像推送完成"
    echo ""
    log_info "已推送的镜像列表:"
    echo "  - $SPARK_IMAGE_DST"
    echo "  - $HIVE_IMAGE_DST"
    echo "  - $KYUUBI_IMAGE_DST"
    echo ""
}

# 主入口
main() {
    local component="${1:-all}"

    case "$component" in
        all)        push_all ;;
        spark)      push_spark ;;
        hive)       push_hive ;;
        kyuubi)     push_kyuubi ;;
        *)
            log_error "未知组件: $component"
            echo "用法: $0 [all|spark|hive|kyuubi]"
            exit 1
            ;;
    esac
}

main "$@"
