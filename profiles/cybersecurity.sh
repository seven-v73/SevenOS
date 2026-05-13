#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS CYBERSECURITY profile..."
install_package_file "$ROOT_DIR/scripts/packages-cybersecurity.txt"

add_user_to_group wireshark "$USER"
log_warn "Use security tooling only on systems and networks where you have permission."

log_success "CYBERSECURITY profile installed."
