# Vosk语音识别模型

这个目录用于存储Vosk语音识别模型文件。

## 支持的模型

### 中文模型

1. **vosk-model-small-cn-0.22** (轻量版, ~170MB)
   - 适合：快速响应、资源受限环境
   - 下载：`wget https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip`

2. **vosk-model-cn-0.22** (标准版, ~1.8GB)
   - 适合：高精度要求、服务器环境
   - 下载：`wget https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip`

### 英文模型

1. **vosk-model-small-en-us-0.15** (轻量版, ~40MB)
   - 适合：英文语音识别
   - 下载：`wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip`

## 自动下载

运行部署脚本时，模型会自动下载到此目录：

```bash
./deploy-local-asr.sh
```

或手动下载：

```bash
cd models

# 中文轻量版
wget https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip
unzip vosk-model-small-cn-0.22.zip
rm vosk-model-small-cn-0.22.zip

# 中文标准版
wget https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip
unzip vosk-model-cn-0.22.zip
rm vosk-model-cn-0.22.zip

# 英文轻量版
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
rm vosk-model-small-en-us-0.15.zip
```

## 目录结构

下载完成后，目录结构应该如下：

```
models/
├── vosk-model-small-cn-0.22/
│   ├── am/
│   ├── graph/
│   ├── ivector/
│   └── conf/
├── vosk-model-cn-0.22/
│   ├── am/
│   ├── graph/
│   ├── ivector/
│   └── conf/
└── vosk-model-small-en-us-0.15/
    ├── am/
    ├── graph/
    ├── ivector/
    └── conf/
```

## Docker挂载

使用Docker部署时，此目录会被挂载到容器内的`/app/models`路径：

```yaml
volumes:
  - ./models:/app/models:ro
```

## 注意事项

- 模型文件较大，首次下载需要时间和网络带宽
- 建议在V100服务器等高性能环境中使用标准版模型
- 模型文件已在.gitignore中排除，不会提交到版本控制系统