#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

BIN_HOME="${HOME}/.local/bin"

log_info "Installing SevenOS CLI..."
run_cmd mkdir -p "$BIN_HOME"
run_cmd cp "$ROOT_DIR/bin/seven" "$BIN_HOME/seven"
run_cmd cp "$ROOT_DIR/bin/sevenpkg" "$BIN_HOME/sevenpkg"
run_cmd cp "$ROOT_DIR/bin/sevenosctl" "$BIN_HOME/sevenosctl"
run_cmd chmod +x "$BIN_HOME/seven"
run_cmd chmod +x "$BIN_HOME/sevenpkg"
run_cmd chmod +x "$BIN_HOME/sevenosctl"

log_success "SevenOS CLI installed. Run: seven status or sevenpkg meta"
