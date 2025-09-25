#!/bin/bash

# ===================================================================
# 本地WebSocket ASR服务一键部署脚本
# 作者: Songm
# 功能: 在服务器上自动部署完全本地化的WebSocket ASR服务
# ===================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_NAME="websocket-asr-local"
WEBSOCKET_PORT=8765
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

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 命令未找到，请先安装 $1"
        exit 1
    fi
}

# 检查系统依赖
check_dependencies() {
    log_info "检查系统依赖..."
    check_command docker
    # 检查Docker Compose（新版本或legacy版本）
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请安装Docker Compose"
        exit 1
    fi
    check_command git
    log_success "系统依赖检查完成"
}

# 检查Docker服务状态
check_docker_service() {
    log_info "检查Docker服务状态..."
    if ! systemctl is-active --quiet docker; then
        log_warning "Docker服务未运行，尝试启动..."
        sudo systemctl start docker
        sleep 2
        if ! systemctl is-active --quiet docker; then
            log_error "Docker服务启动失败"
            exit 1
        fi
    fi
    log_success "Docker服务运行正常"
}

# 检查端口占用
check_port() {
    log_info "检查端口 $WEBSOCKET_PORT 是否被占用..."
    if lsof -Pi :$WEBSOCKET_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "端口 $WEBSOCKET_PORT 已被占用"
        read -p "是否要停止占用该端口的进程? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "停止占用端口 $WEBSOCKET_PORT 的进程..."
            sudo lsof -ti:$WEBSOCKET_PORT | xargs sudo kill -9 2>/dev/null || true
            sleep 2
        else
            log_error "部署已取消"
            exit 1
        fi
    fi
    log_success "端口 $WEBSOCKET_PORT 可用"
}

# 检查并准备容器切换（在模型下载前执行）
check_and_prepare_switch() {
    log_info "检查部署状态..."

    # 检查是否有旧容器运行
    local has_old_container=false
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        has_old_container=true
        if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            log_info "检测到运行中的旧容器: $CONTAINER_NAME（将在模型就绪后进行无缝切换）"
        else
            log_info "检测到停止的旧容器: $CONTAINER_NAME（将在模型就绪后清理）"
        fi
    else
        log_info "未检测到旧容器，将进行全新部署"
    fi

    # 清理dangling镜像（不影响服务）
    local dangling_count=$(docker images -f "dangling=true" -q | wc -l)
    if [ "$dangling_count" -gt 0 ]; then
        log_info "清理 $dangling_count 个无用的Docker镜像..."
        docker image prune -f >/dev/null 2>&1
    fi

    log_success "部署状态检查完成"
    return 0
}

# 执行容器切换（在模型和镜像就绪后执行）
perform_container_switch() {
    log_info "执行容器切换（最小化服务中断）..."

    # 快速停止并删除旧容器
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "停止旧容器: $CONTAINER_NAME"
        docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
        log_info "删除旧容器: $CONTAINER_NAME"
        docker rm $CONTAINER_NAME >/dev/null 2>&1 || true
    fi

    # 清理旧的项目镜像
    if docker images --format "table {{.Repository}}\t{{.Tag}}" | grep -q "^${IMAGE_NAME}\s"; then
        log_info "删除旧镜像: $IMAGE_NAME"
        docker rmi $IMAGE_NAME >/dev/null 2>&1 || true
    fi

    log_success "容器切换准备完成"
}

# 下载Vosk语音模型
download_vosk_models() {
    log_info "检查Vosk语音模型..."

    # 创建models目录
    mkdir -p ./models

    # 中文模型 (small)
    if [ ! -d "./models/vosk-model-small-cn-0.22" ]; then
        log_info "下载中文语音模型 Small (约170MB)..."
        cd models
        wget -c https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip
        unzip -q vosk-model-small-cn-0.22.zip
        rm vosk-model-small-cn-0.22.zip
        cd ..
        log_success "中文模型 Small 下载完成"
    else
        log_success "中文模型 Small 已存在"
    fi

    # 中文模型 (standard)
    if [ ! -d "./models/vosk-model-cn-0.22" ]; then
        log_info "下载中文语音模型 Standard (约1.8GB)..."
        cd models
        wget -c https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip
        unzip -q vosk-model-cn-0.22.zip
        rm vosk-model-cn-0.22.zip
        cd ..
        log_success "中文模型 Standard 下载完成"
    else
        log_success "中文模型 Standard 已存在"
    fi

    # 英文模型
    if [ ! -d "./models/vosk-model-small-en-us-0.15" ]; then
        log_info "下载英文语音模型 (约40MB)..."
        cd models
        wget -c https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
        unzip -q vosk-model-small-en-us-0.15.zip
        rm vosk-model-small-en-us-0.15.zip
        cd ..
        log_success "英文模型下载完成"
    else
        log_success "英文模型已存在"
    fi
}

# 构建Docker镜像
build_docker_image() {
    log_info "构建Docker镜像..."

    # 检查Dockerfile是否存在
    if [ ! -f "Dockerfile.websocket-asr-local" ]; then
        log_error "Dockerfile.websocket-asr-local 文件不存在"
        exit 1
    fi

    # 构建镜像
    docker build -f Dockerfile.websocket-asr-local -t $IMAGE_NAME . --no-cache
    log_success "Docker镜像构建完成"
}

# 启动服务
start_service() {
    log_info "启动WebSocket ASR服务..."

    # 检查docker-compose文件
    if [ ! -f "docker-compose.websocket-asr-local.yml" ]; then
        log_error "docker-compose.websocket-asr-local.yml 文件不存在"
        exit 1
    fi

    # 启动服务
    if docker compose version &> /dev/null; then
        docker compose -f docker-compose.websocket-asr-local.yml up -d
    else
        docker-compose -f docker-compose.websocket-asr-local.yml up -d
    fi

    # 等待服务启动
    log_info "等待服务启动..."
    sleep 5

    # 检查服务状态
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "websocket-asr-local.*Up"; then
        log_success "WebSocket ASR服务启动成功!"
    else
        log_error "服务启动失败，请检查日志"
        if docker compose version &> /dev/null; then
            docker compose -f docker-compose.websocket-asr-local.yml logs
        else
            docker-compose -f docker-compose.websocket-asr-local.yml logs
        fi
        exit 1
    fi
}

# 检查服务健康状态
check_service_health() {
    log_info "检查服务健康状态..."

    # 等待服务完全启动
    sleep 3

    # 检查WebSocket端口
    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if netstat -tuln | grep -q ":$WEBSOCKET_PORT "; then
            log_success "WebSocket服务 (端口 $WEBSOCKET_PORT) 运行正常"
            break
        else
            log_info "等待服务启动... (尝试 $attempt/$max_attempts)"
            sleep 2
            ((attempt++))
        fi
    done

    if [ $attempt -gt $max_attempts ]; then
        log_error "服务健康检查失败"
        show_service_logs
        exit 1
    fi
}

# 可选的深度清理（在部署完成后提供）
optional_deep_cleanup() {
    echo
    read -p "是否要清理所有未使用的Docker资源以节省空间? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "执行深度清理：删除所有未使用的资源..."
        docker system prune -a -f
        log_success "深度清理完成，已释放更多磁盘空间"
    else
        log_info "跳过深度清理"
    fi
}

# 显示服务日志
show_service_logs() {
    log_info "显示服务日志..."
    if docker compose version &> /dev/null; then
        docker compose -f docker-compose.websocket-asr-local.yml logs --tail=20
    else
        docker-compose -f docker-compose.websocket-asr-local.yml logs --tail=20
    fi
}

# 显示部署信息
show_deployment_info() {
    local server_ip=$(hostname -I | awk '{print $1}')

    echo
    echo "==============================================="
    log_success "WebSocket ASR服务部署完成!"
    echo "==============================================="
    echo
    echo "🚀 服务信息:"
    echo "  • WebSocket地址: ws://${server_ip}:${WEBSOCKET_PORT}"
    echo "  • 容器名称: $CONTAINER_NAME"
    echo "  • 支持模型: 中文Small/Standard + 英文Small"
    echo "  • 识别模式: 模型选择"
    echo "  • 模型存储: ./models/ (外挂挂载)"
    echo
    echo "🔧 管理命令:"
    if docker compose version &> /dev/null; then
        echo "  • 查看日志: docker compose -f docker-compose.websocket-asr-local.yml logs -f"
        echo "  • 停止服务: docker compose -f docker-compose.websocket-asr-local.yml down"
        echo "  • 重启服务: docker compose -f docker-compose.websocket-asr-local.yml restart"
        echo "  • 查看状态: docker compose -f docker-compose.websocket-asr-local.yml ps"
    else
        echo "  • 查看日志: docker-compose -f docker-compose.websocket-asr-local.yml logs -f"
        echo "  • 停止服务: docker-compose -f docker-compose.websocket-asr-local.yml down"
        echo "  • 重启服务: docker-compose -f docker-compose.websocket-asr-local.yml restart"
        echo "  • 查看状态: docker-compose -f docker-compose.websocket-asr-local.yml ps"
    fi
    echo
    echo "🌐 测试页面:"
    echo "  • 本地测试: file://$(pwd)/test-websocket-asr-simple.html"
    echo "  • 服务器测试: 将test-websocket-asr-simple.html复制到客户端打开"
    echo
    echo "📋 快速测试:"
    echo "  1. 在浏览器中打开测试页面"
    echo "  2. 设置服务器地址为: ws://${server_ip}:${WEBSOCKET_PORT}"
    echo "  3. 点击"连接服务器"按钮"
    echo "  4. 选择语言并开始录音测试"
    echo
}

# 主函数
main() {
    echo "==============================================="
    echo "🎤 本地WebSocket ASR服务一键部署脚本"
    echo "==============================================="
    echo

    # 阶段1：预检查
    log_info "阶段1: 系统环境检查"
    check_dependencies
    check_docker_service
    check_port

    # 阶段2：检查部署状态
    log_info "阶段2: 检查当前部署状态"
    check_and_prepare_switch

    # 阶段3：模型准备（关键优化：在切换服务前完成）
    log_info "阶段3: 模型文件检查和下载（优先保证模型就绪）"
    download_vosk_models

    # 阶段4：快速容器切换（模型已就绪，最小化服务中断）
    log_info "阶段4: 执行容器切换（模型已就绪，加速切换）"
    perform_container_switch

    # 阶段5：镜像构建和服务启动
    log_info "阶段5: 构建新镜像和启动服务"
    build_docker_image
    start_service

    # 阶段6：验证和展示
    log_info "阶段6: 服务健康检查和部署信息展示"
    check_service_health
    show_deployment_info

    # 阶段7：可选清理
    optional_deep_cleanup

    echo
    log_success "部署流程完成！服务切换时间已最小化。"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi