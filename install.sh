#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS installer

Usage:
  ./install.sh <target> [--dry-run]

Targets:
  base             Install base SevenOS desktop layer
  dev              Install development profile
  cybersecurity    Install cybersecurity profile
  creation         Install creation profile
  windows          Install Windows compatibility layer
  all              Install base layer and all profiles

Options:
  --dry-run         Show actions without installing packages or copying configs
  -h, --help        Show this help
EOF
}

TARGET="${1:-}"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
  esac
done

if [[ -z "$TARGET" || "$TARGET" == "--dry-run" ]]; then
  usage
  exit 1
fi

require_arch
require_command sudo
require_command pacman

export SEVENOS_ROOT="$ROOT_DIR"
export SEVENOS_DRY_RUN="$DRY_RUN"

case "$TARGET" in
  base)
    "$ROOT_DIR/bootstrap.sh"
    ;;
  dev)
    "$ROOT_DIR/profiles/dev.sh"
    ;;
  cybersecurity)
    "$ROOT_DIR/profiles/cybersecurity.sh"
    ;;
  creation)
    "$ROOT_DIR/profiles/creation.sh"
    ;;
  windows)
    install_package_file "$ROOT_DIR/scripts/packages-windows.txt"
    ;;
  all)
    "$ROOT_DIR/profiles/all.sh"
    ;;
  *)
    log_error "Unknown target: $TARGET"
    usage
    exit 1
    ;;
esac

log_success "SevenOS target '$TARGET' completed."
