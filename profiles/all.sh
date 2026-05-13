#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS ALL-IN-ONE profile..."
"$ROOT_DIR/bootstrap.sh"
"$ROOT_DIR/profiles/dev.sh"
"$ROOT_DIR/profiles/cybersecurity.sh"
"$ROOT_DIR/profiles/creation.sh"
"$ROOT_DIR/profiles/windows.sh"
"$ROOT_DIR/security/hardening.sh"

log_success "ALL-IN-ONE profile installed."
