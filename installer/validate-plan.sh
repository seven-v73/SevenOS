#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"
source "$ROOT_DIR/installer/lib.sh"

PLAN_FILE="$ROOT_DIR/out/installer/sevenos-install-plan.conf"

usage() {
  cat <<'EOF'
SevenOS install plan validator

Usage:
  ./install.sh installer-check [--plan PATH] [--dry-run]

Validates a generated install plan. This command is non-destructive.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --plan) PLAN_FILE="${2:-}"; shift 2 ;;
    --dry-run) export SEVENOS_DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

installer_source_plan_or_default "$PLAN_FILE"

errors=0

require_value() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    log_error "Missing required plan value: $name"
    errors=$((errors + 1))
  fi
}

require_value target_disk
require_value hostname
require_value username
require_value luks
require_value profiles
require_value filesystem
require_value bootloader
require_value timezone
require_value locale
require_value keymap
require_value swap

if [[ "${target_disk:-}" != /dev/* ]]; then
  log_error "target_disk must look like /dev/..."
  errors=$((errors + 1))
fi

if [[ "${target_disk:-}" == *[0-9] && "${target_disk:-}" != /dev/nvme*n* && "${target_disk:-}" != /dev/mmcblk* ]]; then
  log_warn "target_disk looks like a partition, not a whole disk: $target_disk"
fi

if [[ ! "${hostname:-}" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]]; then
  log_error "hostname contains invalid characters: ${hostname:-}"
  errors=$((errors + 1))
fi

if [[ ! "${username:-}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
  log_error "username contains invalid characters: ${username:-}"
  errors=$((errors + 1))
fi

case "${luks:-}" in
  yes|no) ;;
  *)
    log_error "luks must be yes or no"
    errors=$((errors + 1))
    ;;
esac

case "${filesystem:-}" in
  btrfs|ext4) ;;
  *) log_error "filesystem must be btrfs or ext4"; errors=$((errors + 1)) ;;
esac

case "${bootloader:-}" in
  systemd-boot|grub) ;;
  *) log_error "bootloader must be systemd-boot or grub"; errors=$((errors + 1)) ;;
esac

case "${swap:-}" in
  zram|swapfile|none) ;;
  *) log_error "swap must be zram, swapfile, or none"; errors=$((errors + 1)) ;;
esac

if [[ ! "${timezone:-}" =~ ^[A-Za-z0-9_./+-]+$ ]]; then
  log_error "timezone contains invalid characters: ${timezone:-}"
  errors=$((errors + 1))
fi

if [[ ! "${locale:-}" =~ ^[A-Za-z_]+(\.[A-Za-z0-9-]+)?$ ]]; then
  log_error "locale contains invalid characters: ${locale:-}"
  errors=$((errors + 1))
fi

if [[ ! "${keymap:-}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  log_error "keymap contains invalid characters: ${keymap:-}"
  errors=$((errors + 1))
fi

IFS=',' read -r -a profile_list <<< "${profiles:-}"
for profile in "${profile_list[@]}"; do
  case "$profile" in
    base|dev|cybersecurity|creation|windows) ;;
    "")
      log_error "profiles contains an empty entry"
      errors=$((errors + 1))
      ;;
    *)
      log_error "unknown profile in plan: $profile"
      errors=$((errors + 1))
      ;;
  esac
done

if [[ "$errors" -ne 0 ]]; then
  log_error "Install plan validation failed with $errors error(s)."
  exit 1
fi

log_success "Install plan is valid: $PLAN_FILE"
