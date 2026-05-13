#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

BIN_HOME="${HOME}/.local/bin"
APP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"

write_command_wrapper() {
  local target_file="$1"
  local source_file="$2"

  {
    printf '#!/usr/bin/env bash\n'
    printf 'export SEVENOS_ROOT=%q\n' "$ROOT_DIR"
    printf 'exec %q "$@"\n' "$source_file"
  } > "$target_file"
  chmod +x "$target_file"
}

log_info "Installing Seven Hub launcher..."
run_cmd mkdir -p "$BIN_HOME" "$APP_HOME" "$ICON_HOME"
if is_dry_run; then
  printf 'install Seven Hub wrapper %q -> %q\n' "$ROOT_DIR/seven-hub/bin/seven-hub" "$BIN_HOME/seven-hub"
  printf 'install Seven Control Center wrapper %q -> %q\n' "$ROOT_DIR/seven-hub/bin/seven-control-center" "$BIN_HOME/seven-control-center"
  printf 'sudo install Seven Hub wrapper %q -> %q\n' "$ROOT_DIR/seven-hub/bin/seven-hub" "/usr/local/bin/seven-hub"
  printf 'sudo install Seven Control Center wrapper %q -> %q\n' "$ROOT_DIR/seven-hub/bin/seven-control-center" "/usr/local/bin/seven-control-center"
else
  write_command_wrapper "$BIN_HOME/seven-hub" "$ROOT_DIR/seven-hub/bin/seven-hub"
  write_command_wrapper "$BIN_HOME/seven-control-center" "$ROOT_DIR/seven-hub/bin/seven-control-center"
  if command -v sudo >/dev/null 2>&1; then
    tmp_file="$(mktemp)"
    write_command_wrapper "$tmp_file" "$ROOT_DIR/seven-hub/bin/seven-hub"
    if ! sudo install -Dm755 "$tmp_file" "/usr/local/bin/seven-hub"; then
      log_warn "Could not install seven-hub into /usr/local/bin."
      log_warn "The user command is still available at $BIN_HOME/seven-hub."
    fi
    rm -f "$tmp_file"

    tmp_file="$(mktemp)"
    write_command_wrapper "$tmp_file" "$ROOT_DIR/seven-hub/bin/seven-control-center"
    if ! sudo install -Dm755 "$tmp_file" "/usr/local/bin/seven-control-center"; then
      log_warn "Could not install seven-control-center into /usr/local/bin."
      log_warn "The user command is still available at $BIN_HOME/seven-control-center."
    fi
    rm -f "$tmp_file"
  fi
fi
run_cmd cp "$ROOT_DIR/seven-hub/seven-hub.desktop" "$APP_HOME/seven-hub.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-files.desktop" "$APP_HOME/seven-files.desktop"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos.svg" "$ICON_HOME/sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos-symbol.svg" "$ICON_HOME/sevenos-symbol.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-hub.svg" "$ICON_HOME/seven-hub.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-dev.svg" "$ICON_HOME/sevenos-dev.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-security.svg" "$ICON_HOME/sevenos-security.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-creation.svg" "$ICON_HOME/sevenos-creation.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-windows.svg" "$ICON_HOME/sevenos-windows.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-installer.svg" "$ICON_HOME/sevenos-installer.svg"

log_success "Seven Hub installed. Launch it with: seven hub"
log_info "Command palette fallback: seven-hub"
