#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

BIN_HOME="${HOME}/.local/bin"
APP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

log_info "Installing Seven Hub launcher..."
run_cmd mkdir -p "$BIN_HOME" "$APP_HOME"
run_cmd cp "$ROOT_DIR/seven-hub/bin/seven-hub" "$BIN_HOME/seven-hub"
run_cmd chmod +x "$BIN_HOME/seven-hub"
run_cmd cp "$ROOT_DIR/seven-hub/seven-hub.desktop" "$APP_HOME/seven-hub.desktop"

log_success "Seven Hub installed. Launch it with: seven-hub"
