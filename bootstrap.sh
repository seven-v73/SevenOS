#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS base desktop layer..."
install_package_file "$ROOT_DIR/scripts/packages-base.txt"

"$ROOT_DIR/branding/apply-branding.sh"
"$ROOT_DIR/scripts/install-cli.sh"
"$ROOT_DIR/scripts/apply-theme.sh"

log_success "Base desktop layer installed."
log_info "Start Hyprland from your display manager or TTY after logging out."
