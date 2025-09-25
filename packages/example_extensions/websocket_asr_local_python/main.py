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
from ten_runtime import (
    Addon,
    AsyncExtension,
    register_addon_as_extension,
    TenEnv,
    Cmd,
    CmdResult,
    StatusCode,
    AsyncTenEnv,
    LogLevel,
    Data,
)


class WebSocketASRLocalExtension(AsyncExtension):
    def __init__(self, name: str) -> None:
        super().__init__(name)
        self.name = name
        self.server = None
        self.model = None
        self.recognizers = {}  # Store recognizers per client

    async def on_init(self, ten_env: AsyncTenEnv) -> None:
        self.ten_env = ten_env

        # Get configuration from properties
        self.server_port, err = await ten_env.get_property_int("server_port")
        if err is not None:
            ten_env.log(LogLevel.ERROR, f"Could not read 'server_port' from properties: {err}")
            self.server_port = 8765

        self.model_path, err = await ten_env.get_property_string("model_path")
        if err is not None:
            ten_env.log(LogLevel.ERROR, f"Could not read 'model_path' from properties: {err}")
            self.model_path = "models/vosk-model-small-en-us-0.15"

        self.sample_rate, err = await ten_env.get_property_int("sample_rate")
        if err is not None:
            ten_env.log(LogLevel.ERROR, f"Could not read 'sample_rate' from properties: {err}")
            self.sample_rate = 16000

        # Initialize Vosk model
        try:
            if not os.path.exists(self.model_path):
                ten_env.log(LogLevel.ERROR, f"Model path does not exist: {self.model_path}")
                raise FileNotFoundError(f"Model path does not exist: {self.model_path}")

            vosk.SetLogLevel(-1)  # Disable Vosk logging
            self.model = vosk.Model(self.model_path)
            ten_env.log(LogLevel.INFO, f"Vosk model loaded successfully from: {self.model_path}")
        except Exception as e:
            ten_env.log(LogLevel.ERROR, f"Failed to load Vosk model: {e}")
            raise e

    async def on_start(self, ten_env: AsyncTenEnv) -> None:
        ten_env.log(LogLevel.DEBUG, "Starting WebSocket ASR Local Extension")

        # Start WebSocket server
        try:
            self.server = await websockets.serve(
                self.handle_websocket_connection,
                "0.0.0.0",
                self.server_port
            )
            ten_env.log(LogLevel.INFO, f"WebSocket ASR server started on port {self.server_port}")
        except Exception as e:
            ten_env.log(LogLevel.ERROR, f"Failed to start WebSocket server: {e}")
            raise e

    async def handle_websocket_connection(self, websocket, path):
        """Handle new WebSocket connection"""
        client_id = id(websocket)
        self.ten_env.log(LogLevel.INFO, f"New WebSocket client connected: {client_id}")

        # Create a new recognizer for this client
        recognizer = vosk.KaldiRecognizer(self.model, self.sample_rate)
        self.recognizers[client_id] = recognizer

        try:
            # Send welcome message
            welcome_msg = {
                "type": "connection",
                "status": "connected",
                "sample_rate": self.sample_rate,
                "message": "WebSocket ASR Local Service Ready"
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
                    self.ten_env.log(LogLevel.ERROR, f"Error processing message from client {client_id}: {e}")
                    error_msg = {
                        "type": "error",
                        "message": str(e)
                    }
                    await websocket.send(json.dumps(error_msg))

        except websockets.exceptions.ConnectionClosed:
            self.ten_env.log(LogLevel.INFO, f"Client {client_id} disconnected")
        except Exception as e:
            self.ten_env.log(LogLevel.ERROR, f"Error handling client {client_id}: {e}")
        finally:
            # Clean up recognizer
            if client_id in self.recognizers:
                del self.recognizers[client_id]

    async def process_audio_data(self, websocket, client_id, audio_data):
        """Process incoming audio data"""
        recognizer = self.recognizers.get(client_id)
        if not recognizer:
            return

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
                        "confidence": result.get("confidence", 0.0)
                    }
                    await websocket.send(json.dumps(response))

                    # Send data to TEN framework
                    await self.send_asr_result_to_ten(response)
            else:
                # Partial result
                partial_result = json.loads(recognizer.PartialResult())
                if partial_result.get("partial", "").strip():
                    response = {
                        "type": "asr_result",
                        "text": partial_result["partial"],
                        "is_final": False,
                        "confidence": 0.0
                    }
                    await websocket.send(json.dumps(response))

        except Exception as e:
            self.ten_env.log(LogLevel.ERROR, f"Error processing audio data: {e}")

    async def process_text_command(self, websocket, client_id, message):
        """Process text commands from client"""
        try:
            command = json.loads(message)
            command_type = command.get("type", "")

            if command_type == "reset":
                # Reset recognizer
                recognizer = vosk.KaldiRecognizer(self.model, self.sample_rate)
                self.recognizers[client_id] = recognizer

                response = {
                    "type": "command_response",
                    "command": "reset",
                    "status": "success"
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

    async def send_asr_result_to_ten(self, result):
        """Send ASR result to TEN framework"""
        try:
            data = Data.create("asr_result")
            data.set_property("text", result["text"])
            data.set_property("is_final", result["is_final"])
            data.set_property("confidence", result["confidence"])

            await self.ten_env.send_data(data)

        except Exception as e:
            self.ten_env.log(LogLevel.ERROR, f"Error sending ASR result to TEN: {e}")

    async def on_deinit(self, ten_env: AsyncTenEnv) -> None:
        ten_env.log(LogLevel.DEBUG, "Deinitializing WebSocket ASR Local Extension")

        # Clean up recognizers
        self.recognizers.clear()

    async def on_cmd(self, ten_env: AsyncTenEnv, cmd: Cmd) -> None:
        ten_env.log(LogLevel.DEBUG, "Received command")

        # Not supported command.
        await ten_env.return_result(CmdResult.create(StatusCode.ERROR, cmd))

    async def on_stop(self, ten_env: AsyncTenEnv) -> None:
        ten_env.log(LogLevel.DEBUG, "Stopping WebSocket ASR Local Extension")

        if self.server:
            self.server.close()
            await self.server.wait_closed()


@register_addon_as_extension("websocket_asr_local_python")
class WebSocketASRLocalAddon(Addon):
    def on_create_instance(
        self, ten_env: TenEnv, name: str, context: object
    ) -> None:
        print("Creating WebSocket ASR Local Extension instance")
        ten_env.on_create_instance_done(WebSocketASRLocalExtension(name), context)