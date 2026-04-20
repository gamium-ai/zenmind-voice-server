# CLAUDE.md

## 1. 项目概览

`zenmind-voice-server` 是一个统一语音服务仓库，提供实时 ASR、文本 TTS，以及 ASR -> LLM -> TTS 的 QA 闭环能力。

外层接口契约固定为：

- `GET /api/voice/capabilities`
- `GET /api/voice/tts/voices`
- `GET /api/voice/ws`
- `GET /actuator/health`
- `GET /`

## 2. 技术栈

- 后端：Go 1.26、`net/http`、`gorilla/websocket`
- 前端：React 18、TypeScript、Vite
- 发布：原生 Go 交叉编译 + `go:embed`

## 3. 架构设计

- 单个 Go 进程同时提供 API、WebSocket 和前端静态文件
- backend 暴露唯一业务前缀 `/api/voice/*`
- 前端调试台只用于调试，不改变外层语音 API 路由契约
- QA 模式依赖外部 runner SSE

## 4. 目录结构

- `Makefile`：根目录统一开发命令入口
- `VERSION`：正式发布版本单一来源
- `cmd/voice-server`：服务启动入口
- `internal/httpapi`：REST 接口与嵌入式 UI 托管
- `internal/ws`：WebSocket 协议实现
- `frontend`：调试台源码
- `scripts/release.sh`：版本化 release 打包入口
- `scripts/release-assets/`：离线 bundle 模板资产

## 5. 开发流程

1. `cp .env.example .env`
2. `make build`
3. `./bin/voice-server`
4. `make frontend-dev`
5. `make test`
6. `make release`

## 6. 开发要点

- 默认服务端口由 `SERVER_PORT` 控制
- `make build` / `make run` 会先构建前端并写入 `internal/httpapi/ui/`
- 对外路径只维护 `/api/voice/*`
- 当前版本未内建业务鉴权，接入方需在网关或部署层控制访问

## 7. 已知约束

- 本轮总控只接入 backend API，不公开额外业务前缀
- 若接入外层网关，不要再在路径层做第二套 voice 业务前缀
