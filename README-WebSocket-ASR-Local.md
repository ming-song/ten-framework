# WebSocket本地ASR服务 - 使用指南

## 概述

这是一个完全本地化的WebSocket实时语音识别(ASR)服务，基于TEN框架构建，使用Vosk离线语音识别引擎。

**核心特点：**
- ✅ 完全本地运行，无需互联网连接
- ✅ 不需要任何API密钥
- ✅ Docker容器化部署
- ✅ 支持多客户端并发连接
- ✅ 实时音频流处理
- ✅ WebSocket通信协议

## 快速开始

### 1. 启动服务

```bash
# 方法一：使用启动脚本（推荐）
./start_websocket_asr.sh

# 方法二：手动启动
docker-compose -f docker-compose.websocket-asr-local.yml up -d
```

### 2. 测试服务

1. 在浏览器中打开 `test-websocket-asr-local.html`
2. 点击"连接 WebSocket"按钮
3. 点击"开始录音"开始语音识别测试
4. 对着麦克风说话，观察实时识别结果

## 技术架构

```
客户端 → WebSocket(8765端口) → Vosk离线ASR → 识别结果 → 客户端
```

### 核心组件

1. **WebSocket服务器** (`standalone_websocket_asr.py`)
   - 处理WebSocket连接
   - 管理多客户端会话
   - 音频数据处理

2. **Vosk语音识别引擎**
   - 离线语音识别模型
   - 模型：vosk-model-small-en-us-0.15 (英语)
   - 采样率：16000Hz

3. **Docker容器化**
   - Ubuntu 22.04基础镜像
   - 自动下载和配置Vosk模型
   - 端口8765对外提供服务

## API协议

### WebSocket连接
```
WebSocket URL: ws://localhost:8765
```

### 消息格式

#### 1. 连接响应
```json
{
    "type": "connection",
    "status": "connected",
    "sample_rate": 16000,
    "message": "WebSocket ASR Local Service Ready"
}
```

#### 2. 音频数据（二进制）
发送PCM格式的音频数据：
```javascript
// 发送16位PCM音频数据
websocket.send(pcmAudioBuffer);
```

#### 3. ASR识别结果
```json
{
    "type": "asr_result",
    "text": "识别的文本内容",
    "is_final": true,  // true=最终结果, false=部分结果
    "confidence": 0.95
}
```

#### 4. 控制命令
```json
// 重置识别器
{
    "type": "reset"
}

// 心跳检测
{
    "type": "ping"
}
```

#### 5. 命令响应
```json
{
    "type": "command_response",
    "command": "reset",
    "status": "success"
}
```

## 管理命令

### 查看服务状态
```bash
docker ps | grep websocket-asr-local
```

### 查看服务日志
```bash
docker logs websocket-asr-local
```

### 停止服务
```bash
docker-compose -f docker-compose.websocket-asr-local.yml down
```

### 重启服务
```bash
docker-compose -f docker-compose.websocket-asr-local.yml restart
```

### 重新构建
```bash
docker-compose -f docker-compose.websocket-asr-local.yml build --no-cache
```

## 自定义配置

### 更换语言模型

1. 下载其他Vosk模型（如中文模型）：
```bash
# 下载中文模型
wget https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip
```

2. 修改Dockerfile中的模型下载部分：
```dockerfile
RUN mkdir -p models && \
    cd models && \
    wget https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip && \
    unzip vosk-model-small-cn-0.22.zip && \
    rm vosk-model-small-cn-0.22.zip
```

3. 更新环境变量：
```dockerfile
ENV MODEL_PATH=models/vosk-model-small-cn-0.22
```

### 更改端口

修改docker-compose.yml中的端口映射：
```yaml
ports:
  - "9999:8765"  # 将服务映射到9999端口
```

### 调整采样率

修改Dockerfile中的环境变量：
```dockerfile
ENV SAMPLE_RATE=8000  # 改为8000Hz
```

## 故障排除

### 常见问题

1. **容器无法启动**
   ```bash
   # 检查Docker是否运行
   docker info

   # 查看详细错误信息
   docker logs websocket-asr-local
   ```

2. **WebSocket连接失败**
   ```bash
   # 检查端口是否被占用
   netstat -tlnp | grep 8765

   # 检查防火墙设置
   sudo ufw status
   ```

3. **音频识别不准确**
   - 确保麦克风正常工作
   - 检查音频采样率设置(16000Hz)
   - 尝试在安静环境中测试

4. **模型下载失败**
   - 检查网络连接
   - 手动下载模型文件并放入容器

### 性能优化

1. **内存优化**
   - 使用小型模型(small)而非大型模型
   - 限制并发连接数

2. **CPU优化**
   - 在多核服务器上运行
   - 考虑使用GPU加速版本

## 开发扩展

### 添加新功能

1. **支持多语言切换**
2. **添加实时语音端点检测**
3. **集成语音转文字后处理**
4. **添加语音活动检测(VAD)**

### 代码结构

```
├── standalone_websocket_asr.py    # 主服务文件
├── Dockerfile.websocket-asr-local # Docker构建文件
├── docker-compose.websocket-asr-local.yml # 服务编排
├── test-websocket-asr-local.html  # 测试客户端
└── start_websocket_asr.sh        # 启动脚本
```

## 许可证

本项目基于Apache License 2.0开源协议。

## 支持与反馈

如果您遇到问题或有改进建议，请通过以下方式联系：

- 查看日志文件获取详细错误信息
- 检查Docker和系统资源使用情况
- 确保音频设备正常工作

---

**注意**: 这是一个本地ASR服务，所有语音数据都在本地处理，不会上传到任何外部服务器，完全保护您的隐私。