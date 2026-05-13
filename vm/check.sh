#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ok() {
  printf '[OK] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*"
}

command_status() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name available"
  else
    fail "$command_name missing"
  fi
}

package_status() {
  local package="$1"
  if pacman -Q "$package" >/dev/null 2>&1; then
    ok "$package installed"
  else
    warn "$package not installed"
  fi
}

service_status() {
  local service="$1"
  if systemctl is-active --quiet "$service"; then
    ok "$service active"
  elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
    warn "$service enabled but not active"
  else
    warn "$service inactive"
  fi
}

log_info "Checking SevenOS VM readiness..."

if grep -Eiq '(vmx|svm)' /proc/cpuinfo; then
  ok "CPU virtualization flag detected"
else
  fail "CPU virtualization flag not detected. Enable VT-x or AMD-V in firmware."
fi

if [[ -e /dev/kvm ]]; then
  ok "/dev/kvm available"
else
  fail "/dev/kvm missing. KVM acceleration is not available."
fi

command_status qemu-system-x86_64
command_status virt-manager
command_status virt-install
command_status virsh

package_status qemu-full
package_status virt-manager
package_status edk2-ovmf
package_status dnsmasq

service_status libvirtd.service

if groups "$USER" | grep -qw libvirt; then
  ok "$USER is in libvirt"
else
  warn "$USER is not in libvirt. Run './install.sh windows' and log out/in."
fi

if command -v virsh >/dev/null 2>&1 && virsh -c qemu:///system net-info default >/dev/null 2>&1; then
  ok "libvirt default network exists"
  if virsh -c qemu:///system net-info default | grep -q 'Active:.*yes'; then
    ok "libvirt default network active"
  else
    warn "libvirt default network exists but is not active"
  fi
else
  warn "libvirt default network not found"
fi

log_success "VM readiness check completed."
