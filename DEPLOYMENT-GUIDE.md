# 本地WebSocket ASR服务部署指南

## 📋 概述

本指南提供了在服务器上一键部署完全本地化的WebSocket ASR（自动语音识别）服务的详细步骤。该服务使用Vosk离线语音识别引擎，支持中英文识别，无需任何API密钥。

## 🏗️ 系统架构

```
客户端浏览器 ←→ WebSocket (端口8765) ←→ Docker容器 ←→ Vosk语音识别引擎
                                            ↓
                                        本地语音模型
                                        • 中文: vosk-model-small-cn-0.22
                                        • 英文: vosk-model-small-en-us-0.15
```

## 🔧 系统要求

### 最低配置
- **操作系统**: Ubuntu 18.04+ / CentOS 7+ / 其他Linux发行版
- **内存**: 4GB RAM (推荐8GB+)
- **存储**: 2GB可用空间
- **网络**: 能够访问外网下载模型文件

### 推荐配置（适用于V100服务器）
- **操作系统**: Ubuntu 20.04+
- **内存**: 16GB+ RAM
- **存储**: 10GB+ 可用空间
- **GPU**: NVIDIA V100 (可选，用于模型加速)

### 必需软件
- Docker 20.10+
- Docker Compose 2.0+ (集成在Docker中) 或 docker-compose 1.29+
- Git 2.0+
- wget
- unzip

## 🚀 快速部署

### 1. 克隆项目代码

```bash
git clone <your-repository-url>
cd ten-framework
```

### 2. 一键部署

```bash
# 给部署脚本执行权限
chmod +x deploy-local-asr.sh

# 执行一键部署脚本
./deploy-local-asr.sh
```

### 3. 验证部署

部署完成后，脚本会显示服务信息：

```
===============================================
✅ WebSocket ASR服务部署完成!
===============================================

🚀 服务信息:
  • WebSocket地址: ws://YOUR_SERVER_IP:8765
  • 容器名称: websocket-asr-local
  • 支持语言: 中文 (cn) / 英文 (en)
  • 识别模式: 手动切换
```

## 🔍 部署步骤详解

### 优化的零停机部署流程

本部署方案专为最小化服务中断时间而设计，特别适合V100服务器等生产环境：

#### 阶段1: 系统环境检查
脚本会自动检查以下组件：
- Docker 服务状态
- Docker Compose 可用性
- 端口8765是否被占用
- 必要的系统命令

#### 阶段2: 部署状态评估
- 检测现有容器运行状态
- 识别是否为更新部署或全新部署
- 准备无缝切换策略

#### 阶段3: 模型文件准备（关键优化）
**在停止任何服务之前**，优先完成模型文件的下载和验证：
- **中文模型Small**: vosk-model-small-cn-0.22 (~170MB)
- **中文模型Standard**: vosk-model-cn-0.22 (~1.8GB) - V100服务器推荐
- **英文模型Small**: vosk-model-small-en-us-0.15 (~40MB)

这确保了大文件下载不会在服务切换期间造成长时间中断。

#### 阶段4: 快速容器切换
模型文件就绪后，执行最小化停机的容器切换：
- 快速停止旧容器
- 清理旧镜像资源
- 准备新部署环境

#### 阶段5: 镜像构建和服务启动
- 快速构建Docker镜像（无需等待模型下载）
- 立即启动新服务容器
- 自动挂载准备好的模型文件

#### 阶段6: 验证和优化
- 服务健康检查和状态验证
- 显示部署信息和管理命令
- 可选的资源清理优化

## 🎦 效果对比

### 传统部署流程
```
停止服务 → 下载模型(1.8GB) → 构建镜像 → 启动服务
服务不可用时间：5-15分钟（取决于网络速度）
```

### 优化后部署流程
```
下载模型(1.8GB) → 快速切换 → 构建镜像 → 启动服务
服务不可用时间：30秒-2分钟（主要为镜像构建时间）
```

### 更新部署（模型已存在）
```
检查模型(跳过下载) → 快速切换 → 构建镜像 → 启动服务
服务不可用时间：30秒-1分钟（几乎零停机）
```

### 性能优势
- ✅ **服务可用性提升**: 80-90%的中断时间减少
- ✅ **V100服务器适配**: 充分利用高性能网络和存储
- ✅ **模型复用**: 避免重复下载1.8GB模型文件
- ✅ **热更新支持**: 代码更新无需重下载模型

## 🧪 测试验证

### 方式1: 使用测试页面

1. **本地测试**（如果有桌面环境）：
   ```bash
   # 在浏览器中打开
   file:///path/to/ten-framework/test-websocket-asr-simple.html
   ```

2. **远程测试**：
   ```bash
   # 将测试页面复制到客户端
   scp test-websocket-asr-simple.html user@client-machine:~/

   # 在客户端浏览器中打开该文件
   # 设置服务器地址为: ws://YOUR_SERVER_IP:8765
   ```

### 方式2: 命令行测试

```bash
# 安装WebSocket客户端工具
pip install websocket-client

# 创建测试脚本
cat > test_websocket.py << 'EOF'
import websocket
import json

def on_message(ws, message):
    print(f"收到消息: {message}")

def on_open(ws):
    print("WebSocket连接已建立")
    # 切换到中文模式
    ws.send(json.dumps({"command": "switch_language", "language": "cn"}))

ws = websocket.WebSocketApp("ws://localhost:8765",
                          on_open=on_open,
                          on_message=on_message)
ws.run_forever()
EOF

# 运行测试
python test_websocket.py
```

## 🛠️ 管理操作

### 查看服务状态
```bash
# 优先使用新版docker compose
docker compose -f docker-compose.websocket-asr-local.yml ps

# 或者使用legacy版本
docker-compose -f docker-compose.websocket-asr-local.yml ps
```

### 查看服务日志
```bash
# 查看最新日志
docker compose -f docker-compose.websocket-asr-local.yml logs

# 实时跟踪日志
docker compose -f docker-compose.websocket-asr-local.yml logs -f

# 查看最近20行日志
docker compose -f docker-compose.websocket-asr-local.yml logs --tail=20

# 如果使用legacy版本，将docker compose替换为docker-compose
```

### 重启服务
```bash
docker compose -f docker-compose.websocket-asr-local.yml restart
```

### 停止服务
```bash
docker compose -f docker-compose.websocket-asr-local.yml down
```

### 清理旧部署
```bash
# 使用清理工具（推荐）
./cleanup-asr.sh

# 或手动清理
docker stop websocket-asr-local
docker rm websocket-asr-local
docker rmi ten-framework/websocket-asr-local
```

### 完全清理
```bash
# 使用交互式清理工具
./cleanup-asr.sh

# 或手动彻底清理
# 停止并删除容器
docker compose -f docker-compose.websocket-asr-local.yml down

# 删除镜像
docker rmi ten-framework/websocket-asr-local

# 清理无用镜像
docker image prune -f
```

## 🔧 配置自定义

### 修改端口
编辑 `docker-compose.websocket-asr-local.yml`：
```yaml
ports:
  - "YOUR_PORT:8765"  # 修改YOUR_PORT为所需端口
```

### 添加GPU支持
如果服务器有GPU，可以编辑 `docker-compose.websocket-asr-local.yml` 添加GPU支持：
```yaml
services:
  websocket-asr:
    # ... 其他配置
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### 使用自定义模型
将自定义Vosk模型放在 `./models/` 目录下，并修改 `standalone_websocket_asr_simple.py` 中的模型路径。

## 🚨 故障排除

### 问题1: 端口被占用
```bash
# 查看端口占用
sudo lsof -i :8765

# 杀死占用进程
sudo kill -9 <PID>
```

### 问题2: Docker权限问题
```bash
# 将当前用户添加到docker组
sudo usermod -aG docker $USER

# 重新登录或执行
newgrp docker
```

### 问题3: 模型下载失败
```bash
# 手动下载模型
cd models
wget https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-cn-0.22.zip
unzip vosk-model-small-en-us-0.15.zip
```

### 问题4: 容器启动失败
```bash
# 查看详细错误日志
docker-compose -f docker-compose.websocket-asr-local.yml logs

# 检查Dockerfile构建
docker build -f Dockerfile.websocket-asr-local -t test-image . --no-cache
```

### 问题5: WebSocket连接失败
1. 检查防火墙设置
2. 确认端口8765已开放
3. 检查服务器IP地址配置
4. 验证容器网络配置

## 📊 性能优化

### 内存优化
- 为容器分配足够内存（推荐4GB+）
- 使用小型模型以减少内存占用
- 定期清理Docker缓存

### CPU优化
- 在多核服务器上可以运行多个实例
- 使用负载均衡分发请求

### 网络优化
- 使用CDN分发模型文件
- 配置适当的WebSocket超时设置

## 🔐 安全考虑

### 网络安全
- 使用防火墙限制8765端口访问
- 考虑使用WSS（WebSocket Secure）
- 实施IP白名单机制

### 容器安全
- 定期更新基础镜像
- 使用非root用户运行容器
- 限制容器资源使用

## 📝 API接口说明

### WebSocket连接
```
ws://YOUR_SERVER_IP:8765
```

### 支持的命令

#### 1. 切换语言
```json
{
  "command": "switch_language",
  "language": "cn"  // 或 "en"
}
```

#### 2. 重置会话
```json
{
  "command": "reset"
}
```

### 返回消息格式

#### 部分识别结果
```json
{
  "is_final": false,
  "mode": "vosk-model-small-cn-0.22",
  "text": "你好世界",
  "wav_name": "h5",
  "language": "cn",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### 最终识别结果
```json
{
  "is_final": true,
  "mode": "vosk-model-small-cn-0.22",
  "text": "你好世界，这是最终结果",
  "wav_name": "h5",
  "language": "cn",
  "timestamp": "2024-01-15T10:30:05Z"
}
```

## 📞 技术支持

如有问题，请：
1. 查看服务日志进行初步诊断
2. 检查本文档的故障排除部分
3. 提交Issue时请包含：
   - 错误日志
   - 系统信息
   - 复现步骤

---

## 📄 更新日志

### v1.0.0 (2024-01-15)
- 初始版本发布
- 支持中英文语音识别
- 提供一键部署脚本
- 包含完整的测试页面

---

**作者**: Songm
**更新时间**: 2024-01-15
**许可证**: 请参考项目根目录的LICENSE文件