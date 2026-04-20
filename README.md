# zenmind-voice-server

## 1. 项目简介

这是一个统一语音服务仓库，提供实时 ASR、本地 TTS，以及 ASR -> LLM -> TTS 的 QA 闭环能力。

服务对外只维护一套地址契约：

- `GET /api/voice/capabilities`
- `GET /api/voice/tts/voices`
- `GET /api/voice/ws`
- `GET /actuator/health`
- `GET /`：嵌入式前端调试台

前端静态文件由 Go 二进制通过 `go:embed` 直接托管，不再依赖 nginx 或 Docker Compose。

## 2. 快速开始

### 前置要求

- Go 1.26+
- Node.js 22+ 与 npm

### 本地运行嵌入式服务

```bash
cp .env.example .env
make build
./bin/voice-server
```

默认地址（当 `SERVER_PORT=11953` 时）：

- 页面：`http://localhost:11953/`
- API：`http://localhost:11953/api/voice/capabilities`
- WebSocket：`ws://localhost:11953/api/voice/ws`

### 本地前端调试模式

```bash
cp .env.example .env
make frontend-dev
```

- Vite 地址：`http://localhost:5173`
- Vite 会把 `/api`、`/actuator`、`/api/voice/ws` 代理到根目录 `.env` 中的 `SERVER_PORT`

### 测试

```bash
make test
```

## 3. 构建与发布

### 本地构建

```bash
make build
```

`make build` 会先执行前端构建，把 `frontend/dist` 复制到 `internal/httpapi/ui/`，再编译 `bin/voice-server`。

### 版本化 release

正式版本单一来源是根目录 `VERSION`，格式固定为 `vX.Y.Z`。

```bash
make release
```

默认会产出：

- `dist/release/zenmind-voice-server-vX.Y.Z-darwin-arm64.tar.gz`
- `dist/release/zenmind-voice-server-vX.Y.Z-windows-amd64.zip`

常见用法：

```bash
make release VERSION=v0.1.0
make release VERSION=v0.1.0 ARCH=amd64
make release VERSION=v0.1.0 PROGRAM_TARGETS=windows
make release VERSION=v0.1.0 PROGRAM_TARGET_MATRIX=darwin/arm64,windows/amd64
make release VERSION=v0.1.0 PROGRAM_TARGET_MATRIX=linux/arm64
```

release bundle 内包含：

- 原生 Go 二进制 `backend/voice-server`
- `.env.example`
- `manifest.json`
- `deploy/start/stop` 脚本
- `scripts/program-common.{sh|ps1}`
- `README.txt`

## 4. 配置说明

- 环境变量契约文件：`.env.example`
- 服务使用单端口模式，只保留 `SERVER_PORT`
- 前端、API 和 WebSocket 都由同一个 Go 进程托管
- LLM QA 模式支持由客户端在 `tts.start.agentKey` 中动态指定员工；`APP_VOICE_TTS_LLM_RUNNER_AGENT_KEY` 仅作为默认回退
- ASR 本地音量门限默认开启，可通过 `APP_VOICE_ASR_CLIENT_GATE_*` 调整浏览器侧 RMS 门限、开门/关门保持时长和预缓冲时长

## 5. 部署

离线 bundle 解压后的最小步骤：

```bash
tar -xzf zenmind-voice-server-v0.1.0-darwin-arm64.tar.gz
cd zenmind-voice-server
cp .env.example .env
./deploy.sh
./start.sh --daemon
```

启动后访问：

- `http://127.0.0.1:11953/`

停止服务：

```bash
./stop.sh
```

更多发布细节见 [docs/versioned-release-bundle.md](/Users/ther/project/git/zenmind/zenmind-voice-server/docs/versioned-release-bundle.md)。
