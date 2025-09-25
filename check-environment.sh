#!/bin/bash

# 服务器环境检查脚本
# 用于在部署前检查服务器是否满足运行要求

echo "==================================================="
echo "🔍 服务器环境检查 - WebSocket ASR服务部署准备"
echo "==================================================="
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

check_pass() {
    echo -e "  ✅ ${GREEN}PASS${NC}: $1"
    ((PASS++))
}

check_fail() {
    echo -e "  ❌ ${RED}FAIL${NC}: $1"
    ((FAIL++))
}

check_warn() {
    echo -e "  ⚠️  ${YELLOW}WARN${NC}: $1"
}

check_info() {
    echo -e "  ℹ️  ${BLUE}INFO${NC}: $1"
}

# 1. 系统信息
echo "📊 系统信息检查"
echo "-------------------"
check_info "操作系统: $(lsb_release -d 2>/dev/null | cut -f2 || uname -s)"
check_info "内核版本: $(uname -r)"
check_info "架构: $(uname -m)"
echo

# 2. 硬件资源检查
echo "💻 硬件资源检查"
echo "-------------------"

# 内存检查
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}' | sed 's/Gi//')
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')
if [ "$TOTAL_MEM_MB" -ge 4096 ]; then
    check_pass "内存: ${TOTAL_MEM}B (≥4GB)"
elif [ "$TOTAL_MEM_MB" -ge 2048 ]; then
    check_warn "内存: ${TOTAL_MEM}B (推荐4GB+)"
else
    check_fail "内存: ${TOTAL_MEM}B (最低需要2GB)"
fi

# 存储空间检查
AVAIL_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAIL_SPACE" -ge 5 ]; then
    check_pass "可用存储: ${AVAIL_SPACE}GB (≥5GB)"
elif [ "$AVAIL_SPACE" -ge 2 ]; then
    check_warn "可用存储: ${AVAIL_SPACE}GB (推荐5GB+)"
else
    check_fail "可用存储: ${AVAIL_SPACE}GB (最低需要2GB)"
fi

# CPU检查
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -ge 4 ]; then
    check_pass "CPU核心: ${CPU_CORES}核 (≥4核)"
elif [ "$CPU_CORES" -ge 2 ]; then
    check_warn "CPU核心: ${CPU_CORES}核 (推荐4核+)"
else
    check_fail "CPU核心: ${CPU_CORES}核 (最低需要2核)"
fi

echo

# 3. 必需软件检查
echo "🛠️  必需软件检查"
echo "-------------------"

# Docker检查
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    check_pass "Docker: v${DOCKER_VERSION}"
    
    # Docker服务状态
    if systemctl is-active --quiet docker 2>/dev/null; then
        check_pass "Docker服务: 运行中"
    else
        check_fail "Docker服务: 未运行"
    fi
    
    # Docker权限检查
    if docker ps &> /dev/null; then
        check_pass "Docker权限: 正常"
    else
        check_fail "Docker权限: 当前用户无法运行docker命令"
    fi
else
    check_fail "Docker: 未安装"
fi

# Docker Compose检查
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
    check_pass "Docker Compose: v${COMPOSE_VERSION}"
else
    check_fail "Docker Compose: 未安装"
fi

# Git检查
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    check_pass "Git: v${GIT_VERSION}"
else
    check_fail "Git: 未安装"
fi

# Wget检查
if command -v wget &> /dev/null; then
    check_pass "Wget: 已安装"
else
    check_fail "Wget: 未安装"
fi

# Unzip检查
if command -v unzip &> /dev/null; then
    check_pass "Unzip: 已安装"
else
    check_fail "Unzip: 未安装"
fi

echo

# 4. 网络检查
echo "🌐 网络连接检查"
echo "-------------------"

# 外网连接检查
if ping -c 1 8.8.8.8 &> /dev/null; then
    check_pass "外网连接: 正常"
else
    check_fail "外网连接: 无法连接到外网"
fi

# DNS解析检查
if nslookup alphacephei.com &> /dev/null; then
    check_pass "DNS解析: 正常"
else
    check_fail "DNS解析: 无法解析域名"
fi

# 模型下载测试
echo "  📥 测试模型下载连接..."
if wget --spider -q --timeout=10 https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip; then
    check_pass "模型下载: 连接正常"
else
    check_fail "模型下载: 无法连接到模型服务器"
fi

echo

# 5. 端口检查
echo "🔌 端口检查"
echo "-------------------"

# 检查8765端口
if netstat -tuln 2>/dev/null | grep -q ":8765 "; then
    check_fail "端口8765: 已被占用"
else
    check_pass "端口8765: 可用"
fi

# 检查防火墙状态
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    check_info "防火墙状态: $UFW_STATUS"
fi

echo

# 6. GPU检查（可选）
echo "🎮 GPU检查（可选）"
echo "-------------------"

if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
    check_pass "NVIDIA GPU: $GPU_INFO"
    
    # CUDA检查
    if command -v nvcc &> /dev/null; then
        CUDA_VERSION=$(nvcc --version | grep "release" | cut -d' ' -f5 | cut -d',' -f1)
        check_pass "CUDA: $CUDA_VERSION"
    else
        check_warn "CUDA: 未安装（GPU加速不可用）"
    fi
else
    check_info "GPU: 未检测到NVIDIA GPU（将使用CPU）"
fi

echo

# 7. 总结
echo "📋 检查结果总结"
echo "-------------------"
echo -e "✅ 通过: ${GREEN}$PASS${NC} 项"
echo -e "❌ 失败: ${RED}$FAIL${NC} 项"
echo

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 恭喜！服务器环境完全满足部署要求${NC}"
    echo -e "${GREEN}📝 建议：可以直接运行 ./deploy-local-asr.sh 进行部署${NC}"
elif [ $FAIL -le 3 ]; then
    echo -e "${YELLOW}⚠️  警告：服务器环境基本满足要求，但有些问题需要解决${NC}"
    echo -e "${YELLOW}📝 建议：解决上述❌标记的问题后再进行部署${NC}"
else
    echo -e "${RED}🚫 错误：服务器环境不满足部署要求${NC}"
    echo -e "${RED}📝 建议：请先解决上述问题，特别是❌标记的必需项${NC}"
fi

echo
echo "🔧 常见问题解决方案："
echo "• Docker安装: curl -fsSL https://get.docker.com | sh"
echo "• Docker Compose安装: pip install docker-compose"
echo "• 用户权限: sudo usermod -aG docker \$USER"
echo "• 启动Docker: sudo systemctl start docker"
echo

exit $FAIL