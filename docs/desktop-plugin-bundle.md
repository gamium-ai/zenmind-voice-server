# ZenMind Desktop 插件产物

这份说明对应 `zenmind-voice-server` 当前 release bundle 的 Desktop 集成形态。

Desktop mode:

- kind: `plugin`
- frontend.mode: `embedded`
- backend.entry: `backend/voice-server`
- web.routePath: `/`
- web.portEnvKey: `SERVER_PORT`
- web.defaultPort: `11953`

Bundle contents:

- top-level dir: `zenmind-voice-server`
- darwin/linux requiredPaths: `manifest.json`、`deploy.sh`、`start.sh`、`stop.sh`、`.env.example`、`README.txt`、`backend/voice-server`、`scripts/program-common.sh`
- windows requiredPaths: `manifest.json`、`deploy.ps1`、`start.ps1`、`stop.ps1`、`.env.example`、`README.txt`、`backend/voice-server.exe`、`scripts/program-common.ps1`
- config templates: `.env.example` -> `.env`

Scripts:

- darwin/linux start: `["start.sh", "--daemon"]`
- darwin/linux stop: `stop.sh`
- darwin/linux deploy: `deploy.sh`
- windows start: `["start.ps1", "--daemon"]`
- windows stop: `stop.ps1`
- windows deploy: `deploy.ps1`

Runtime notes:

- macOS bundle 产物名：`zenmind-voice-server-vX.Y.Z-darwin-<arch>.tar.gz`
- Linux bundle 产物名：`zenmind-voice-server-vX.Y.Z-linux-<arch>.tar.gz`
- Windows bundle 产物名：`zenmind-voice-server-vX.Y.Z-windows-amd64.zip`
- 前端页面、API 和 WebSocket 都由单个 Go 进程直接提供

Artifact path:

- file producer: not applicable
- publish adapter: not applicable
- reason: `zenmind-voice-server` 只提供实时语音 API 和调试控制台，不向 `agent-platform` / `agent-webclient` 产出统一聊天 artifact

Auth bridge:

- required: no
- desktop changes: none
- frontend message types: none
