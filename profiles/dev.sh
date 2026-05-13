#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS DEV profile..."
install_package_file "$ROOT_DIR/scripts/packages-dev.txt"

if ! is_dry_run; then
  enable_service docker.service || log_warn "Docker service could not be enabled."
  add_user_to_group docker "$USER"
else
  enable_service docker.service
  add_user_to_group docker "$USER"
fi

log_success "DEV profile installed."
