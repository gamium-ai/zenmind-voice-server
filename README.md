# zenmind-voice-server

## 1. 项目简介

这是一个统一语音服务示例仓库，提供实时 ASR、本地 TTS 和 QA 闭环语音对话能力。

外层网关契约已经固定为：

- 业务接口统一走 `/api/voice/*`
- 健康检查走 `/actuator/health`
- 本轮总控只接入 backend API，不公开 voice console 路由

## 2. 快速开始

```bash
cp .env.example .env
go run ./cmd/voice-server
```

默认地址：

- HTTP：`http://localhost:11953`
- WebSocket：`ws://localhost:11953/api/voice/ws`

## 3. 配置说明

- 环境变量契约文件：`.env.example`
- 当前只通过 `.env` / 环境变量注入真实值
- 最重要的部署路径约束是 `/api/voice/*`
- 若由总网关接入，应直接把 `/api/voice/*` 反代到 backend，而不是依赖 console 前端

## 4. 部署

```bash
docker compose up --build
```

- `docker-compose.yml` 是标准 compose 入口
- `voice-server` 负责 backend
- `voice-console` 仅用于本地调试控制台

## 5. 运维

- 健康检查：`curl -sS http://localhost:11953/actuator/health`
- 能力接口：`curl -sS http://localhost:11953/api/voice/capabilities`
