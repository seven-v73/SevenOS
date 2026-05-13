#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

BIN_HOME="${HOME}/.local/bin"
APP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"

log_info "Installing Seven Hub launcher..."
run_cmd mkdir -p "$BIN_HOME" "$APP_HOME" "$ICON_HOME"
run_cmd cp "$ROOT_DIR/seven-hub/bin/seven-hub" "$BIN_HOME/seven-hub"
run_cmd chmod +x "$BIN_HOME/seven-hub"
run_cmd cp "$ROOT_DIR/seven-hub/seven-hub.desktop" "$APP_HOME/seven-hub.desktop"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos.svg" "$ICON_HOME/sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos-symbol.svg" "$ICON_HOME/sevenos-symbol.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-hub.svg" "$ICON_HOME/seven-hub.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-dev.svg" "$ICON_HOME/sevenos-dev.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-security.svg" "$ICON_HOME/sevenos-security.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-creation.svg" "$ICON_HOME/sevenos-creation.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-windows.svg" "$ICON_HOME/sevenos-windows.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-installer.svg" "$ICON_HOME/sevenos-installer.svg"

log_success "Seven Hub installed. Launch it with: seven-hub"
