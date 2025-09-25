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

        # 模型名称映射
        self.model_names = {
            'en': 'vosk-model-small-en-us-0.15',
            'cn': 'vosk-model-small-cn-0.22'
        }

        # 英文模型
        try:
            self.models['en'] = vosk.Model("models/vosk-model-small-en-us-0.15")
            print("✓ 英文模型加载成功")
        except Exception as e:
            print(f"❌ 英文模型加载失败: {e}")

        # 中文模型
        try:
            self.models['cn'] = vosk.Model("models/vosk-model-small-cn-0.22")
            print("✓ 中文模型加载成功")
        except Exception as e:
            print(f"❌ 中文模型加载失败: {e}")

        self.client_sessions = {}  # 存储每个客户端的会话信息

    def create_recognizer(self, language='cn'):
        """为指定语言创建识别器"""
        if language in self.models:
            return vosk.KaldiRecognizer(self.models[language], 16000)
        return None

    async def handle_websocket_connection(self, websocket):
        client_id = id(websocket)
        print(f"客户端 {client_id} 已连接")

        # 初始化客户端会话
        self.client_sessions[client_id] = {
            'current_language': 'cn',  # 默认中文
            'recognizer': self.create_recognizer('cn')
        }

        try:
            await websocket.send(json.dumps({
                'type': 'connection_established',
                'message': '简单ASR服务已连接',
                'supported_languages': list(self.models.keys()),
                'current_language': 'cn',
                'mode': 'manual_switch'
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

        if command == 'switch_language':
            language = data.get('language', 'cn')
            if language in self.models:
                session['current_language'] = language
                # 创建新的识别器
                session['recognizer'] = self.create_recognizer(language)

                await websocket.send(json.dumps({
                    'type': 'language_switched',
                    'language': language,
                    'message': f'已切换到{self.get_language_name(language)}识别'
                }))
                print(f"客户端 {client_id} 切换语言: {language}")
            else:
                await websocket.send(json.dumps({
                    'type': 'error',
                    'message': f'不支持的语言: {language}'
                }))

        elif command == 'reset':
            # 重置识别器
            current_lang = session['current_language']
            session['recognizer'] = self.create_recognizer(current_lang)

            await websocket.send(json.dumps({
                'type': 'reset_complete',
                'message': '识别器已重置'
            }))

    async def process_audio_data(self, websocket, client_id, audio_data):
        """处理音频数据 - 单语言识别"""
        session = self.client_sessions[client_id]
        current_lang = session['current_language']
        recognizer = session['recognizer']

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
                        'mode': self.model_names.get(current_lang, current_lang),
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
                        'mode': self.model_names.get(current_lang, current_lang),
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