#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Hyprland Lua Engine

Usage:
  seven hypr lua status [--json]
  seven hypr lua profiles [--json]
  seven hypr lua plan [profile] [--json]
  seven hypr lua audit [--json]
  seven hypr lua generate [profile]
  seven hypr lua apply [profile]
  seven hypr lua doctor
EOF
}

lua_bin() {
  command -v lua || command -v luajit || true
}

run_lua() {
  local lua
  lua="$(lua_bin)"
  if [[ -z "$lua" ]]; then
    log_error "Lua is not installed. Install package: lua"
    return 1
  fi
  SEVENOS_ROOT="$ROOT_DIR" "$lua" "$ROOT_DIR/hyprland/lua/init.lua" "$@"
}

case "${1:-status}" in
  status|json|profiles|plan|audit|generate|apply|doctor)
    run_lua "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    log_error "Unknown Hypr Lua action: $1"
    usage
    exit 1
    ;;
esac
