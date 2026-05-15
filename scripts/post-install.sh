#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

warnings=0

warn_item() {
  warnings=$((warnings + 1))
  printf '[WARN] %s\n' "$*"
}

ok_item() {
  printf '[OK] %s\n' "$*"
}

section() {
  printf '\n== %s ==\n' "$1"
}

root_check() {
  section "User Context"
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    warn_item "post-install is running as root"
    printf '  run SevenOS install commands as your normal user, not with sudo\n'
  else
    ok_item "running as normal user: $USER"
  fi
}

path_check() {
  section "PATH"
  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    ok_item "~/.local/bin is in PATH"
  else
    warn_item "~/.local/bin is not in PATH"
    printf '  run: export PATH="$HOME/.local/bin:$PATH"\n'
    printf '  then open a new shell after ./install.sh cli or ./install.sh base\n'
  fi
}

desktop_config_check() {
  section "Desktop Configs"
  local missing=0
  local path

  for path in \
    "$HOME/.config/hypr/hyprland.conf" \
    "$HOME/.config/waybar/config.jsonc" \
    "$HOME/.config/rofi/config.rasi" \
    "$HOME/.config/mako/config" \
    "$HOME/.config/kitty/kitty.conf"; do
    if [[ -s "$path" ]]; then
      ok_item "${path#$HOME/}"
    else
      warn_item "missing ${path#$HOME/}"
      missing=$((missing + 1))
    fi
  done

  if [[ "$missing" -gt 0 ]]; then
    printf '  run: seven repair ux --apply\n'
    printf '  or:  ./install.sh theme\n'
    printf '  then log out and back into Hyprland\n'
  fi

  if [[ -s "$HOME/.config/hypr/hyprland.conf" ]]; then
    if grep -q 'SevenOS Hyprland config' "$HOME/.config/hypr/hyprland.conf"; then
      ok_item "Hyprland config is SevenOS branded"
    else
      warn_item "Hyprland config exists but does not look like SevenOS"
      printf '  run: seven repair ux --apply\n'
      printf '  then log out and back into Hyprland\n'
    fi
  fi
}

toolkit_theme_check() {
  section "Toolkit Theme"
  local path
  for path in \
    "$HOME/.config/gtk-3.0/settings.ini" \
    "$HOME/.config/gtk-4.0/settings.ini" \
    "$HOME/.config/qt5ct/qt5ct.conf" \
    "$HOME/.config/qt6ct/qt6ct.conf"; do
    if [[ -s "$path" ]]; then
      ok_item "${path#$HOME/}"
    else
      warn_item "missing ${path#$HOME/}"
    fi
  done

  if command -v gsettings >/dev/null 2>&1; then
    local color_scheme
    color_scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)"
    if [[ "$color_scheme" == *prefer-light* ]]; then
      ok_item "GTK color-scheme prefer-light"
    else
      warn_item "GTK color-scheme is not prefer-light"
      printf '  run: ./install.sh theme\n'
    fi
  fi
}

command_check() {
  section "SevenOS Commands"
  local command_name
  local hub_command="seven-hub"
  local control_command="seven-control-center"

  if is_dry_run; then
    hub_command="$ROOT_DIR/seven-hub/bin/seven-hub"
    control_command="$ROOT_DIR/seven-hub/bin/seven-control-center"
  fi

  for command_name in seven sevenpkg seven-country seven-files seven-hub seven-control-center seven-session seven-power; do
    if command -v "$command_name" >/dev/null 2>&1; then
      ok_item "$command_name available"
    elif [[ -x "$HOME/.local/bin/$command_name" ]]; then
      warn_item "$command_name installed in ~/.local/bin but not visible in this shell"
      printf '  run: export PATH="$HOME/.local/bin:$PATH"\n'
    elif [[ -x "$ROOT_DIR/bin/$command_name" || -x "$ROOT_DIR/seven-hub/bin/$command_name" ]]; then
      warn_item "$command_name is available in the repository but not installed to ~/.local/bin"
      printf '  run: ./install.sh cli\n'
      if [[ "$command_name" == "seven-hub" ]]; then
        printf '  run: ./install.sh hub\n'
      fi
    else
      warn_item "$command_name missing"
    fi
  done

  if command -v seven-hub >/dev/null 2>&1 || [[ -x "$hub_command" ]]; then
    if "$hub_command" doctor >/dev/null 2>&1; then
      ok_item "seven-hub doctor"
    else
      warn_item "seven-hub exists but fails its doctor check"
      printf '  run: ./install.sh hub\n'
      printf '  if /usr/local/bin shadows the user wrapper, run: command -v seven-hub\n'
    fi
  fi

  if command -v seven-control-center >/dev/null 2>&1 || [[ -x "$control_command" ]]; then
    if "$control_command" status >/dev/null 2>&1; then
      ok_item "seven-control-center status"
    else
      warn_item "seven-control-center exists but status failed"
      printf '  run: ./install.sh hub\n'
    fi
  fi
}

group_check() {
  section "Group Membership"
  local group
  for group in docker libvirt wireshark; do
    if getent group "$group" >/dev/null 2>&1; then
      if id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
        ok_item "$USER is in $group"
      else
        warn_item "$USER is not in $group"
        printf '  if just added, log out and back in\n'
      fi
    fi
  done
}

service_check() {
  section "Services"
  local service
  for service in NetworkManager.service docker.service libvirtd.service ufw.service; do
    if systemctl list-unit-files "$service" >/dev/null 2>&1; then
      if systemctl is-active --quiet "$service" 2>/dev/null; then
        ok_item "$service active"
      else
        warn_item "$service not active"
      fi
    fi
  done

  if systemctl --user is-enabled --quiet seven-server.service 2>/dev/null; then
    if systemctl --user is-active --quiet seven-server.service 2>/dev/null; then
      ok_item "seven-server user service active"
    else
      warn_item "seven-server user service enabled but not active"
      printf '  run: seven server start\n'
    fi
  fi
}

files_check() {
  section "Files Experience"
  local command_name
  local available=0

  for command_name in nautilus nemo thunar dolphin pcmanfm xdg-open; do
    if command -v "$command_name" >/dev/null 2>&1; then
      ok_item "$command_name available"
      available=1
      break
    fi
  done

  if [[ "$available" -eq 0 ]]; then
    warn_item "no graphical file manager found"
    printf '  run: ./install.sh base --yes\n'
  fi

  if command -v gio >/dev/null 2>&1; then
    ok_item "GVfs/GIO available for trash, recent files and volumes"
  else
    warn_item "gio missing; removable drives and trash integration may be limited"
    printf '  run: sudo pacman -S --needed gvfs\n'
  fi
}

lab_check() {
  section "Cyber Lab Context"
  if [[ "${HOSTNAME:-}" == sevenos-* ]] || hostname 2>/dev/null | grep -q '^sevenos-'; then
    warn_item "This looks like an isolated SevenOS lab shell"
    printf '  type: exit\n'
    printf '  then run SevenOS commands from the normal shell\n'
  else
    ok_item "normal host context"
  fi
}

next_steps() {
  section "Next Steps"
  printf '  seven status\n'
  printf '  seven doctor\n'
  printf '  seven readiness\n'
  printf '  seven phase-gate\n'
  printf '  seven repair\n'
  printf '  seven repair ux --apply\n'
}

printf 'SevenOS Post-Install Check\n'
printf '==========================\n'
root_check
path_check
command_check
desktop_config_check
toolkit_theme_check
group_check
service_check
files_check
lab_check
next_steps

if [[ "$warnings" -gt 0 ]]; then
  log_warn "Post-install check completed with $warnings warning(s)."
else
  log_success "Post-install check completed cleanly."
fi
