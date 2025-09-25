#!/bin/bash

# V100服务器模型下载脚本
# 针对高性能服务器优化，优先下载标准版模型

set -e

MODELS_DIR="./models"
LOG_FILE="model_download.log"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a $LOG_FILE
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a $LOG_FILE
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a $LOG_FILE
}

# 创建模型目录
mkdir -p $MODELS_DIR
cd $MODELS_DIR

echo "========================================"
echo "🎯 V100服务器Vosk模型下载工具"
echo "========================================"
echo

# 中文标准版模型（V100服务器推荐）
if [ ! -d "vosk-model-cn-0.22" ]; then
    log_info "下载中文标准版模型 (推荐用于V100服务器，高精度识别) ~1.8GB"
    wget -c --progress=bar:force https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip
    log_info "解压中文标准版模型..."
    unzip -q vosk-model-cn-0.22.zip
    rm vosk-model-cn-0.22.zip
    log_success "中文标准版模型安装完成"
else
    log_success "中文标准版模型已存在"
fi

# 中文轻量版模型（备用）
if [ ! -d "vosk-model-small-cn-0.22" ]; then
    log_info "下载中文轻量版模型 (备用选项) ~170MB"
    wget -c --progress=bar:force https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip
    unzip -q vosk-model-small-cn-0.22.zip
    rm vosk-model-small-cn-0.22.zip
    log_success "中文轻量版模型安装完成"
else
    log_success "中文轻量版模型已存在"
fi

# 英文模型
if [ ! -d "vosk-model-small-en-us-0.15" ]; then
    log_info "下载英文模型 ~40MB"
    wget -c --progress=bar:force https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
    unzip -q vosk-model-small-en-us-0.15.zip
    rm vosk-model-small-en-us-0.15.zip
    log_success "英文模型安装完成"
else
    log_success "英文模型已存在"
fi

cd ..

echo
echo "========================================"
log_success "模型下载完成！"
echo "========================================"
echo
echo "📁 模型存储位置: $(pwd)/models/"
echo "🐳 Docker挂载路径: /app/models"
echo "🎯 推荐模型: vosk-model-cn-0.22 (高精度中文识别)"
echo
echo "模型大小统计:"
du -sh models/* 2>/dev/null || echo "模型大小计算中..."
echo

echo "下一步操作:"
echo "1. 启动Docker服务: docker compose -f docker-compose.websocket-asr-local.yml up -d"
echo "2. 检查模型挂载: docker exec websocket-asr-local ls -la /app/models"
echo "3. 测试识别服务: 使用test-websocket-asr-simple.html"