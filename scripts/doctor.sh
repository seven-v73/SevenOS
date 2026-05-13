#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

status_ok() {
  printf '[OK] %s\n' "$*"
}

status_warn() {
  printf '[WARN] %s\n' "$*"
}

status_fail() {
  printf '[FAIL] %s\n' "$*"
}

log_info "Running SevenOS host readiness checks..."

if [[ -f /etc/arch-release ]]; then
  status_ok "Arch-based system detected"
else
  status_fail "SevenOS Phase 1 expects Arch Linux or an Arch-based system"
fi

if command -v pacman >/dev/null 2>&1; then
  status_ok "pacman available"
else
  status_fail "pacman missing"
fi

if command -v sudo >/dev/null 2>&1; then
  status_ok "sudo available"
else
  status_fail "sudo missing"
fi

memory_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
memory_gb="$((memory_kb / 1024 / 1024))"

if (( memory_gb >= 16 )); then
  status_ok "RAM: ${memory_gb} GB"
elif (( memory_gb >= 8 )); then
  status_warn "RAM: ${memory_gb} GB, usable but 16 GB is recommended"
else
  status_fail "RAM: ${memory_gb} GB, SevenOS recommends at least 8 GB"
fi

if grep -Eiq '(vmx|svm)' /proc/cpuinfo; then
  status_ok "CPU virtualization flag detected"
else
  status_warn "CPU virtualization flag not detected; Windows VM workflows may not work"
fi

if command -v lspci >/dev/null 2>&1; then
  gpu_info="$(lspci | grep -Ei 'vga|3d|display' || true)"
  if [[ -n "$gpu_info" ]]; then
    status_ok "GPU detected"
    printf '%s\n' "$gpu_info"
  else
    status_warn "No GPU entry found through lspci"
  fi
else
  status_warn "lspci missing; install pciutils for GPU detection"
fi

if [[ -d /sys/firmware/efi ]]; then
  status_ok "UEFI boot detected"
else
  status_warn "UEFI firmware path not detected"
fi

printf '\nCyber readiness:\n'
if command -v firejail >/dev/null 2>&1; then
  status_ok "Firejail available for SevenOS cyber labs"
else
  status_warn "Firejail missing; install './install.sh cybersecurity sandbox' for cyber labs"
fi

if command -v bwrap >/dev/null 2>&1; then
  status_ok "Bubblewrap available"
else
  status_warn "Bubblewrap missing; sandbox isolation is incomplete"
fi

if id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx wireshark; then
  status_ok "$USER is in wireshark group"
else
  status_warn "$USER is not in wireshark group; packet capture may need elevated privileges"
fi

if pacman-conf --repo-list 2>/dev/null | grep -qx 'blackarch'; then
  status_ok "BlackArch repository bridge enabled"
else
  status_warn "BlackArch bridge disabled; this is recommended until specialized tools are needed"
fi

log_success "Doctor checks completed."
