#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/scripts/program-common.sh"

main() {
  cd "$SCRIPT_DIR"
  program_validate_bundle
  program_prepare_runtime_dirs
  program_copy_default_env

  chmod +x "$BUNDLE_ROOT/start.sh" "$BUNDLE_ROOT/stop.sh" "$BUNDLE_ROOT/deploy.sh" "$BACKEND_BIN" "$SCRIPTS_DIR/"*.sh

  echo "[program-deploy] bundle validated"
  echo "[program-deploy] backend binary: $BACKEND_BIN"
  echo "[program-deploy] env file: $ENV_FILE"
  echo "[program-deploy] runtime directory: $RUN_DIR"
}

main "$@"
