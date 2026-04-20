#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
APP_ID="zenmind-voice-server"
PROGRAM_NAME="voice-server"
MANIFEST_FILE="$BUNDLE_ROOT/manifest.json"
ENV_EXAMPLE_FILE="$BUNDLE_ROOT/.env.example"
ENV_FILE="$BUNDLE_ROOT/.env"
BACKEND_BIN="$BUNDLE_ROOT/backend/$PROGRAM_NAME"
RUN_DIR="$BUNDLE_ROOT/run"
PID_FILE="$RUN_DIR/$APP_ID.pid"
LOG_FILE="$RUN_DIR/$APP_ID.log"
ERROR_LOG_FILE="$RUN_DIR/$APP_ID.stderr.log"

program_die() {
  echo "[program] $*" >&2
  exit 1
}

program_require_file() {
  local path="$1"
  [[ -f "$path" ]] || program_die "required file not found: $path"
}

program_validate_bundle() {
  program_require_file "$MANIFEST_FILE"
  program_require_file "$ENV_EXAMPLE_FILE"
  [[ -x "$BACKEND_BIN" ]] || program_die "backend binary is not executable: $BACKEND_BIN"
}

program_prepare_runtime_dirs() {
  mkdir -p "$RUN_DIR"
}

program_copy_default_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
  fi
}

program_load_env() {
  [[ -f "$ENV_FILE" ]] || program_die "missing .env (copy from .env.example first)"
  SERVER_PORT="$(
    awk -F= '
      /^[[:space:]]*#/ { next }
      $1 == "SERVER_PORT" {
        value = substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    ' "$ENV_FILE"
  )"
  SERVER_PORT="${SERVER_PORT:-11953}"
  export SERVER_PORT
}

program_read_pid() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$pid"
}

program_clear_stale_pid() {
  if [[ ! -f "$PID_FILE" ]]; then
    return
  fi

  local pid
  pid="$(program_read_pid || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    program_die "$APP_ID is already running with pid $pid"
  fi

  rm -f "$PID_FILE"
}

program_start_backend_daemon() {
  local pid

  program_clear_stale_pid
  : >"$LOG_FILE"
  : >"$ERROR_LOG_FILE"

  nohup "$BACKEND_BIN" >>"$LOG_FILE" 2>>"$ERROR_LOG_FILE" &
  pid=$!
  printf '%s\n' "$pid" >"$PID_FILE"
  sleep 1

  if ! kill -0 "$pid" >/dev/null 2>&1; then
    rm -f "$PID_FILE"
    program_die "backend failed to start; see $LOG_FILE and $ERROR_LOG_FILE"
  fi

  echo "[program-start] started $APP_ID in daemon mode (pid=$pid)"
  echo "[program-start] web: http://127.0.0.1:${SERVER_PORT}/"
  echo "[program-start] log file: $LOG_FILE"
  echo "[program-start] stderr file: $ERROR_LOG_FILE"
}

program_exec_backend() {
  exec "$BACKEND_BIN"
}

program_stop_backend() {
  local pid

  if [[ ! -f "$PID_FILE" ]]; then
    echo "[program-stop] pid file not found: $PID_FILE"
    return
  fi

  pid="$(program_read_pid || true)"
  [[ -n "$pid" ]] || program_die "pid file must contain a numeric pid: $PID_FILE"

  if ! kill -0 "$pid" >/dev/null 2>&1; then
    rm -f "$PID_FILE"
    echo "[program-stop] process $pid is not running; removed stale pid file"
    return
  fi

  kill "$pid"
  for _ in $(seq 1 30); do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      rm -f "$PID_FILE"
      echo "[program-stop] stopped $APP_ID (pid=$pid)"
      return
    fi
    sleep 1
  done

  kill -9 "$pid" >/dev/null 2>&1 || true
  rm -f "$PID_FILE"
  echo "[program-stop] force stopped $APP_ID (pid=$pid)"
}
