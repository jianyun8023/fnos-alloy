#!/bin/bash

# Grafana Alloy 飞牛应用 - 多架构打包脚本
# 支持 x86 (amd64) 和 arm (arm64) 架构
# 使用 fnpack 官方工具打包

set -e

# 配置
ALLOY_VERSION="1.13.0"
FNPACK_VERSION="1.2.1"

# Alloy 下载 URL 模板
ALLOY_URL_AMD64="https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-amd64.zip"
ALLOY_URL_ARM64="https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-arm64.zip"

# fnpack 下载 URL（根据当前系统自动选择）
detect_fnpack_url() {
    local os arch
    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        *)      log_error "不支持的操作系统: $(uname -s)"; exit 1 ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)   arch="amd64" ;;
        aarch64|arm64)  arch="arm64" ;;
        *)              log_error "不支持的架构: $(uname -m)"; exit 1 ;;
    esac
    echo "https://static2.fnnas.com/fnpack/fnpack-${FNPACK_VERSION}-${os}-${arch}"
}

# 脚本所在目录（即项目根目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FNPACK="${SCRIPT_DIR}/fnpack"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查并安装 fnpack
ensure_fnpack() {
    if [ -f "${FNPACK}" ]; then
        log_info "fnpack 已存在: ${FNPACK}"
        return
    fi

    local url
    url=$(detect_fnpack_url)
    log_info "下载 fnpack: ${url}"
    curl -fsSL "${url}" -o "${FNPACK}"
    chmod +x "${FNPACK}"
    log_info "fnpack 下载完成"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."

    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装"
        exit 1
    fi

    if ! command -v unzip &> /dev/null; then
        log_error "unzip 未安装"
        exit 1
    fi

    ensure_fnpack
    log_info "依赖检查通过"
}

# 下载 Alloy 二进制
download_alloy() {
    local arch=$1
    local url=$2
    local filename="alloy-linux-${arch}.zip"
    local extract_name="alloy-linux-${arch}"

    log_info "下载 Alloy ${ALLOY_VERSION} (${arch})..."

    if [ -f "/tmp/${filename}" ]; then
        log_warn "使用缓存: /tmp/${filename}"
    else
        curl -fsSL "${url}" -o "/tmp/${filename}"
    fi

    log_info "解压 Alloy..."
    rm -rf "/tmp/alloy-extract-${arch}"
    unzip -o "/tmp/${filename}" -d "/tmp/alloy-extract-${arch}"

    # 复制到 app/bin
    mkdir -p "${SCRIPT_DIR}/app/bin"
    mv "/tmp/alloy-extract-${arch}/${extract_name}" "${SCRIPT_DIR}/app/bin/alloy"
    chmod +x "${SCRIPT_DIR}/app/bin/alloy"

    log_info "Alloy 二进制已就位: app/bin/alloy"
}

# 更新 manifest 平台和版本
update_manifest() {
    local platform=$1

    log_info "更新 manifest: platform=${platform}, version=${ALLOY_VERSION}"

    local manifest="${SCRIPT_DIR}/manifest"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^platform[[:space:]]*=.*/platform              = ${platform}/" "${manifest}"
        sed -i '' "s/^version[[:space:]]*=.*/version               = ${ALLOY_VERSION}/" "${manifest}"
    else
        sed -i "s/^platform[[:space:]]*=.*/platform              = ${platform}/" "${manifest}"
        sed -i "s/^version[[:space:]]*=.*/version               = ${ALLOY_VERSION}/" "${manifest}"
    fi
}

# 构建单个架构
build_arch() {
    local arch=$1       # amd64 / arm64
    local platform=$2   # x86 / arm（fnOS manifest 中的值）
    local url=$3

    log_info "=========================================="
    log_info "构建 ${arch} (${platform}) 版本"
    log_info "=========================================="

    # 下载并安装二进制
    download_alloy "${arch}" "${url}"

    # 更新 manifest
    update_manifest "${platform}"

    # 使用 fnpack 打包
    log_info "使用 fnpack 打包..."
    cd "${SCRIPT_DIR}"
    ${FNPACK} build

    # 重命名输出文件以区分架构
    local output_file="${SCRIPT_DIR}/grafana.alloy.fpk"
    local target_file="${SCRIPT_DIR}/grafana.alloy_${ALLOY_VERSION}_${platform}.fpk"

    if [ -f "${output_file}" ]; then
        mv "${output_file}" "${target_file}"
        log_info "打包完成: $(basename "${target_file}")"
        ls -lh "${target_file}"
    else
        log_error "打包失败，未找到输出文件"
        exit 1
    fi

    echo ""
}

# 清理
cleanup() {
    log_info "清理临时文件..."
    rm -rf /tmp/alloy-extract-*
    rm -f "${SCRIPT_DIR}/app/bin/alloy"
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  all       构建所有架构 (x86 + arm)"
    echo "  amd64     仅构建 x86 (amd64)"
    echo "  arm64     仅构建 arm (arm64)"
    echo "  clean     清理缓存和临时文件"
    echo "  help      显示帮助"
    echo ""
    echo "示例:"
    echo "  $0 all       # 构建双架构"
    echo "  $0 amd64     # 仅构建 x86"
    echo "  $0 arm64     # 仅构建 arm"
    echo ""
}

# 主函数
main() {
    local target=${1:-"all"}

    case "$target" in
        all)
            check_dependencies
            build_arch "amd64" "x86" "${ALLOY_URL_AMD64}"
            build_arch "arm64" "arm" "${ALLOY_URL_ARM64}"
            cleanup
            log_info "=========================================="
            log_info "所有架构打包完成！"
            log_info "=========================================="
            ls -lh "${SCRIPT_DIR}"/grafana.alloy_*.fpk
            ;;
        amd64|x86)
            check_dependencies
            build_arch "amd64" "x86" "${ALLOY_URL_AMD64}"
            cleanup
            ;;
        arm64|arm)
            check_dependencies
            build_arch "arm64" "arm" "${ALLOY_URL_ARM64}"
            cleanup
            ;;
        clean)
            cleanup
            rm -f /tmp/alloy-linux-*.zip
            rm -f "${SCRIPT_DIR}"/grafana.alloy*.fpk
            log_info "清理完成"
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            log_error "未知选项: $target"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
