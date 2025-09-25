# WebSocket ASR Local Python Extension

一个完全本地化的WebSocket实时ASR服务扩展，使用Vosk离线语音识别，无需任何API密钥。

## 特性

- **完全离线**: 使用Vosk离线语音识别模型，无需互联网连接
- **实时处理**: WebSocket实时音频流处理
- **多客户端支持**: 支持多个WebSocket客户端同时连接
- **无API密钥**: 完全本地运行，不依赖任何第三方API
- **Docker容器化**: 支持完全容器化部署

## 架构

```
Client → WebSocket → Vosk ASR → TEN Framework → Response
```

## 配置参数

- `server_port`: WebSocket服务器端口 (默认: 8765)
- `model_path`: Vosk模型路径 (默认: "models/vosk-model-small-en-us-0.15")
- `sample_rate`: 音频采样率 (默认: 16000)
- `audio_format`: 音频格式 (默认: "pcm")
- `channels`: 音频声道数 (默认: 1)

## WebSocket协议

### 客户端发送音频数据
```javascript
// 发送二进制音频数据 (PCM格式)
websocket.send(audioBuffer);
```

### 客户端发送命令
```javascript
// 重置识别器
websocket.send(JSON.stringify({
    "type": "reset"
}));

// Ping测试
websocket.send(JSON.stringify({
    "type": "ping"
}));
```

### 服务器响应格式
```json
{
    "type": "asr_result",
    "text": "识别的文本内容",
    "is_final": true,
    "confidence": 0.95
}
```

## 使用示例

### HTML5客户端示例
```html
<!DOCTYPE html>
<html>
<head>
    <title>WebSocket ASR 测试</title>
</head>
<body>
    <button id="startBtn">开始录音</button>
    <button id="stopBtn">停止录音</button>
    <div id="results"></div>

    <script>
        const ws = new WebSocket('ws://localhost:8765');
        let mediaRecorder;
        let audioContext;

        ws.onopen = function() {
            console.log('WebSocket连接已建立');
        };

        ws.onmessage = function(event) {
            const data = JSON.parse(event.data);
            if (data.type === 'asr_result') {
                const results = document.getElementById('results');
                results.innerHTML += `<p>${data.text} (final: ${data.is_final})</p>`;
            }
        };

        document.getElementById('startBtn').onclick = async function() {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            audioContext = new AudioContext({ sampleRate: 16000 });

            mediaRecorder = new MediaRecorder(stream);
            mediaRecorder.ondataavailable = function(event) {
                if (event.data.size > 0) {
                    event.data.arrayBuffer().then(buffer => {
                        ws.send(buffer);
                    });
                }
            };

            mediaRecorder.start(100); // 每100ms发送一次数据
        };

        document.getElementById('stopBtn').onclick = function() {
            if (mediaRecorder) {
                mediaRecorder.stop();
            }
        };
    </script>
</body>
</html>
```

## 安装和部署

### 前置条件
1. 下载Vosk模型文件
2. Python 3.8+
3. Docker (可选)

### 本地安装
```bash
# 安装依赖
pip install -r requirements.txt

# 下载Vosk模型
mkdir -p models
cd models
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
```

### Docker部署
参见项目根目录的Docker配置文件。

## 模型支持

支持所有Vosk官方模型：
- 英语: vosk-model-small-en-us-0.15 (约40MB)
- 中文: vosk-model-small-cn-0.22 (约42MB)
- 其他语言模型: https://alphacephei.com/vosk/models

## 性能优化

- 使用小型模型以降低内存占用
- 支持多客户端并发处理
- 实时音频流处理，低延迟
- 可根据需要调整采样率和缓冲区大小