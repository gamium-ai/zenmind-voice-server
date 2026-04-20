#!/usr/bin/env bash
set -euo pipefail

APP_ID="zenmind-voice-server"
PROGRAM_NAME="voice-server"

die() {
  echo "[release] $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || die "required file not found: $path"
}

require_dir() {
  local path="$1"
  [[ -d "$path" ]] || die "required directory not found: $path"
}

require_release_tools() {
  command -v go >/dev/null 2>&1 || die "go is required"
  command -v node >/dev/null 2>&1 || die "node is required"
  command -v npm >/dev/null 2>&1 || die "npm is required"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
    *) die "cannot detect ARCH from $(uname -m); pass ARCH=amd64|arm64" ;;
  esac
}

detect_host_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) die "cannot detect host OS from $(uname -s); pass PROGRAM_TARGET_MATRIX explicitly" ;;
  esac
}

validate_arch() {
  case "$1" in
    amd64|arm64) ;;
    *) die "ARCH must be amd64 or arm64 (got: $1)" ;;
  esac
}

validate_target_os() {
  case "$1" in
    darwin|linux|windows) ;;
    *) die "TARGET_OS must be darwin, linux, or windows (got: $1)" ;;
  esac
}

validate_target_pair() {
  local target_os="$1"
  local target_arch="$2"
  validate_target_os "$target_os"
  validate_arch "$target_arch"
  if [[ "$target_os" == "windows" && "$target_arch" != "amd64" ]]; then
    die "windows bundles only support amd64 (got: $target_arch)"
  fi
}

archive_format_for_os() {
  local target_os="$1"
  validate_target_os "$target_os"
  case "$target_os" in
    darwin|linux) printf 'tar.gz\n' ;;
    windows) printf 'zip\n' ;;
  esac
}

require_archive_tool_for_os() {
  local target_os="$1"
  local archive_format
  archive_format="$(archive_format_for_os "$target_os")"
  case "$archive_format" in
    tar.gz) command -v tar >/dev/null 2>&1 || die "tar is required for $target_os bundles" ;;
    zip) command -v zip >/dev/null 2>&1 || die "zip is required for $target_os bundles" ;;
    *) die "unsupported archive format: $archive_format" ;;
  esac
}

archive_bundle_dir() {
  local stage_root="$1"
  local bundle_dir_name="$2"
  local output_path="$3"
  local format="$4"

  mkdir -p "$(dirname "$output_path")"
  rm -f "$output_path"

  case "$format" in
    tar.gz)
      tar -czf "$output_path" -C "$stage_root" "$bundle_dir_name"
      ;;
    zip)
      (
        cd "$stage_root"
        zip -qr "$output_path" "$bundle_dir_name"
      )
      ;;
    *)
      die "unsupported archive format: $format"
      ;;
  esac
}

binary_name_for_os() {
  local target_os="$1"
  validate_target_os "$target_os"
  if [[ "$target_os" == "windows" ]]; then
    printf '%s.exe\n' "$PROGRAM_NAME"
    return
  fi
  printf '%s\n' "$PROGRAM_NAME"
}

program_bundle_filename() {
  local version="$1"
  local target_os="$2"
  local target_arch="$3"
  local archive_format="$4"
  printf '%s-%s-%s-%s.%s\n' "$APP_ID" "$version" "$target_os" "$target_arch" "$archive_format"
}

resolve_release_context() {
  VERSION="${VERSION:-$(cat "$REPO_ROOT/VERSION" 2>/dev/null || echo "")}"
  [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION must match vX.Y.Z (got: ${VERSION:-<empty>})"

  HOST_OS="$(detect_host_os)"
  HOST_ARCH="$(detect_arch)"
  if [[ -n "${ARCH:-}" ]]; then
    validate_arch "$ARCH"
  fi

  RELEASE_DIR="$REPO_ROOT/dist/release"
}

parse_program_targets() {
  local raw="${PROGRAM_TARGETS:-${RELEASE_TARGETS:-}}"
  raw="${raw//,/ }"
  for target_os in $raw; do
    validate_target_os "$target_os"
    printf '%s\n' "$target_os"
  done
}

parse_program_target_matrix() {
  local raw="${PROGRAM_TARGET_MATRIX:-${RELEASE_TARGET_MATRIX:-}}"
  local target_spec
  local target_os
  local target_arch

  if [[ -n "$raw" ]]; then
    raw="${raw//,/ }"
    for target_spec in $raw; do
      [[ "$target_spec" == */* ]] || die "PROGRAM_TARGET_MATRIX entries must look like <os>/<arch> (got: $target_spec)"
      target_os="${target_spec%%/*}"
      target_arch="${target_spec#*/}"
      validate_target_pair "$target_os" "$target_arch"
      printf '%s %s\n' "$target_os" "$target_arch"
    done
    return
  fi

  if [[ -n "${PROGRAM_TARGETS:-${RELEASE_TARGETS:-}}" ]]; then
    while IFS= read -r target_os; do
      [[ -n "$target_os" ]] || continue
      case "$target_os" in
        darwin|linux)
          target_arch="${ARCH:-$HOST_ARCH}"
          ;;
        windows)
          target_arch="amd64"
          ;;
      esac
      validate_target_pair "$target_os" "$target_arch"
      printf '%s %s\n' "$target_os" "$target_arch"
    done < <(parse_program_targets)
    return
  fi

  if [[ -n "${ARCH:-}" ]]; then
    validate_target_pair "$HOST_OS" "$ARCH"
    printf '%s %s\n' "$HOST_OS" "$ARCH"
    return
  fi

  printf '%s %s\n' "$HOST_OS" "$HOST_ARCH"
  if [[ "$HOST_OS" != "windows" ]]; then
    printf 'windows amd64\n'
  fi
}

write_program_manifest() {
  local dest="$1"
  local target_os="$2"
  local target_arch="$3"
  local backend_entry="$4"
  local asset_file_name="$5"
  local start_script="start.sh"
  local stop_script="stop.sh"
  local deploy_script="deploy.sh"
  local program_common="scripts/program-common.sh"

  if [[ "$target_os" == "windows" ]]; then
    start_script="start.ps1"
    stop_script="stop.ps1"
    deploy_script="deploy.ps1"
    program_common="scripts/program-common.ps1"
  fi

  cat >"$dest" <<EOF
{
  "id": "$APP_ID",
  "name": "语音服务",
  "kind": "plugin",
  "version": "$VERSION",
  "description": "原生二进制语音服务，Go 进程同时提供 API、WebSocket 和嵌入式前端调试台。",
  "platform": {
    "os": "$target_os",
    "arch": "$target_arch"
  },
  "frontend": {
    "mode": "embedded",
    "entry": "/",
    "directAccess": true,
    "hostManaged": false
  },
  "backend": {
    "entry": "$backend_entry"
  },
  "scripts": {
    "start": ["$start_script", "--daemon"],
    "stop": "$stop_script",
    "deploy": "$deploy_script"
  },
  "configFiles": [
    {
      "key": "env",
      "label": ".env",
      "relativePath": ".env",
      "templateRelativePath": ".env.example",
      "required": true
    }
  ],
  "runtime": {
    "pidRelativePath": "run/$APP_ID.pid",
    "logRelativePath": "run/$APP_ID.log",
    "errorLogRelativePath": "run/$APP_ID.stderr.log",
    "requiredPaths": [
      "$backend_entry",
      "$start_script",
      "$stop_script",
      "$deploy_script",
      "$program_common",
      ".env.example",
      "manifest.json",
      "README.txt"
    ]
  },
  "web": {
    "routePath": "/",
    "portEnvKey": "SERVER_PORT",
    "defaultPort": 11953
  },
  "desktop": {
    "assetFileName": "$asset_file_name",
    "bundleTopLevelDir": "$APP_ID"
  }
}
EOF
}
