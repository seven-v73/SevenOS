#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

require_arch
require_command pacman

log_info "Checking shell syntax..."
bash -n \
  "$ROOT_DIR/install.sh" \
  "$ROOT_DIR/bootstrap.sh" \
  "$ROOT_DIR"/profiles/*.sh \
  "$ROOT_DIR/scripts/lib.sh" \
  "$ROOT_DIR/scripts/doctor.sh" \
  "$ROOT_DIR/scripts/status.sh" \
  "$ROOT_DIR/scripts/apply-theme.sh" \
  "$ROOT_DIR/scripts/build-iso.sh" \
  "$ROOT_DIR/security/hardening.sh" \
  "$ROOT_DIR/vm/check.sh" \
  "$ROOT_DIR/vm/network.sh" \
  "$ROOT_DIR/vm/windows-vm.sh" \
  "$ROOT_DIR/seven-hub/install.sh" \
  "$ROOT_DIR/seven-hub/bin/seven-hub"
bash -n "$ROOT_DIR/security/hardening.sh"

log_info "Checking package names against pacman metadata..."
missing=0

for package_file in "$ROOT_DIR"/scripts/packages-*.txt; do
  while IFS= read -r package; do
    package="${package%%#*}"
    package="${package//[[:space:]]/}"

    [[ -z "$package" ]] && continue

    if ! pacman -Si "$package" >/dev/null 2>&1; then
      printf '%s: missing package: %s\n' "${package_file#$ROOT_DIR/}" "$package" >&2
      missing=1
    fi
  done < "$package_file"
done

if [[ "$missing" -ne 0 ]]; then
  log_error "Some packages were not found in enabled pacman repositories."
  exit 1
fi

log_info "Checking installer dry-run..."
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" all --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" theme --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" iso --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" vm-network --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" vm-windows --iso /tmp/windows.iso --dry-run >/dev/null

log_success "All checks passed."
