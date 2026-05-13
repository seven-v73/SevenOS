#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

log_info "Applying SevenOS African first theme..."
copy_config_file "$ROOT_DIR/hyprland/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"
copy_config_dir "$ROOT_DIR/hyprland/waybar" "$CONFIG_HOME/waybar"
copy_config_dir "$ROOT_DIR/hyprland/rofi" "$CONFIG_HOME/rofi"

log_success "SevenOS theme applied."
log_info "Reload Hyprland or restart Waybar/Rofi to see every change."
