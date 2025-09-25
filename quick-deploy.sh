#!/bin/bash

# 快速部署脚本 - 适用于有经验的用户
# 使用方法: ./quick-deploy.sh [port]

set -e

PORT=${1:-8765}
CONTAINER_NAME="websocket-asr-local"

echo "🚀 快速部署WebSocket ASR服务..."

# 检查依赖
command -v docker >/dev/null 2>&1 || { echo "❌ Docker未安装"; exit 1; }
if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    echo "❌ Docker Compose未安装"
    exit 1
fi

# 停止旧容器
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# 下载模型（如果不存在）
mkdir -p models
[ ! -d "models/vosk-model-small-cn-0.22" ] && {
    echo "📥 下载中文模型 Small..."
    cd models
    wget -q https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip
    unzip -q vosk-model-small-cn-0.22.zip && rm vosk-model-small-cn-0.22.zip
    cd ..
}

[ ! -d "models/vosk-model-cn-0.22" ] && {
    echo "📥 下载中文模型 Standard..."
    cd models
    wget -q https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip
    unzip -q vosk-model-cn-0.22.zip && rm vosk-model-cn-0.22.zip
    cd ..
}

[ ! -d "models/vosk-model-small-en-us-0.15" ] && {
    echo "📥 下载英文模型..."
    cd models
    wget -q https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
    unzip -q vosk-model-small-en-us-0.15.zip && rm vosk-model-small-en-us-0.15.zip
    cd ..
}

# 构建并启动
echo "🔨 构建镜像..."
docker build -f Dockerfile.websocket-asr-local -t ten-framework/websocket-asr-local . >/dev/null

echo "🚀 启动服务..."
if docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose.websocket-asr-local.yml up -d
else
    docker-compose -f docker-compose.websocket-asr-local.yml up -d
fi

sleep 5

# 检查状态
if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "websocket-asr-local.*Up"; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "✅ 部署成功!"
    echo "📡 WebSocket地址: ws://${SERVER_IP}:${PORT}"
    echo "🌐 测试页面: $(pwd)/test-websocket-asr-simple.html"
else
    echo "❌ 部署失败，查看日志:"
    if docker compose version >/dev/null 2>&1; then
        docker compose -f docker-compose.websocket-asr-local.yml logs
    else
        docker-compose -f docker-compose.websocket-asr-local.yml logs
    fi
    exit 1
fi