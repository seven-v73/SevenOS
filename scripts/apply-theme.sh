#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

log_info "Applying SevenOS African first theme..."
copy_config_file "$ROOT_DIR/hyprland/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"
copy_config_file "$ROOT_DIR/hyprland/hyprpaper.conf" "$CONFIG_HOME/hypr/hyprpaper.conf"
copy_config_dir "$ROOT_DIR/hyprland/waybar" "$CONFIG_HOME/waybar"
copy_config_dir "$ROOT_DIR/hyprland/rofi" "$CONFIG_HOME/rofi"
copy_config_dir "$ROOT_DIR/hyprland/mako" "$CONFIG_HOME/mako"

run_cmd mkdir -p "$DATA_HOME/sevenos/wallpapers" "$DATA_HOME/icons/hicolor/scalable/apps"
run_cmd cp "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" "$DATA_HOME/sevenos/wallpapers/wallpaper-sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos.svg" "$DATA_HOME/icons/hicolor/scalable/apps/sevenos.svg"

if command -v rsvg-convert >/dev/null 2>&1; then
  run_cmd rsvg-convert -w 1920 -h 1080 "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" -o "$DATA_HOME/sevenos/wallpapers/wallpaper-sevenos.png"
elif command -v magick >/dev/null 2>&1; then
  run_cmd magick "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" "$DATA_HOME/sevenos/wallpapers/wallpaper-sevenos.png"
else
  log_warn "No SVG renderer found. Install librsvg or imagemagick to generate the PNG wallpaper."
fi

log_success "SevenOS theme applied."
log_info "Reload Hyprland or restart Hyprpaper/Waybar/Rofi to see every change."
