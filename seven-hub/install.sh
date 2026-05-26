#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

BIN_HOME="${HOME}/.local/bin"
APP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
SYSTEM_BIN_HOME="/usr/local/bin"
SYSTEM_INSTALL_WARNED=0

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

install_system_command() {
  local source_file="$1"
  local command_name="$2"
  local tmp_file

  if [[ -z "$(privileged_backend)" ]]; then
    if [[ "$SYSTEM_INSTALL_WARNED" -eq 0 ]]; then
      log_warn "No admin prompt available; skipping $SYSTEM_BIN_HOME command install."
      SYSTEM_INSTALL_WARNED=1
    fi
    return 0
  fi

  tmp_file="$(mktemp)"
  write_command_wrapper "$tmp_file" "$source_file"
  if ! run_privileged_cmd install -Dm755 "$tmp_file" "$SYSTEM_BIN_HOME/$command_name"; then
    log_warn "Could not install $command_name into $SYSTEM_BIN_HOME."
    log_warn "The user command is still available at $BIN_HOME/$command_name."
  fi
  rm -f "$tmp_file"
}

log_info "Installing Seven Hub launcher..."
run_cmd mkdir -p "$BIN_HOME" "$APP_HOME" "$ICON_HOME"
if is_dry_run; then
  printf 'install Seven Hub wrapper %q -> %q\n' "$ROOT_DIR/seven-hub/bin/seven-hub" "$BIN_HOME/seven-hub"
  printf 'install Seven Control Center wrapper %q -> %q\n' "$ROOT_DIR/seven-hub/bin/seven-control-center" "$BIN_HOME/seven-control-center"
  printf 'install SevenOS Home wrapper %q -> %q\n' "$ROOT_DIR/bin/seven-home-native" "$BIN_HOME/seven-home-native"
  printf 'install Seven Hub Native wrapper %q -> %q\n' "$ROOT_DIR/bin/seven-hub-native" "$BIN_HOME/seven-hub-native"
  printf 'install SevenOS Settings wrapper %q -> %q\n' "$ROOT_DIR/bin/seven-settings" "$BIN_HOME/seven-settings"
  printf 'install SevenStore wrapper %q -> %q\n' "$ROOT_DIR/bin/seven-store" "$BIN_HOME/seven-store"
  printf 'install SevenStore Native wrapper %q -> %q\n' "$ROOT_DIR/bin/seven-store-native" "$BIN_HOME/seven-store-native"
  printf '%q install Seven Hub wrapper %q -> %q\n' "$(privileged_backend_label)" "$ROOT_DIR/seven-hub/bin/seven-hub" "$SYSTEM_BIN_HOME/seven-hub"
  printf '%q install Seven Control Center wrapper %q -> %q\n' "$(privileged_backend_label)" "$ROOT_DIR/seven-hub/bin/seven-control-center" "$SYSTEM_BIN_HOME/seven-control-center"
  printf '%q install SevenOS Home wrapper %q -> %q\n' "$(privileged_backend_label)" "$ROOT_DIR/bin/seven-home-native" "$SYSTEM_BIN_HOME/seven-home-native"
  printf '%q install Seven Hub Native wrapper %q -> %q\n' "$(privileged_backend_label)" "$ROOT_DIR/bin/seven-hub-native" "$SYSTEM_BIN_HOME/seven-hub-native"
  printf '%q install SevenOS Settings wrapper %q -> %q\n' "$(privileged_backend_label)" "$ROOT_DIR/bin/seven-settings" "$SYSTEM_BIN_HOME/seven-settings"
  printf '%q install SevenStore wrapper %q -> %q\n' "$(privileged_backend_label)" "$ROOT_DIR/bin/seven-store" "$SYSTEM_BIN_HOME/seven-store"
  printf '%q install SevenStore Native wrapper %q -> %q\n' "$(privileged_backend_label)" "$ROOT_DIR/bin/seven-store-native" "$SYSTEM_BIN_HOME/seven-store-native"
else
  write_command_wrapper "$BIN_HOME/seven-hub" "$ROOT_DIR/seven-hub/bin/seven-hub"
  write_command_wrapper "$BIN_HOME/seven-control-center" "$ROOT_DIR/seven-hub/bin/seven-control-center"
  write_command_wrapper "$BIN_HOME/seven-home-native" "$ROOT_DIR/bin/seven-home-native"
  write_command_wrapper "$BIN_HOME/seven-hub-native" "$ROOT_DIR/bin/seven-hub-native"
  write_command_wrapper "$BIN_HOME/seven-actions-native" "$ROOT_DIR/bin/seven-actions-native"
  write_command_wrapper "$BIN_HOME/seven-settings" "$ROOT_DIR/bin/seven-settings"
  write_command_wrapper "$BIN_HOME/seven-store" "$ROOT_DIR/bin/seven-store"
  write_command_wrapper "$BIN_HOME/seven-store-native" "$ROOT_DIR/bin/seven-store-native"
  install_system_command "$ROOT_DIR/seven-hub/bin/seven-hub" seven-hub
  install_system_command "$ROOT_DIR/seven-hub/bin/seven-control-center" seven-control-center
  install_system_command "$ROOT_DIR/bin/seven-home-native" seven-home-native
  install_system_command "$ROOT_DIR/bin/seven-hub-native" seven-hub-native
  install_system_command "$ROOT_DIR/bin/seven-actions-native" seven-actions-native
  install_system_command "$ROOT_DIR/bin/seven-settings" seven-settings
  install_system_command "$ROOT_DIR/bin/seven-store" seven-store
  install_system_command "$ROOT_DIR/bin/seven-store-native" seven-store-native
fi
run_cmd cp "$ROOT_DIR/seven-hub/seven-hub.desktop" "$APP_HOME/seven-hub.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-home.desktop" "$APP_HOME/seven-home.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-hub-native.desktop" "$APP_HOME/seven-hub-native.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-actions.desktop" "$APP_HOME/seven-actions.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-settings.desktop" "$APP_HOME/seven-settings.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-files.desktop" "$APP_HOME/seven-files.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-recorder.desktop" "$APP_HOME/seven-recorder.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-store.desktop" "$APP_HOME/seven-store.desktop"
run_cmd cp "$ROOT_DIR/seven-hub/seven-wallpaper.desktop" "$APP_HOME/seven-wallpaper.desktop"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos.svg" "$ICON_HOME/sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos-symbol.svg" "$ICON_HOME/sevenos-symbol.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-hub.svg" "$ICON_HOME/seven-hub.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-store.svg" "$ICON_HOME/seven-store.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-dev.svg" "$ICON_HOME/sevenos-dev.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-security.svg" "$ICON_HOME/sevenos-security.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-creation.svg" "$ICON_HOME/sevenos-creation.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-windows.svg" "$ICON_HOME/sevenos-windows.svg"
run_cmd cp "$ROOT_DIR/identity/assets/icon-installer.svg" "$ICON_HOME/sevenos-installer.svg"

log_success "Seven Hub installed. Launch it with: seven hub"
log_info "Command palette fallback: seven-hub"
