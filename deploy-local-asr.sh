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
    check_command docker-compose
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

# 清理旧容器和镜像
cleanup_old_deployment() {
    log_info "清理旧的部署..."
    
    # 停止并删除旧容器
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "停止并删除旧容器: $CONTAINER_NAME"
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true
    fi
    
    # 清理dangling镜像
    if docker images -f "dangling=true" -q | wc -l | grep -v "^0$"; then
        log_info "清理无用的Docker镜像..."
        docker image prune -f
    fi
    
    log_success "清理完成"
}

# 下载Vosk语音模型
download_vosk_models() {
    log_info "检查Vosk语音模型..."
    
    # 创建models目录
    mkdir -p ./models
    
    # 中文模型
    if [ ! -d "./models/vosk-model-small-cn-0.22" ]; then
        log_info "下载中文语音模型 (约170MB)..."
        cd models
        wget -c https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip
        unzip -q vosk-model-small-cn-0.22.zip
        rm vosk-model-small-cn-0.22.zip
        cd ..
        log_success "中文模型下载完成"
    else
        log_success "中文模型已存在"
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
    docker-compose -f docker-compose.websocket-asr-local.yml up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 5
    
    # 检查服务状态
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "websocket-asr-local.*Up"; then
        log_success "WebSocket ASR服务启动成功!"
    else
        log_error "服务启动失败，请检查日志"
        docker-compose -f docker-compose.websocket-asr-local.yml logs
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

# 显示服务日志
show_service_logs() {
    log_info "显示服务日志..."
    docker-compose -f docker-compose.websocket-asr-local.yml logs --tail=20
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
    echo "  • 支持语言: 中文 (cn) / 英文 (en)"
    echo "  • 识别模式: 手动切换"
    echo
    echo "🔧 管理命令:"
    echo "  • 查看日志: docker-compose -f docker-compose.websocket-asr-local.yml logs -f"
    echo "  • 停止服务: docker-compose -f docker-compose.websocket-asr-local.yml down"
    echo "  • 重启服务: docker-compose -f docker-compose.websocket-asr-local.yml restart"
    echo "  • 查看状态: docker-compose -f docker-compose.websocket-asr-local.yml ps"
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
    
    # 预检查
    check_dependencies
    check_docker_service
    check_port
    
    # 部署流程
    cleanup_old_deployment
    download_vosk_models
    build_docker_image
    start_service
    check_service_health
    
    # 显示结果
    show_deployment_info
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi