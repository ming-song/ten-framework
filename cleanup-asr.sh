#!/bin/bash

# ===================================================================
# WebSocket ASR服务清理脚本
# 作者: Songm
# 功能: 清理Docker容器、镜像和相关资源
# ===================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
CONTAINER_NAME="websocket-asr-local"
IMAGE_NAME="ten-framework/websocket-asr-local"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示当前Docker资源使用情况
show_docker_status() {
    log_info "当前Docker资源使用情况："
    echo
    echo "📦 容器状态："
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -E "(NAMES|websocket-asr)" || echo "无相关容器"
    echo
    echo "🖼️ 镜像占用："
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "(REPOSITORY|ten-framework)" || echo "无相关镜像"
    echo
    echo "💾 总体资源占用："
    docker system df
    echo
}

# 清理容器
cleanup_containers() {
    log_info "清理WebSocket ASR容器..."

    # 停止运行中的容器
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "停止运行中的容器: $CONTAINER_NAME"
        docker stop $CONTAINER_NAME
        log_success "容器已停止"
    fi

    # 删除容器
    if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "删除容器: $CONTAINER_NAME"
        docker rm $CONTAINER_NAME
        log_success "容器已删除"
    else
        log_info "未找到容器: $CONTAINER_NAME"
    fi
}

# 清理镜像
cleanup_images() {
    log_info "清理WebSocket ASR镜像..."

    # 删除项目镜像
    if docker images --format "{{.Repository}}" | grep -q "^${IMAGE_NAME}$"; then
        log_info "删除项目镜像: $IMAGE_NAME"
        docker rmi $IMAGE_NAME 2>/dev/null || {
            log_warning "无法删除镜像（可能被其他容器使用），强制删除..."
            docker rmi -f $IMAGE_NAME
        }
        log_success "项目镜像已删除"
    else
        log_info "未找到项目镜像: $IMAGE_NAME"
    fi

    # 清理dangling镜像
    local dangling_images=$(docker images -f "dangling=true" -q)
    if [ -n "$dangling_images" ]; then
        local count=$(echo "$dangling_images" | wc -l)
        log_info "清理 $count 个dangling镜像..."
        docker image prune -f
        log_success "Dangling镜像已清理"
    else
        log_info "未找到dangling镜像"
    fi
}

# 清理Docker系统资源
cleanup_system() {
    log_warning "系统清理会删除所有未使用的Docker资源（镜像、容器、网络、卷）"
    read -p "是否确认执行系统清理? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "执行Docker系统清理..."
        docker system prune -a -f --volumes
        log_success "系统清理完成"
    else
        log_info "跳过系统清理"
    fi
}

# 清理模型文件（可选）
cleanup_models() {
    if [ -d "./models" ]; then
        local model_size=$(du -sh ./models 2>/dev/null | cut -f1)
        log_warning "发现模型目录 ./models (大小: $model_size)"
        log_warning "删除模型需要重新下载，建议保留以避免重复下载"
        read -p "是否删除模型文件? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "删除模型目录..."
            rm -rf ./models
            log_success "模型目录已删除"
        else
            log_info "保留模型目录"
        fi
    else
        log_info "未找到模型目录"
    fi
}

# 显示清理结果
show_cleanup_result() {
    echo
    echo "==============================================="
    log_success "清理操作完成！"
    echo "==============================================="
    echo

    log_info "清理后的Docker资源状态："
    echo
    echo "📦 剩余容器："
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | head -10
    echo
    echo "🖼️ 剩余镜像："
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -10
    echo
    echo "💾 资源占用："
    docker system df
    echo

    log_info "如需重新部署，请运行: ./deploy-local-asr.sh"
}

# 主菜单
show_menu() {
    echo "==============================================="
    echo "🧹 WebSocket ASR服务清理工具"
    echo "==============================================="
    echo
    echo "请选择清理选项："
    echo "1) 清理ASR容器和镜像（推荐）"
    echo "2) 仅清理ASR容器"
    echo "3) 仅清理ASR镜像"
    echo "4) 清理Docker系统资源（危险：影响所有Docker资源）"
    echo "5) 清理模型文件"
    echo "6) 显示资源状态"
    echo "0) 退出"
    echo
}

# 主函数
main() {
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装或未启动"
        exit 1
    fi

    # 显示当前状态
    show_docker_status

    # 显示菜单
    while true; do
        show_menu
        read -p "请输入选项 [0-6]: " choice
        echo

        case $choice in
            1)
                cleanup_containers
                cleanup_images
                show_cleanup_result
                break
                ;;
            2)
                cleanup_containers
                log_success "容器清理完成"
                ;;
            3)
                cleanup_images
                log_success "镜像清理完成"
                ;;
            4)
                cleanup_system
                show_cleanup_result
                break
                ;;
            5)
                cleanup_models
                ;;
            6)
                show_docker_status
                ;;
            0)
                log_info "退出清理工具"
                exit 0
                ;;
            *)
                log_error "无效选项，请重新选择"
                ;;
        esac
        echo
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi