#!/usr/bin/env python3
"""
简单的测试脚本来验证模型切换逻辑
"""
import asyncio
import websockets
import json

class TestASRService:
    def __init__(self):
        # 模拟模型配置
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
        
        # 模拟所有模型都已加载
        self.models = {name: True for name in self.model_configs.keys()}
        
        # 默认模型
        self.default_model = 'vosk-model-cn-0.22'
        self.client_sessions = {}

    async def handle_websocket_connection(self, websocket):
        client_id = id(websocket)
        print(f"客户端 {client_id} 已连接")

        # 初始化客户端会话
        self.client_sessions[client_id] = {
            'current_model': self.default_model,
            'recognizer': f"mock_recognizer_{self.default_model}"
        }

        try:
            # 发送连接建立消息
            await websocket.send(json.dumps({
                'type': 'connection_established',
                'message': '简单ASR服务已连接',
                'available_models': [{k: v['display_name']} for k, v in self.model_configs.items()],
                'current_model': self.default_model,
                'mode': 'model_selection'
            }))
            
            print(f"向客户端 {client_id} 发送连接建立消息，默认模型: {self.default_model}")

            async for message in websocket:
                try:
                    if isinstance(message, bytes):
                        # 模拟音频数据处理
                        await self.mock_audio_processing(websocket, client_id)
                    else:
                        # 处理文本命令
                        data = json.loads(message)
                        await self.handle_command(websocket, client_id, data)

                except json.JSONDecodeError:
                    await websocket.send(json.dumps({
                        'type': 'error',
                        'message': '无效的JSON格式'
                    }))
                except Exception as e:
                    print(f"处理消息时出错: {e}")

        except websockets.exceptions.ConnectionClosed:
            print(f"客户端 {client_id} 连接已关闭")
        except Exception as e:
            print(f"WebSocket连接错误: {e}")
        finally:
            if client_id in self.client_sessions:
                del self.client_sessions[client_id]
            print(f"客户端 {client_id} 会话已清理")

    async def handle_command(self, websocket, client_id, data):
        command = data.get('command')
        session = self.client_sessions[client_id]

        print(f"客户端 {client_id} 发送命令: {command}, 数据: {data}")

        if command == 'switch_model':
            model_name = data.get('model', self.default_model)
            print(f"客户端 {client_id} 请求切换到模型: {model_name}")
            
            if model_name in self.models:
                old_model = session['current_model']
                session['current_model'] = model_name
                session['recognizer'] = f"mock_recognizer_{model_name}"
                
                config = self.model_configs.get(model_name, {})
                display_name = config.get('display_name', model_name)

                response = {
                    'type': 'model_switched',
                    'model': model_name,
                    'message': f'已切换到{display_name}'
                }
                
                await websocket.send(json.dumps(response))
                print(f"客户端 {client_id} 模型切换成功: {old_model} -> {model_name}")
                print(f"发送响应: {response}")
            else:
                error_response = {
                    'type': 'error',
                    'message': f'不支持的模型: {model_name}'
                }
                await websocket.send(json.dumps(error_response))
                print(f"客户端 {client_id} 模型切换失败: 不支持的模型 {model_name}")

        elif command == 'reset':
            current_model = session['current_model']
            session['recognizer'] = f"mock_recognizer_{current_model}"

            response = {
                'type': 'reset_complete',
                'message': '识别器已重置'
            }
            await websocket.send(json.dumps(response))
            print(f"客户端 {client_id} 重置完成")

    async def mock_audio_processing(self, websocket, client_id):
        """模拟音频处理"""
        session = self.client_sessions[client_id]
        current_model = session['current_model']
        current_lang = self.model_configs[current_model]['language']
        
        # 模拟返回识别结果
        if current_lang == 'cn':
            test_text = "你好，这是中文识别测试"
        else:
            test_text = "Hello, this is English recognition test"
            
        await websocket.send(json.dumps({
            'is_final': True,
            'mode': current_model,
            'text': test_text,
            'wav_name': 'test',
            'language': current_lang,
            'timestamp': 1234567890
        }))

async def main():
    service = TestASRService()
    
    print("启动测试ASR服务器...")
    print(f"默认模型: {service.default_model}")
    print("可用模型:")
    for name, config in service.model_configs.items():
        print(f"  - {name}: {config['display_name']}")
    
    async with websockets.serve(service.handle_websocket_connection, "localhost", 8766):
        print("服务器运行在 ws://localhost:8766")
        await asyncio.Future()  # 永远运行

if __name__ == "__main__":
    asyncio.run(main())