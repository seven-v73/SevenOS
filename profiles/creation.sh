#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS CREATION profile..."
install_package_file "$ROOT_DIR/scripts/packages-creation.txt"

log_warn "DaVinci Resolve is intentionally not installed automatically. Add it later through an AUR workflow or manual package."
log_success "CREATION profile installed."
