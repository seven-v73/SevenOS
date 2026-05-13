#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS base desktop layer..."
install_package_file "$ROOT_DIR/scripts/packages-base.txt"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

copy_config_file "$ROOT_DIR/hyprland/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"
copy_config_dir "$ROOT_DIR/hyprland/waybar" "$CONFIG_HOME/waybar"
copy_config_dir "$ROOT_DIR/hyprland/rofi" "$CONFIG_HOME/rofi"

log_success "Base desktop layer installed."
log_info "Start Hyprland from your display manager or TTY after logging out."
