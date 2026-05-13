#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

BIN_HOME="${HOME}/.local/bin"
PROFILE_HOME="${HOME}/.profile"
SYSTEM_BIN_HOME="/usr/local/bin"

ensure_user_bin_path() {
  local marker_start="# >>> SevenOS user bin path"
  local marker_end="# <<< SevenOS user bin path"

  if [[ ":$PATH:" == *":$BIN_HOME:"* ]]; then
    return 0
  fi

  log_warn "$BIN_HOME is not in PATH for this shell."

  if is_dry_run; then
    printf 'touch %q\n' "$PROFILE_HOME"
    printf 'append managed SevenOS PATH block to %q\n' "$PROFILE_HOME"
    return 0
  fi

  touch "$PROFILE_HOME"
  if ! grep -qF "$marker_start" "$PROFILE_HOME"; then
    cp -a "$PROFILE_HOME" "$(backup_path "$PROFILE_HOME")"
    {
      printf '\n%s\n' "$marker_start"
      printf 'case ":$PATH:" in\n'
      printf '  *":$HOME/.local/bin:"*) ;;\n'
      printf '  *) export PATH="$HOME/.local/bin:$PATH" ;;\n'
      printf 'esac\n'
      printf '%s\n' "$marker_end"
    } >> "$PROFILE_HOME"
  fi

  log_warn "Open a new shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
}

install_system_command() {
  local source_file="$1"
  local command_name="$2"

  if is_dry_run; then
    printf 'sudo install -Dm755 %q %q\n' "$source_file" "$SYSTEM_BIN_HOME/$command_name"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo install -Dm755 "$source_file" "$SYSTEM_BIN_HOME/$command_name"
  else
    log_warn "sudo unavailable; skipping system command install: $command_name"
  fi
}

log_info "Installing SevenOS CLI..."
run_cmd mkdir -p "$BIN_HOME"
run_cmd cp "$ROOT_DIR/bin/seven" "$BIN_HOME/seven"
run_cmd cp "$ROOT_DIR/bin/seven-power" "$BIN_HOME/seven-power"
run_cmd cp "$ROOT_DIR/bin/seven-welcome" "$BIN_HOME/seven-welcome"
run_cmd cp "$ROOT_DIR/bin/seven-country" "$BIN_HOME/seven-country"
run_cmd cp "$ROOT_DIR/bin/seven-waybar-profile" "$BIN_HOME/seven-waybar-profile"
run_cmd cp "$ROOT_DIR/bin/seven-waybar-security" "$BIN_HOME/seven-waybar-security"
run_cmd cp "$ROOT_DIR/bin/sevenpkg" "$BIN_HOME/sevenpkg"
run_cmd cp "$ROOT_DIR/bin/sevenosctl" "$BIN_HOME/sevenosctl"
run_cmd chmod +x "$BIN_HOME/seven"
run_cmd chmod +x "$BIN_HOME/seven-power"
run_cmd chmod +x "$BIN_HOME/seven-welcome"
run_cmd chmod +x "$BIN_HOME/seven-country"
run_cmd chmod +x "$BIN_HOME/seven-waybar-profile"
run_cmd chmod +x "$BIN_HOME/seven-waybar-security"
run_cmd chmod +x "$BIN_HOME/sevenpkg"
run_cmd chmod +x "$BIN_HOME/sevenosctl"
ensure_user_bin_path

log_info "Installing SevenOS CLI into /usr/local/bin for reliable terminal access..."
install_system_command "$ROOT_DIR/bin/seven" seven
install_system_command "$ROOT_DIR/bin/sevenpkg" sevenpkg
install_system_command "$ROOT_DIR/bin/seven-country" seven-country
install_system_command "$ROOT_DIR/bin/seven-power" seven-power
install_system_command "$ROOT_DIR/bin/seven-welcome" seven-welcome
install_system_command "$ROOT_DIR/bin/seven-waybar-profile" seven-waybar-profile
install_system_command "$ROOT_DIR/bin/seven-waybar-security" seven-waybar-security
install_system_command "$ROOT_DIR/bin/sevenosctl" sevenosctl

log_success "SevenOS CLI installed. Run: seven status or sevenpkg meta"
