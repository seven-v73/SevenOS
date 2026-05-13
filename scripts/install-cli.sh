#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

BIN_HOME="${HOME}/.local/bin"
PROFILE_HOME="${HOME}/.profile"
BASHRC_HOME="${HOME}/.bashrc"
ZSHRC_HOME="${HOME}/.zshrc"
SYSTEM_BIN_HOME="/usr/local/bin"

ensure_user_bin_path() {
  local marker_start="# >>> SevenOS user bin path"
  local marker_end="# <<< SevenOS user bin path"
  local shell_file

  if [[ ":$PATH:" == *":$BIN_HOME:"* ]]; then
    log_success "$BIN_HOME is already in PATH."
    return 0
  fi

  if is_dry_run; then
    printf 'append managed SevenOS PATH block to %q %q %q\n' "$PROFILE_HOME" "$BASHRC_HOME" "$ZSHRC_HOME"
    return 0
  fi

  for shell_file in "$PROFILE_HOME" "$BASHRC_HOME" "$ZSHRC_HOME"; do
    touch "$shell_file"
    if ! grep -qF "$marker_start" "$shell_file"; then
      cp -a "$shell_file" "$(backup_path "$shell_file")"
      {
        printf '\n%s\n' "$marker_start"
        printf 'case ":$PATH:" in\n'
        printf '  *":$HOME/.local/bin:"*) ;;\n'
        printf '  *) export PATH="$HOME/.local/bin:$PATH" ;;\n'
        printf 'esac\n'
        printf '%s\n' "$marker_end"
      } >> "$shell_file"
    fi
  done

  log_warn "Open a new shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
}

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

install_user_command() {
  local source_file="$1"
  local command_name="$2"

  if is_dry_run; then
    printf 'install SevenOS wrapper %q -> %q\n' "$source_file" "$BIN_HOME/$command_name"
    return 0
  fi

  write_command_wrapper "$BIN_HOME/$command_name" "$source_file"
}

install_system_command() {
  local source_file="$1"
  local command_name="$2"
  local tmp_file

  if is_dry_run; then
    printf 'sudo install SevenOS wrapper %q -> %q\n' "$source_file" "$SYSTEM_BIN_HOME/$command_name"
    return 0
  fi

  tmp_file="$(mktemp)"
  write_command_wrapper "$tmp_file" "$source_file"
  if command -v sudo >/dev/null 2>&1; then
    if ! sudo install -Dm755 "$tmp_file" "$SYSTEM_BIN_HOME/$command_name"; then
      log_warn "Could not install $command_name into $SYSTEM_BIN_HOME."
      log_warn "The user command is still available at $BIN_HOME/$command_name."
    fi
  else
    log_warn "sudo unavailable; skipping system command install: $command_name"
  fi
  rm -f "$tmp_file"
}

log_info "Installing SevenOS CLI..."
run_cmd mkdir -p "$BIN_HOME"
install_user_command "$ROOT_DIR/bin/seven" seven
install_user_command "$ROOT_DIR/bin/seven-power" seven-power
install_user_command "$ROOT_DIR/bin/seven-welcome" seven-welcome
install_user_command "$ROOT_DIR/bin/seven-help" seven-help
install_user_command "$ROOT_DIR/bin/seven-wallpaper" seven-wallpaper
install_user_command "$ROOT_DIR/bin/seven-country" seven-country
install_user_command "$ROOT_DIR/bin/seven-waybar-profile" seven-waybar-profile
install_user_command "$ROOT_DIR/bin/seven-waybar-security" seven-waybar-security
install_user_command "$ROOT_DIR/bin/sevenpkg" sevenpkg
install_user_command "$ROOT_DIR/bin/sevenosctl" sevenosctl
ensure_user_bin_path

log_info "Installing SevenOS CLI into /usr/local/bin for reliable terminal access..."
install_system_command "$ROOT_DIR/bin/seven" seven
install_system_command "$ROOT_DIR/bin/sevenpkg" sevenpkg
install_system_command "$ROOT_DIR/bin/seven-country" seven-country
install_system_command "$ROOT_DIR/bin/seven-power" seven-power
install_system_command "$ROOT_DIR/bin/seven-welcome" seven-welcome
install_system_command "$ROOT_DIR/bin/seven-help" seven-help
install_system_command "$ROOT_DIR/bin/seven-wallpaper" seven-wallpaper
install_system_command "$ROOT_DIR/bin/seven-waybar-profile" seven-waybar-profile
install_system_command "$ROOT_DIR/bin/seven-waybar-security" seven-waybar-security
install_system_command "$ROOT_DIR/bin/sevenosctl" sevenosctl

log_success "SevenOS CLI installed. Run: seven status or sevenpkg meta"
