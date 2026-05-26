#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

TARGET_DIR="${SEVENOS_SYSTEM_ROOT:-/opt/SevenOS}"
YES=0

usage() {
  cat <<'EOF'
SevenOS system install

Usage:
  ./install.sh system-install [--dry-run] [--yes]
  seven system-install [--yes]

Installs the SevenOS repository into /opt/SevenOS and refreshes public command
wrappers so `seven update` works naturally from any directory.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
    --yes) YES=1; export SEVENOS_YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown system install option: $arg"; usage; exit 1 ;;
  esac
done

if [[ "$YES" -ne 1 && ! is_dry_run ]]; then
  log_error "System install needs explicit consent."
  log_info "Preview: ./install.sh system-install --dry-run"
  log_info "Apply:   ./install.sh system-install --yes"
  exit 1
fi

require_command rsync
require_command sudo

log_info "Installing SevenOS system repository into $TARGET_DIR"
run_cmd sudo mkdir -p "$TARGET_DIR"
run_cmd sudo rsync -a --delete \
  --exclude out \
  --exclude work \
  --exclude iso \
  --exclude dist \
  --exclude target \
  --exclude node_modules \
  --exclude archiso/localrepo \
  "$ROOT_DIR"/ "$TARGET_DIR"/

log_info "Refreshing public SevenOS command wrappers from $TARGET_DIR"
run_cmd env SEVENOS_ROOT="$TARGET_DIR" "$TARGET_DIR/install.sh" cli

log_success "SevenOS is installed in $TARGET_DIR."
log_info "Public update route: seven update check ; seven update install --yes"
