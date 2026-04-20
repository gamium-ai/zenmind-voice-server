#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/scripts/program-common.sh"

cd "$SCRIPT_DIR"
program_validate_bundle
program_prepare_runtime_dirs
if [[ -f "$ENV_FILE" ]]; then
  program_load_env
fi
program_stop_backend
