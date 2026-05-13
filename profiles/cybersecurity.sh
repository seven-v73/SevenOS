#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS CYBERSECURITY profile..."
install_package_file "$ROOT_DIR/scripts/packages-cybersecurity.txt"

if ! is_dry_run; then
  sudo usermod -aG wireshark "$USER" || log_warn "Could not add $USER to wireshark group."
  log_warn "Use security tooling only on systems and networks where you have permission."
else
  printf 'sudo usermod -aG wireshark %q\n' "$USER"
fi

log_success "CYBERSECURITY profile installed."
