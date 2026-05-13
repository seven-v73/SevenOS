#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

PROFILE_SOURCE="$ROOT_DIR/archiso/profile"
BUILD_ROOT="$ROOT_DIR/out/archiso"
PROFILE_BUILD="$BUILD_ROOT/profile"
WORK_DIR="$BUILD_ROOT/work"
OUT_DIR="$ROOT_DIR/out/iso"

usage() {
  cat <<'EOF'
SevenOS ISO builder

Usage:
  ./scripts/build-iso.sh [--dry-run]

Options:
  --dry-run    Show actions without creating build directories or running mkarchiso
  -h, --help   Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

require_arch
require_command rsync

if ! is_dry_run; then
  if ! command -v mkarchiso >/dev/null 2>&1; then
    log_error "mkarchiso is missing. Install ISO tooling first with: ./install.sh iso-tools"
    exit 1
  fi
  require_command sudo
fi

if [[ ! -d "$PROFILE_SOURCE" ]]; then
  log_error "Archiso profile not found: $PROFILE_SOURCE"
  exit 1
fi

log_info "Preparing SevenOS archiso profile..."
run_cmd rm -rf "$PROFILE_BUILD"
run_cmd mkdir -p "$PROFILE_BUILD" "$WORK_DIR" "$OUT_DIR"
run_cmd rsync -a --delete "$PROFILE_SOURCE"/ "$PROFILE_BUILD"/

log_info "Injecting SevenOS repository into live ISO profile..."
run_cmd mkdir -p "$PROFILE_BUILD/airootfs/opt"
run_cmd rsync -a \
  --exclude '.git' \
  --exclude 'out' \
  "$ROOT_DIR"/ "$PROFILE_BUILD/airootfs/opt/SevenOS"/

log_info "Building ISO with mkarchiso..."
run_cmd sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_BUILD"

log_success "ISO build complete. Output directory: $OUT_DIR"
