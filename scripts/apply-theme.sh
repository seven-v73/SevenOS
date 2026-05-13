#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SHELL_HOOK="$CONFIG_HOME/sevenos/shell/terminal-country.sh"

install_shell_hook() {
  local rc_file="$1"
  local marker_start="# >>> SevenOS terminal country signal"
  local marker_end="# <<< SevenOS terminal country signal"

  log_info "Enabling SevenOS terminal country signal in ${rc_file#$HOME/}"

  if is_dry_run; then
    printf 'touch %q\n' "$rc_file"
    printf 'append managed SevenOS terminal country block to %q\n' "$rc_file"
    return 0
  fi

  touch "$rc_file"
  if grep -qF "$marker_start" "$rc_file"; then
    return 0
  fi

  cp -a "$rc_file" "$(backup_path "$rc_file")"
  {
    printf '\n%s\n' "$marker_start"
    printf 'if [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/shell/terminal-country.sh" ]; then\n'
    printf '  . "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/shell/terminal-country.sh"\n'
    printf 'fi\n'
    printf '%s\n' "$marker_end"
  } >> "$rc_file"
}

log_info "Applying SevenOS African first theme..."
copy_config_file "$ROOT_DIR/hyprland/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"
copy_config_file "$ROOT_DIR/hyprland/hyprpaper.conf" "$CONFIG_HOME/hypr/hyprpaper.conf"
copy_config_dir "$ROOT_DIR/hyprland/waybar" "$CONFIG_HOME/waybar"
copy_config_dir "$ROOT_DIR/hyprland/rofi" "$CONFIG_HOME/rofi"
copy_config_dir "$ROOT_DIR/hyprland/mako" "$CONFIG_HOME/mako"
copy_config_dir "$ROOT_DIR/hyprland/kitty" "$CONFIG_HOME/kitty"
copy_config_file "$ROOT_DIR/branding/shell/terminal-country.sh" "$SHELL_HOOK"

run_cmd mkdir -p "$DATA_HOME/sevenos/wallpapers" "$DATA_HOME/sevenos/countries" "$DATA_HOME/icons/hicolor/scalable/apps"
run_cmd cp "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" "$DATA_HOME/sevenos/wallpapers/wallpaper-sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos.svg" "$DATA_HOME/icons/hicolor/scalable/apps/sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/countries/africa.tsv" "$DATA_HOME/sevenos/countries/africa.tsv"

if command -v rsvg-convert >/dev/null 2>&1; then
  run_cmd rsvg-convert -w 1920 -h 1080 "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" -o "$DATA_HOME/sevenos/wallpapers/wallpaper-sevenos.png"
elif command -v magick >/dev/null 2>&1; then
  run_cmd magick "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" "$DATA_HOME/sevenos/wallpapers/wallpaper-sevenos.png"
else
  log_warn "No SVG renderer found. Install librsvg or imagemagick to generate the PNG wallpaper."
fi

install_shell_hook "$HOME/.bashrc"
install_shell_hook "$HOME/.zshrc"

log_success "SevenOS theme applied."
log_info "Reload Hyprland or restart Hyprpaper/Waybar/Rofi/Kitty to see every change."
log_info "Disable terminal country signals with: export SEVENOS_TERMINAL_COUNTRY=0"
