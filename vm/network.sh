#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Configuring libvirt default network..."

if is_dry_run; then
  printf 'sudo virsh -c qemu:///system net-define /usr/share/libvirt/networks/default.xml\n'
  printf 'sudo virsh -c qemu:///system net-start default\n'
  printf 'sudo virsh -c qemu:///system net-autostart default\n'
  exit 0
fi

require_command virsh

if ! virsh -c qemu:///system net-info default >/dev/null 2>&1; then
  sudo virsh -c qemu:///system net-define /usr/share/libvirt/networks/default.xml
fi

sudo virsh -c qemu:///system net-start default >/dev/null 2>&1 || true
sudo virsh -c qemu:///system net-autostart default >/dev/null

log_success "libvirt default network is configured."
log_info "If VM commands still fail, run './install.sh post-install' and confirm libvirtd is active."
