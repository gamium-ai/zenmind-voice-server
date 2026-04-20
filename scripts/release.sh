#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_ASSETS_DIR="$SCRIPT_DIR/release-assets"
UNIX_ASSETS_DIR="$RELEASE_ASSETS_DIR/unix"
WINDOWS_ASSETS_DIR="$RELEASE_ASSETS_DIR/windows"
FRONTEND_DIR="$REPO_ROOT/frontend"
EMBED_UI_DIR="$REPO_ROOT/internal/httpapi/ui"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/release-common.sh"

require_release_tools
resolve_release_context

require_file "$REPO_ROOT/.env.example"
require_dir "$RELEASE_ASSETS_DIR"
require_dir "$UNIX_ASSETS_DIR"
require_dir "$WINDOWS_ASSETS_DIR"
require_file "$RELEASE_ASSETS_DIR/README.txt"
require_file "$UNIX_ASSETS_DIR/start.sh"
require_file "$UNIX_ASSETS_DIR/stop.sh"
require_file "$UNIX_ASSETS_DIR/deploy.sh"
require_file "$UNIX_ASSETS_DIR/scripts/program-common.sh"
require_file "$WINDOWS_ASSETS_DIR/start.ps1"
require_file "$WINDOWS_ASSETS_DIR/stop.ps1"
require_file "$WINDOWS_ASSETS_DIR/deploy.ps1"
require_file "$WINDOWS_ASSETS_DIR/scripts/program-common.ps1"

prepare_embedded_ui() {
  echo "[release] building frontend for embedded UI..."
  (
    cd "$FRONTEND_DIR"
    npm ci
    npm run build
  )

  mkdir -p "$EMBED_UI_DIR"
  find "$EMBED_UI_DIR" -mindepth 1 ! -name '.gitkeep' ! -name 'placeholder.txt' -exec rm -rf {} +
  cp -R "$FRONTEND_DIR/dist/." "$EMBED_UI_DIR/"
  require_file "$EMBED_UI_DIR/index.html"
}

copy_platform_assets() {
  local target_os="$1"
  local bundle_root="$2"

  mkdir -p "$bundle_root/scripts"

  case "$target_os" in
    darwin|linux)
      cp "$UNIX_ASSETS_DIR/deploy.sh" "$bundle_root/deploy.sh"
      cp "$UNIX_ASSETS_DIR/start.sh" "$bundle_root/start.sh"
      cp "$UNIX_ASSETS_DIR/stop.sh" "$bundle_root/stop.sh"
      cp "$UNIX_ASSETS_DIR/scripts/program-common.sh" "$bundle_root/scripts/program-common.sh"
      chmod +x \
        "$bundle_root/deploy.sh" \
        "$bundle_root/start.sh" \
        "$bundle_root/stop.sh" \
        "$bundle_root/scripts/program-common.sh"
      ;;
    windows)
      cp "$WINDOWS_ASSETS_DIR/deploy.ps1" "$bundle_root/deploy.ps1"
      cp "$WINDOWS_ASSETS_DIR/start.ps1" "$bundle_root/start.ps1"
      cp "$WINDOWS_ASSETS_DIR/stop.ps1" "$bundle_root/stop.ps1"
      cp "$WINDOWS_ASSETS_DIR/scripts/program-common.ps1" "$bundle_root/scripts/program-common.ps1"
      ;;
    *)
      die "unsupported target os: $target_os"
      ;;
  esac
}

build_program_bundle() {
  local target_os="$1"
  local target_arch="$2"
  local binary_name
  local archive_format
  local bundle_archive
  local tmp_dir
  local stage_root
  local bundle_root
  local backend_dir
  local backend_path
  local backend_entry

  validate_target_pair "$target_os" "$target_arch"
  require_archive_tool_for_os "$target_os"

  binary_name="$(binary_name_for_os "$target_os")"
  archive_format="$(archive_format_for_os "$target_os")"
  bundle_archive="$RELEASE_DIR/$(program_bundle_filename "$VERSION" "$target_os" "$target_arch" "$archive_format")"

  echo "[release] building program bundle VERSION=$VERSION TARGET_OS=$target_os ARCH=$target_arch"

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/zenmind-voice-program-release.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' RETURN

  stage_root="$tmp_dir/stage"
  bundle_root="$stage_root/$APP_ID"
  backend_dir="$bundle_root/backend"
  backend_path="$backend_dir/$binary_name"
  backend_entry="backend/$binary_name"

  mkdir -p "$backend_dir"

  (
    cd "$REPO_ROOT"
    CGO_ENABLED=0 GOOS="$target_os" GOARCH="$target_arch" \
      go build \
      -trimpath \
      -ldflags "-s -w -X main.buildVersion=$VERSION" \
      -o "$backend_path" \
      ./cmd/voice-server
  )

  cp "$REPO_ROOT/.env.example" "$bundle_root/.env.example"
  cp "$RELEASE_ASSETS_DIR/README.txt" "$bundle_root/README.txt"
  copy_platform_assets "$target_os" "$bundle_root"
  write_program_manifest "$bundle_root/manifest.json" "$target_os" "$target_arch" "$backend_entry" "$(basename "$bundle_archive")"

  if [[ "$target_os" != "windows" ]]; then
    chmod +x "$backend_path"
  fi

  mkdir -p "$RELEASE_DIR"
  archive_bundle_dir "$stage_root" "$APP_ID" "$bundle_archive" "$archive_format"
  echo "[release] done: $bundle_archive"
}

prepare_embedded_ui

while read -r target_os target_arch; do
  [[ -n "$target_os" ]] || continue
  [[ -n "$target_arch" ]] || die "missing ARCH for target $target_os"
  build_program_bundle "$target_os" "$target_arch"
done < <(parse_program_target_matrix)
