#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS DEV profile..."
install_package_file "$ROOT_DIR/scripts/packages-dev.txt"

if ! is_dry_run; then
  sudo systemctl enable --now docker.service || log_warn "Docker service could not be enabled."
  if ! groups "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER" || log_warn "Could not add $USER to docker group."
    log_warn "Log out and back in before using Docker without sudo."
  fi
else
  printf 'sudo systemctl enable --now docker.service\n'
  printf 'sudo usermod -aG docker %q\n' "$USER"
fi

log_success "DEV profile installed."
