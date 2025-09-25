#
# This file is part of TEN Framework, an open source project.
# Licensed under the Apache License, Version 2.0.
# See the LICENSE file for more information.
#
import asyncio
import json
import os
import websockets
import vosk
import wave
import numpy as np
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class WebSocketASRLocalService:
    def __init__(self, config):
        self.config = config
        self.models = {}  # Store multiple language models
        self.recognizers = {}  # Store recognizers per client
        self.current_language = config.get('default_language', 'cn')  # Default to Chinese
        
    async def initialize(self):
        """Initialize Vosk models for multiple languages"""
        try:
            # Initialize Chinese model
            model_path_cn = self.config.get('model_path_cn')
            if model_path_cn and os.path.exists(model_path_cn):
                vosk.SetLogLevel(-1)  # Disable Vosk logging
                self.models['cn'] = vosk.Model(model_path_cn)
                logger.info(f"Chinese Vosk model loaded successfully from: {model_path_cn}")
            else:
                logger.warning(f"Chinese model path does not exist: {model_path_cn}")
                
            # Initialize English model
            model_path_en = self.config.get('model_path_en')
            if model_path_en and os.path.exists(model_path_en):
                self.models['en'] = vosk.Model(model_path_en)
                logger.info(f"English Vosk model loaded successfully from: {model_path_en}")
            else:
                logger.warning(f"English model path does not exist: {model_path_en}")
                
            if not self.models:
                raise FileNotFoundError("No valid models found")
                
            # Set default model if current language not available
            if self.current_language not in self.models:
                self.current_language = list(self.models.keys())[0]
                logger.info(f"Default language not available, using: {self.current_language}")
                
            logger.info(f"Available languages: {list(self.models.keys())}")
            logger.info(f"Current language: {self.current_language}")
            
        except Exception as e:
            logger.error(f"Failed to load Vosk models: {e}")
            raise e

    async def start_server(self):
        """Start WebSocket server"""
        try:
            server = await websockets.serve(
                self.handle_websocket_connection,
                "0.0.0.0",
                self.config['server_port']
            )
            logger.info(f"WebSocket ASR server started on port {self.config['server_port']}")
            return server
        except Exception as e:
            logger.error(f"Failed to start WebSocket server: {e}")
            raise e

    async def handle_websocket_connection(self, websocket):
        """Handle new WebSocket connection"""
        client_id = id(websocket)
        logger.info(f"New WebSocket client connected: {client_id}")
        
        # Create a new recognizer for this client using current language model
        current_model = self.models[self.current_language]
        recognizer = vosk.KaldiRecognizer(current_model, self.config['sample_rate'])
        self.recognizers[client_id] = {
            'recognizer': recognizer,
            'language': self.current_language
        }
        
        try:
            # Send welcome message with available languages
            welcome_msg = {
                "type": "connection",
                "status": "connected",
                "sample_rate": self.config['sample_rate'],
                "current_language": self.current_language,
                "available_languages": list(self.models.keys()),
                "message": f"WebSocket ASR Local Service Ready - Current Language: {self.current_language}"
            }
            await websocket.send(json.dumps(welcome_msg))
            
            async for message in websocket:
                try:
                    if isinstance(message, bytes):
                        # Handle binary audio data
                        await self.process_audio_data(websocket, client_id, message)
                    else:
                        # Handle text commands
                        await self.process_text_command(websocket, client_id, message)
                        
                except Exception as e:
                    logger.error(f"Error processing message from client {client_id}: {e}")
                    error_msg = {
                        "type": "error",
                        "message": str(e)
                    }
                    await websocket.send(json.dumps(error_msg))
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"Client {client_id} disconnected")
        except Exception as e:
            logger.error(f"Error handling client {client_id}: {e}")
        finally:
            # Clean up recognizer
            if client_id in self.recognizers:
                del self.recognizers[client_id]

    async def process_audio_data(self, websocket, client_id, audio_data):
        """Process incoming audio data"""
        recognizer_info = self.recognizers.get(client_id)
        if not recognizer_info:
            return
            
        recognizer = recognizer_info['recognizer']
        
        try:
            # Process audio with Vosk
            if recognizer.AcceptWaveform(audio_data):
                # Final result
                result = json.loads(recognizer.Result())
                if result.get("text", "").strip():
                    response = {
                        "type": "asr_result",
                        "text": result["text"],
                        "is_final": True,
                        "confidence": result.get("confidence", 0.0),
                        "language": recognizer_info['language']
                    }
                    await websocket.send(json.dumps(response))
                    logger.info(f"Final result ({recognizer_info['language']}): {result['text']}")
            else:
                # Partial result
                partial_result = json.loads(recognizer.PartialResult())
                if partial_result.get("partial", "").strip():
                    response = {
                        "type": "asr_result",
                        "text": partial_result["partial"],
                        "is_final": False,
                        "confidence": 0.0,
                        "language": recognizer_info['language']
                    }
                    await websocket.send(json.dumps(response))
                    
        except Exception as e:
            logger.error(f"Error processing audio data: {e}")

    async def process_text_command(self, websocket, client_id, message):
        """Process text commands from client"""
        try:
            command = json.loads(message)
            command_type = command.get("type", "")
            
            if command_type == "switch_language":
                # Switch language model
                new_language = command.get("language", "")
                if new_language in self.models:
                    # Update current language for new connections
                    self.current_language = new_language
                    
                    # Update this client's recognizer
                    new_model = self.models[new_language]
                    new_recognizer = vosk.KaldiRecognizer(new_model, self.config['sample_rate'])
                    self.recognizers[client_id] = {
                        'recognizer': new_recognizer,
                        'language': new_language
                    }
                    
                    response = {
                        "type": "command_response",
                        "command": "switch_language",
                        "status": "success",
                        "language": new_language,
                        "message": f"Switched to {new_language} model"
                    }
                    logger.info(f"Client {client_id} switched to {new_language} model")
                else:
                    response = {
                        "type": "command_response",
                        "command": "switch_language",
                        "status": "error",
                        "message": f"Language '{new_language}' not available. Available: {list(self.models.keys())}"
                    }
                await websocket.send(json.dumps(response))
                
            elif command_type == "reset":
                # Reset recognizer with current language
                recognizer_info = self.recognizers.get(client_id)
                if recognizer_info:
                    current_lang = recognizer_info['language']
                    current_model = self.models[current_lang]
                    new_recognizer = vosk.KaldiRecognizer(current_model, self.config['sample_rate'])
                    self.recognizers[client_id] = {
                        'recognizer': new_recognizer,
                        'language': current_lang
                    }
                
                response = {
                    "type": "command_response",
                    "command": "reset",
                    "status": "success"
                }
                await websocket.send(json.dumps(response))
                logger.info(f"Reset recognizer for client {client_id}")
                
            elif command_type == "get_languages":
                # Get available languages
                response = {
                    "type": "command_response",
                    "command": "get_languages",
                    "status": "success",
                    "current_language": self.current_language,
                    "available_languages": list(self.models.keys())
                }
                await websocket.send(json.dumps(response))
                
            elif command_type == "ping":
                # Ping pong
                response = {
                    "type": "command_response",
                    "command": "ping",
                    "status": "pong"
                }
                await websocket.send(json.dumps(response))
                
        except json.JSONDecodeError:
            error_msg = {
                "type": "error",
                "message": "Invalid JSON command"
            }
            await websocket.send(json.dumps(error_msg))


async def main():
    # Configuration
    config = {
        "server_port": int(os.getenv("SERVER_PORT", "8765")),
        "model_path_cn": os.getenv("MODEL_PATH_CN", "models/vosk-model-small-cn-0.22"),
        "model_path_en": os.getenv("MODEL_PATH_EN", "models/vosk-model-small-en-us-0.15"),
        "sample_rate": int(os.getenv("SAMPLE_RATE", "16000")),
        "default_language": os.getenv("DEFAULT_LANGUAGE", "cn"),
    }
    
    logger.info(f"Starting WebSocket ASR Local Service with config: {config}")
    
    # Create and initialize service
    service = WebSocketASRLocalService(config)
    await service.initialize()
    
    # Start server
    server = await service.start_server()
    
    logger.info("WebSocket ASR Local Service is running. Press Ctrl+C to stop.")
    
    # Keep running
    try:
        await server.wait_closed()
    except KeyboardInterrupt:
        logger.info("Shutting down WebSocket ASR Local Service...")
        server.close()
        await server.wait_closed()


if __name__ == "__main__":
    asyncio.run(main())