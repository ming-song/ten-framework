#
# This file is part of TEN Framework, an open source project.
# Licensed under the Apache License, Version 2.0.
# See the LICENSE file for more information.
#
from ten_runtime import App, TenEnv


class WebSocketASRLocalApp(App):
    def on_configure(self, ten_env: TenEnv) -> None:
        print("WebSocket ASR Local App on_configure")
        ten_env.init_property_from_json('{}')
        ten_env.on_configure_done()


if __name__ == "__main__":
    print("Starting WebSocket ASR Local App...")
    app = WebSocketASRLocalApp()
    app.run(False)
    print("WebSocket ASR Local App completed.")