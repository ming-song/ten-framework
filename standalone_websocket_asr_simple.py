#!/usr/bin/env python3
import asyncio
import websockets
import json
import vosk
import time

class SimpleASRService:
    def __init__(self):
        # 加载模型
        self.models = {}
        self.recognizers = {}

        # 模型名称映射和配置
        self.model_configs = {
            'vosk-model-small-en-us-0.15': {
                'path': 'models/vosk-model-small-en-us-0.15',
                'language': 'en',
                'display_name': 'English (US) - Small'
            },
            'vosk-model-small-cn-0.22': {
                'path': 'models/vosk-model-small-cn-0.22',
                'language': 'cn',
                'display_name': '中文 - Small (0.22)'
            },
            'vosk-model-cn-0.22': {
                'path': 'models/vosk-model-cn-0.22',
                'language': 'cn',
                'display_name': '中文 - Standard (0.22)'
            }
        }
        
        # 加载所有可用模型
        for model_name, config in self.model_configs.items():
            try:
                self.models[model_name] = vosk.Model(config['path'])
                print(f"✓ {config['display_name']} 模型加载成功")
            except Exception as e:
                print(f"❌ {config['display_name']} 模型加载失败: {e}")
                
        # 默认模型 - V100服务器推荐使用标准版获得最佳精度
        self.default_model = 'vosk-model-cn-0.22'

        self.client_sessions = {}  # 存储每个客户端的会话信息

    def create_recognizer(self, model_name=None):
        """为指定模型创建识别器"""
        if model_name is None:
            model_name = self.default_model
            
        if model_name in self.models:
            return vosk.KaldiRecognizer(self.models[model_name], 16000)
        return None
        
    def get_model_language(self, model_name):
        """获取模型对应的语言"""
        if model_name in self.model_configs:
            return self.model_configs[model_name]['language']
        return 'cn'  # 默认中文

    async def handle_websocket_connection(self, websocket):
        client_id = id(websocket)
        print(f"客户端 {client_id} 已连接")

        # 初始化客户端会话
        self.client_sessions[client_id] = {
            'current_model': self.default_model,
            'recognizer': self.create_recognizer(self.default_model)
        }

        try:
            await websocket.send(json.dumps({
                'type': 'connection_established',
                'message': '简单ASR服务已连接',
                'available_models': [{k: v['display_name']} for k, v in self.model_configs.items() if k in self.models],
                'current_model': self.default_model,
                'mode': 'model_selection'
            }))

            async for message in websocket:
                try:
                    if isinstance(message, bytes):
                        # 音频数据
                        await self.process_audio_data(websocket, client_id, message)
                    else:
                        # 文本命令
                        data = json.loads(message)
                        await self.handle_command(websocket, client_id, data)

                except json.JSONDecodeError:
                    await websocket.send(json.dumps({
                        'type': 'error',
                        'message': '无效的JSON格式'
                    }))
                except Exception as e:
                    print(f"处理消息时出错: {e}")
                    await websocket.send(json.dumps({
                        'type': 'error',
                        'message': f'处理消息时出错: {str(e)}'
                    }))

        except websockets.exceptions.ConnectionClosed:
            print(f"客户端 {client_id} 连接已关闭")
        except Exception as e:
            print(f"WebSocket连接错误: {e}")
        finally:
            # 清理客户端会话
            if client_id in self.client_sessions:
                del self.client_sessions[client_id]
            print(f"客户端 {client_id} 会话已清理")

    async def handle_command(self, websocket, client_id, data):
        """处理客户端命令"""
        command = data.get('command')
        session = self.client_sessions[client_id]

        if command == 'switch_model':
            model_name = data.get('model', self.default_model)
            if model_name in self.models:
                session['current_model'] = model_name
                # 创建新的识别器
                session['recognizer'] = self.create_recognizer(model_name)
                
                config = self.model_configs.get(model_name, {})
                display_name = config.get('display_name', model_name)

                await websocket.send(json.dumps({
                    'type': 'model_switched',
                    'model': model_name,
                    'message': f'已切换到{display_name}'
                }))
                print(f"客户端 {client_id} 切换模型: {model_name}")
            else:
                await websocket.send(json.dumps({
                    'type': 'error',
                    'message': f'不支持的模型: {model_name}'
                }))

        elif command == 'reset':
            # 重置识别器
            current_model = session['current_model']
            session['recognizer'] = self.create_recognizer(current_model)

            await websocket.send(json.dumps({
                'type': 'reset_complete',
                'message': '识别器已重置'
            }))

    async def process_audio_data(self, websocket, client_id, audio_data):
        """处理音频数据 - 单模型识别"""
        session = self.client_sessions[client_id]
        current_model = session['current_model']
        recognizer = session['recognizer']
        current_lang = self.get_model_language(current_model)

        if not recognizer:
            return

        try:
            if recognizer.AcceptWaveform(audio_data):
                # 完整识别结果
                result = json.loads(recognizer.Result())
                text = result.get('text', '').strip()

                if text:
                    await websocket.send(json.dumps({
                        'is_final': True,
                        'mode': current_model,
                        'text': text,
                        'wav_name': 'h5',
                        'language': current_lang,
                        'timestamp': time.time()
                    }))
            else:
                # 部分识别结果
                partial_result = json.loads(recognizer.PartialResult())
                partial_text = partial_result.get('partial', '').strip()

                if partial_text:
                    await websocket.send(json.dumps({
                        'is_final': False,
                        'mode': current_model,
                        'text': partial_text,
                        'wav_name': 'h5',
                        'language': current_lang
                    }))

        except Exception as e:
            print(f"音频处理错误: {e}")
            await websocket.send(json.dumps({
                'type': 'error',
                'message': f'音频处理错误: {str(e)}'
            }))

    def get_language_name(self, lang_code):
        """获取语言名称"""
        names = {
            'cn': '中文',
            'en': '英文'
        }
        return names.get(lang_code, lang_code)

async def main():
    asr_service = SimpleASRService()

    print("🚀 简单WebSocket ASR服务启动中...")
    print("📍 监听地址: ws://localhost:8765")
    print("🔧 特性:")
    print("   - 手动语言切换")
    print("   - 单语言识别")
    print("   - 简单可靠")
    print("   - 中英文支持")

    async with websockets.serve(asr_service.handle_websocket_connection, "0.0.0.0", 8765):
        print("✅ 简单ASR服务已启动，等待连接...")
        await asyncio.Future()  # 保持服务运行

if __name__ == "__main__":
    asyncio.run(main())