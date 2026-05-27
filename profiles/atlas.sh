#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS ATLAS Explorer mini OS..."
install_package_file "$ROOT_DIR/scripts/packages-atlas.txt"

log_info "Preparing Atlas workspace..."
for dir in "$HOME/Atlas" "$HOME/Atlas/Documents" "$HOME/Atlas/Maps" "$HOME/Atlas/References" "$HOME/Atlas/Trips" "$HOME/Atlas/Scans"; do
  if is_dry_run; then
    echo "mkdir -p $dir"
  else
    mkdir -p "$dir"
  fi
done

log_success "ATLAS Explorer mini OS installed."
log_info "Next: seven profile activate atlas && seven-mini-os-center atlas"
