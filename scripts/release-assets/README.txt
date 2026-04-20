zenmind-voice-server - Desktop 插件部署包

本 bundle 可以直接导入 zenmind-desktop，也可以手动解压后运行。仓库级发布流程、版本约束和集成说明请查看源码仓库 README、docs/versioned-release-bundle.md 与 docs/desktop-plugin-bundle.md。

Desktop 使用步骤
================

1. 在 zenmind-desktop 中导入当前平台的插件包：
   - macOS / Linux: `.tar.gz`
   - Windows: `.zip`
2. 在控制中心执行初始化，让 Desktop 生成 `.env` 与运行目录。
3. 按需编辑 `.env` 中的 ASR / TTS / runner 配置。
4. 在控制中心启动插件。
5. 在嵌入页打开语音调试台；默认地址为 `http://127.0.0.1:11953/`。

手动运行步骤
============

macOS / Linux:
1. 复制 `.env.example` 为 `.env`，并填入真实配置。
2. 运行 `./deploy.sh` 完成初始化。
3. 运行 `./start.sh --daemon` 启动服务。
4. 浏览器访问 `http://127.0.0.1:11953/`。
5. 运行 `./stop.sh` 停止服务。

Windows:
1. 复制 `.env.example` 为 `.env`，并填入真实配置。
2. 运行 `powershell -ExecutionPolicy Bypass -File .\deploy.ps1` 完成初始化。
3. 运行 `powershell -ExecutionPolicy Bypass -File .\start.ps1 --daemon` 启动服务。
4. 浏览器访问 `http://127.0.0.1:11953/`。
5. 运行 `powershell -ExecutionPolicy Bypass -File .\stop.ps1` 停止服务。

目录说明
========

manifest.json              - Desktop 插件清单
.env.example               - 环境变量模板
backend/                   - 原生 Go 二进制
deploy.{sh|ps1}            - 初始化脚本
start.{sh|ps1}             - 启动脚本
stop.{sh|ps1}              - 停止脚本
scripts/                   - 运行时 helper
README.txt                 - 本文件

注意事项
========

- 服务使用单端口模式，Web 页面、API 和 WebSocket 都由 `SERVER_PORT` 控制，默认 `11953`。
- release bundle 离线交付的是原生二进制与运行脚本；ASR / TTS / runner 等外部依赖仍需按 `.env` 配置可访问。
