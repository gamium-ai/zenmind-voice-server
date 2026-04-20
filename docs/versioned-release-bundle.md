# 版本化离线打包方案

## 1. 目标

`zenmind-voice-server` 的 release bundle 用于交付可直接导入 `zenmind-desktop` 的插件产物，而不是源码压缩包。

当前发布形态：

- 交付物是平台化插件 bundle
- bundle 内包含原生 Go 二进制和最小运行资产
- 前端静态文件已经内嵌进 Go 二进制，不再单独交付 nginx 或静态目录
- 部署端不需要源码构建环境
- 外部 ASR / TTS / runner 依赖仍由 `.env` 配置并要求部署端可达

正式版本单一来源是根目录 `VERSION`，格式固定为 `vX.Y.Z`。

## 2. 产物矩阵

默认 release 会产出：

- `dist/release/zenmind-voice-server-vX.Y.Z-darwin-arm64.tar.gz`
- `dist/release/zenmind-voice-server-vX.Y.Z-windows-amd64.zip`

规则：

- macOS / Linux 插件包使用 `.tar.gz`
- Windows 插件包使用 `.zip`
- 当前支持的目标 OS：`darwin`、`linux`、`windows`
- 当前支持的 Windows 架构只有 `windows/amd64`

## 3. 打包入口

标准入口：

```bash
make release
```

`Makefile` 会把以下变量透传给 `scripts/release.sh`：

- `VERSION`
- `ARCH`
- `PROGRAM_TARGETS`
- `PROGRAM_TARGET_MATRIX`
- `RELEASE_TARGETS`
- `RELEASE_TARGET_MATRIX`

常见用法：

```bash
make release VERSION=v1.0.0
make release VERSION=v1.0.0 ARCH=amd64
make release VERSION=v1.0.0 PROGRAM_TARGETS=windows
make release VERSION=v1.0.0 PROGRAM_TARGET_MATRIX=darwin/arm64,windows/amd64
make release VERSION=v1.0.0 PROGRAM_TARGET_MATRIX=linux/arm64
```

解析规则：

1. `PROGRAM_TARGET_MATRIX` 优先级最高
2. 其次兼容 `RELEASE_TARGET_MATRIX`
3. 再其次是 `PROGRAM_TARGETS` / `RELEASE_TARGETS`
4. 若只设置 `ARCH`，生成当前宿主平台 bundle
5. 若都未设置，默认生成当前宿主平台 bundle 和 `windows/amd64`

## 4. 构建与组装

`scripts/release.sh` 会执行两步：

1. 在 `frontend/` 下执行 `npm ci && npm run build`，把产物复制到 `internal/httpapi/ui/`
2. 对每个目标平台执行 `CGO_ENABLED=0 GOOS=<os> GOARCH=<arch> go build`

编译参数：

- 使用 `-X main.buildVersion=$VERSION`
- release 二进制额外使用 `-s -w` 压缩符号信息

## 5. bundle 资产

bundle 根目录包含：

- `backend/voice-server` 或 `backend/voice-server.exe`
- `manifest.json`
- `.env.example`
- `README.txt`
- `deploy.{sh|ps1}`
- `start.{sh|ps1}`
- `stop.{sh|ps1}`
- `scripts/program-common.{sh|ps1}`

不再包含：

- Docker 镜像 tar
- `compose.release.yml`
- compose watchdog
- nginx 前端资产

## 6. Desktop 插件契约

manifest 维持 `kind: "plugin"`，但运行模式已经切换为原生 program 方式：

- `frontend.mode: "embedded"`
- `backend.entry: "backend/voice-server"` 或 `.exe`
- `scripts.start` 默认带 `--daemon`
- `web.portEnvKey: "SERVER_PORT"`
- `web.defaultPort: 11953`

Desktop 导入后，实际页面访问地址为：

- `http://127.0.0.1:${SERVER_PORT}/`

## 7. 运行流程

启动流程：

1. 校验 bundle 完整性
2. 准备 `run/`
3. 若 `.env` 不存在，则由 `.env.example` 自动复制
4. 加载 `.env`
5. 直接启动 `backend/voice-server`
6. 把 pid 写入 `run/zenmind-voice-server.pid`
7. 把 stdout / stderr 写入 `run/` 目录

停止流程：

1. 读取 pid 文件
2. 终止目标进程
3. 清理 pid 文件

## 8. bundle 结构

macOS / Linux：

```text
zenmind-voice-server/
  manifest.json
  .env.example
  README.txt
  deploy.sh
  start.sh
  stop.sh
  backend/
    voice-server
  scripts/
    program-common.sh
```

Windows：

```text
zenmind-voice-server/
  manifest.json
  .env.example
  README.txt
  deploy.ps1
  start.ps1
  stop.ps1
  backend/
    voice-server.exe
  scripts/
    program-common.ps1
```
