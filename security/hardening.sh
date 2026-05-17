#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/security"
UFW_DEGRADED_MARKER="$STATE_DIR/ufw-degraded"

log_info "Applying SevenOS base security hardening..."
install_package_file "$ROOT_DIR/scripts/packages-security.txt"

try_security_cmd() {
  local description="$1"
  shift

  if is_dry_run; then
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  if "$@"; then
    return 0
  fi

  log_warn "$description failed."
  return 1
}

diagnose_ufw_failure() {
  local kernel modules_dir
  kernel="$(uname -r)"
  modules_dir="/usr/lib/modules/$kernel"

  if ! is_dry_run; then
    mkdir -p "$STATE_DIR"
    {
      printf 'timestamp=%s\n' "$(date -Is)"
      printf 'kernel=%s\n' "$kernel"
      printf 'modules_dir=%s\n' "$modules_dir"
    } > "$UFW_DEGRADED_MARKER"
  fi

  log_warn "UFW could not fully apply its iptables/nftables rules."
  if [[ ! -d "$modules_dir" ]]; then
    log_warn "Kernel modules for the running kernel are missing: $modules_dir"
    log_warn "This usually happens after a kernel upgrade. Reboot, then run: seven shield enable"
  else
    log_warn "Kernel modules exist for $kernel; this may be a netfilter backend/module issue."
    log_warn "Recommended next check: sudo modprobe nf_tables ip_tables ip6_tables x_tables"
  fi
}

try_security_cmd "Set default incoming policy" sudo ufw default deny incoming || true
try_security_cmd "Set default outgoing policy" sudo ufw default allow outgoing || true

if systemctl is-active --quiet sshd.service 2>/dev/null || systemctl is-enabled --quiet sshd.service 2>/dev/null; then
  log_warn "sshd is active or enabled; allowing SSH before enabling UFW."
  try_security_cmd "Allow OpenSSH through UFW" sudo ufw allow OpenSSH || true
fi

try_security_cmd "Enable UFW rules" sudo ufw --force enable || diagnose_ufw_failure

if ! enable_service ufw.service; then
  log_warn "ufw.service could not be enabled through systemd."
  diagnose_ufw_failure
fi

if ! is_dry_run && sudo -n ufw status 2>/dev/null | head -n 1 | grep -qi 'active'; then
  rm -f "$UFW_DEGRADED_MARKER"
fi

log_success "Base security hardening applied."
log_info "Next check: ./install.sh post-install && seven readiness"
