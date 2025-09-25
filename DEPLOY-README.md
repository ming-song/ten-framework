# 🚀 一键部署说明

## 快速开始

### 1. 环境检查
```bash
./check-environment.sh
```

### 2. 一键部署
```bash
./deploy-local-asr.sh
```

### 3. 快速部署（经验用户）
```bash
./quick-deploy.sh [端口号]
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `deploy-local-asr.sh` | 完整的一键部署脚本，包含详细检查和提示 |
| `quick-deploy.sh` | 快速部署脚本，适合有经验的用户 |
| `check-environment.sh` | 环境检查脚本，部署前推荐运行 |
| `DEPLOYMENT-GUIDE.md` | 详细的部署指南文档 |

## 支持的服务器

- ✅ Ubuntu 18.04+
- ✅ CentOS 7+
- ✅ Debian 10+
- ✅ 其他支持Docker的Linux发行版

## 服务地址

部署成功后，WebSocket服务地址为：
```
ws://YOUR_SERVER_IP:8765
```

## 测试

使用 `test-websocket-asr-simple.html` 进行功能测试。