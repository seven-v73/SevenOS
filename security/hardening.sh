#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Applying SevenOS base security hardening..."
install_package_file "$ROOT_DIR/scripts/packages-security.txt"

enable_service ufw.service || log_warn "ufw could not be enabled."
run_cmd sudo ufw default deny incoming
run_cmd sudo ufw default allow outgoing

if systemctl is-active --quiet sshd.service 2>/dev/null || systemctl is-enabled --quiet sshd.service 2>/dev/null; then
  log_warn "sshd is active or enabled; allowing SSH before enabling UFW."
  run_cmd sudo ufw allow OpenSSH
fi

run_cmd sudo ufw --force enable

log_success "Base security hardening applied."
log_info "Next check: ./install.sh post-install && seven readiness"
