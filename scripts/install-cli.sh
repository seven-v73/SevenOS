#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

BIN_HOME="${HOME}/.local/bin"
PROFILE_HOME="${HOME}/.profile"
BASHRC_HOME="${HOME}/.bashrc"
ZSHRC_HOME="${HOME}/.zshrc"
SYSTEM_BIN_HOME="/usr/local/bin"
SYSTEM_INSTALL_WARNED=0

ensure_user_bin_path() {
  local marker_start="# >>> SevenOS user bin path"
  local marker_end="# <<< SevenOS user bin path"
  local shell_file

  if [[ ":$PATH:" == ":$BIN_HOME:"* ]]; then
    log_success "$BIN_HOME is already first in PATH."
    return 0
  fi

  if is_dry_run; then
    printf 'prepend managed SevenOS PATH block to %q %q %q\n' "$PROFILE_HOME" "$BASHRC_HOME" "$ZSHRC_HOME"
    return 0
  fi

  for shell_file in "$PROFILE_HOME" "$BASHRC_HOME" "$ZSHRC_HOME"; do
    touch "$shell_file"
    cp -a "$shell_file" "$(backup_path "$shell_file")"
    python - "$shell_file" "$marker_start" "$marker_end" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
start = sys.argv[2]
end = sys.argv[3]
text = path.read_text()
lines = text.splitlines()
out = []
inside = False
for line in lines:
    if line.strip() == start:
        inside = True
        continue
    if line.strip() == end:
        inside = False
        continue
    if not inside:
        out.append(line)

block = [
    "",
    start,
    'case ":$PATH:" in',
    '  ":$HOME/.local/bin:"*) ;;',
    '  *) export PATH="$HOME/.local/bin:${PATH//$HOME/.local/bin:/}" ;;',
    'esac',
    end,
]
path.write_text("\n".join(out + block).rstrip() + "\n")
PY
  done

  export PATH="$BIN_HOME:${PATH//$BIN_HOME:/}"
  log_warn "SevenOS user commands now take priority in new shells."
  log_warn "For this terminal, run: export PATH=\"\$HOME/.local/bin:\${PATH//\$HOME/.local/bin:/}\" && hash -r"
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

  if ! command -v sudo >/dev/null 2>&1; then
    if [[ "$SYSTEM_INSTALL_WARNED" -eq 0 ]]; then
      log_warn "sudo unavailable; skipping /usr/local/bin command install."
      SYSTEM_INSTALL_WARNED=1
    fi
    return 0
  fi

  if [[ ! -t 0 ]] && ! sudo -n true >/dev/null 2>&1; then
    if [[ "$SYSTEM_INSTALL_WARNED" -eq 0 ]]; then
      log_warn "Skipping /usr/local/bin command install because sudo needs an interactive password."
      log_warn "User commands are still installed in $BIN_HOME."
      SYSTEM_INSTALL_WARNED=1
    fi
    return 0
  fi

  tmp_file="$(mktemp)"
  write_command_wrapper "$tmp_file" "$source_file"
  if ! sudo install -Dm755 "$tmp_file" "$SYSTEM_BIN_HOME/$command_name"; then
    log_warn "Could not install $command_name into $SYSTEM_BIN_HOME."
    log_warn "The user command is still available at $BIN_HOME/$command_name."
  fi
  rm -f "$tmp_file"
}

log_info "Installing SevenOS CLI..."
run_cmd mkdir -p "$BIN_HOME"
install_user_command "$ROOT_DIR/bin/seven" seven
install_user_command "$ROOT_DIR/bin/seven-daemon" seven-daemon
install_user_command "$ROOT_DIR/bin/seven-power" seven-power
install_user_command "$ROOT_DIR/bin/seven-welcome" seven-welcome
install_user_command "$ROOT_DIR/bin/seven-hub-native" seven-hub-native
install_user_command "$ROOT_DIR/bin/seven-settings" seven-settings
install_user_command "$ROOT_DIR/bin/seven-settings-native" seven-settings-native
install_user_command "$ROOT_DIR/bin/seven-help" seven-help
install_user_command "$ROOT_DIR/bin/seven-apps" seven-apps
install_user_command "$ROOT_DIR/bin/seven-launchpad-native" seven-launchpad-native
install_user_command "$ROOT_DIR/bin/seven-dock" seven-dock
install_user_command "$ROOT_DIR/bin/seven-dock-native" seven-dock-native
install_user_command "$ROOT_DIR/bin/seven-overview" seven-overview
install_user_command "$ROOT_DIR/bin/seven-quick-settings" seven-quick-settings
install_user_command "$ROOT_DIR/bin/seven-quick-settings-native" seven-quick-settings-native
install_user_command "$ROOT_DIR/bin/seven-screenshot" seven-screenshot
install_user_command "$ROOT_DIR/bin/seven-shell-panel" seven-shell-panel
install_user_command "$ROOT_DIR/bin/seven-terminal" seven-terminal
install_user_command "$ROOT_DIR/bin/seven-terminal-native" seven-terminal-native
install_user_command "$ROOT_DIR/bin/seven-terminal-shell" seven-terminal-shell
install_user_command "$ROOT_DIR/bin/seven-files" seven-files
install_user_command "$ROOT_DIR/bin/seven-files-native" seven-files-native
install_user_command "$ROOT_DIR/bin/seven-wallpaper" seven-wallpaper
install_user_command "$ROOT_DIR/bin/seven-shell-preview" seven-shell-preview
install_user_command "$ROOT_DIR/bin/seven-spotlight" seven-spotlight
install_user_command "$ROOT_DIR/bin/seven-spotlight-native" seven-spotlight-native
install_user_command "$ROOT_DIR/bin/seven-session" seven-session
install_user_command "$ROOT_DIR/bin/seven-session-status" seven-session-status
install_user_command "$ROOT_DIR/bin/seven-country" seven-country
install_user_command "$ROOT_DIR/bin/seven-waybar-action" seven-waybar-action
install_user_command "$ROOT_DIR/bin/seven-notification-center-native" seven-notification-center-native
install_user_command "$ROOT_DIR/bin/seven-profile-center-native" seven-profile-center-native
install_user_command "$ROOT_DIR/bin/seven-shield-center-native" seven-shield-center-native
install_user_command "$ROOT_DIR/bin/seven-waybar-center-native" seven-waybar-center-native
install_user_command "$ROOT_DIR/bin/seven-waybar-notifications" seven-waybar-notifications
install_user_command "$ROOT_DIR/bin/seven-waybar-profile" seven-waybar-profile
install_user_command "$ROOT_DIR/bin/seven-waybar-security" seven-waybar-security
install_user_command "$ROOT_DIR/bin/seven-waybar" seven-waybar
install_user_command "$ROOT_DIR/bin/seven-wifi" seven-wifi
install_user_command "$ROOT_DIR/bin/seven-windows-assistant" seven-windows-assistant
install_user_command "$ROOT_DIR/bin/sevenpkg" sevenpkg
install_user_command "$ROOT_DIR/bin/sevenosctl" sevenosctl
ensure_user_bin_path

log_info "Installing SevenOS CLI into /usr/local/bin for reliable terminal access..."
install_system_command "$ROOT_DIR/bin/seven" seven
install_system_command "$ROOT_DIR/bin/seven-daemon" seven-daemon
install_system_command "$ROOT_DIR/bin/sevenpkg" sevenpkg
install_system_command "$ROOT_DIR/bin/seven-country" seven-country
install_system_command "$ROOT_DIR/bin/seven-power" seven-power
install_system_command "$ROOT_DIR/bin/seven-welcome" seven-welcome
install_system_command "$ROOT_DIR/bin/seven-hub-native" seven-hub-native
install_system_command "$ROOT_DIR/bin/seven-settings" seven-settings
install_system_command "$ROOT_DIR/bin/seven-settings-native" seven-settings-native
install_system_command "$ROOT_DIR/bin/seven-help" seven-help
install_system_command "$ROOT_DIR/bin/seven-apps" seven-apps
install_system_command "$ROOT_DIR/bin/seven-launchpad-native" seven-launchpad-native
install_system_command "$ROOT_DIR/bin/seven-dock" seven-dock
install_system_command "$ROOT_DIR/bin/seven-dock-native" seven-dock-native
install_system_command "$ROOT_DIR/bin/seven-overview" seven-overview
install_system_command "$ROOT_DIR/bin/seven-quick-settings" seven-quick-settings
install_system_command "$ROOT_DIR/bin/seven-quick-settings-native" seven-quick-settings-native
install_system_command "$ROOT_DIR/bin/seven-screenshot" seven-screenshot
install_system_command "$ROOT_DIR/bin/seven-shell-panel" seven-shell-panel
install_system_command "$ROOT_DIR/bin/seven-terminal" seven-terminal
install_system_command "$ROOT_DIR/bin/seven-terminal-native" seven-terminal-native
install_system_command "$ROOT_DIR/bin/seven-terminal-shell" seven-terminal-shell
install_system_command "$ROOT_DIR/bin/seven-files" seven-files
install_system_command "$ROOT_DIR/bin/seven-files-native" seven-files-native
install_system_command "$ROOT_DIR/bin/seven-wallpaper" seven-wallpaper
install_system_command "$ROOT_DIR/bin/seven-shell-preview" seven-shell-preview
install_system_command "$ROOT_DIR/bin/seven-spotlight" seven-spotlight
install_system_command "$ROOT_DIR/bin/seven-spotlight-native" seven-spotlight-native
install_system_command "$ROOT_DIR/bin/seven-session" seven-session
install_system_command "$ROOT_DIR/bin/seven-session-status" seven-session-status
install_system_command "$ROOT_DIR/bin/seven-waybar-action" seven-waybar-action
install_system_command "$ROOT_DIR/bin/seven-notification-center-native" seven-notification-center-native
install_system_command "$ROOT_DIR/bin/seven-profile-center-native" seven-profile-center-native
install_system_command "$ROOT_DIR/bin/seven-shield-center-native" seven-shield-center-native
install_system_command "$ROOT_DIR/bin/seven-waybar-center-native" seven-waybar-center-native
install_system_command "$ROOT_DIR/bin/seven-waybar-notifications" seven-waybar-notifications
install_system_command "$ROOT_DIR/bin/seven-waybar-profile" seven-waybar-profile
install_system_command "$ROOT_DIR/bin/seven-waybar-security" seven-waybar-security
install_system_command "$ROOT_DIR/bin/seven-waybar" seven-waybar
install_system_command "$ROOT_DIR/bin/seven-wifi" seven-wifi
install_system_command "$ROOT_DIR/bin/seven-windows-assistant" seven-windows-assistant
install_system_command "$ROOT_DIR/bin/sevenosctl" sevenosctl

log_success "SevenOS CLI installed. Run: seven status or sevenpkg meta"
