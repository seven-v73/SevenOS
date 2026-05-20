#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

VERSION="${SEVENOS_GLAZE_VERSION:-7.6.0}"
PREFIX="${SEVENOS_GLAZE_PREFIX:-$HOME/.local/lib/sevenos/glaze}"
BUILD_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos/build/glaze"
SOURCE_DIR="$BUILD_ROOT/glaze-$VERSION"
TARBALL="$BUILD_ROOT/v$VERSION.tar.gz"
URL="https://github.com/stephenberry/glaze/archive/refs/tags/v$VERSION.tar.gz"

usage() {
  cat <<'EOF'
SevenOS local glaze installer

Usage:
  ./scripts/install-glaze-local.sh install
  ./scripts/install-glaze-local.sh status

Installs the header-only glaze C++ library into:
  ~/.local/lib/sevenos/glaze

This gives SevenOS a stable non-root path for Hypr ecosystem builds when
pacman cannot install the system glaze package without an interactive sudo.
EOF
}

header_path() {
  printf '%s/include/glaze/glaze.hpp' "$PREFIX"
}

pkgconfig_path() {
  printf '%s/lib/pkgconfig/glaze.pc' "$PREFIX"
}

is_ready() {
  [[ -f "$(header_path)" && -f "$(pkgconfig_path)" ]]
}

status() {
  printf 'SevenOS glaze local dependency\n'
  printf '===============================\n\n'
  if pacman -Q glaze >/dev/null 2>&1; then
    printf '  system:  OK   %s\n' "$(pacman -Q glaze)"
  else
    printf '  system:  MISS glaze is not installed through pacman\n'
  fi

  if is_ready; then
    printf '  local:   OK   %s\n' "$PREFIX"
    printf '  header:  OK   %s\n' "$(header_path)"
    printf '  pc file: OK   %s\n' "$(pkgconfig_path)"
  else
    printf '  local:   MISS %s\n' "$PREFIX"
  fi
}

prepare_source() {
  mkdir -p "$BUILD_ROOT"
  if [[ -d "$SOURCE_DIR" ]]; then
    return 0
  fi

  if is_dry_run; then
    printf 'curl -L %q -o %q\n' "$URL" "$TARBALL"
    printf 'tar -xf %q -C %q\n' "$TARBALL" "$BUILD_ROOT"
    return 0
  fi

  require_command curl
  curl -L "$URL" -o "$TARBALL"
  tar -xf "$TARBALL" -C "$BUILD_ROOT"
}

write_pkgconfig() {
  local pc_dir="$PREFIX/lib/pkgconfig"
  mkdir -p "$pc_dir"
  cat >"$pc_dir/glaze.pc" <<EOF
prefix=$PREFIX
includedir=\${prefix}/include

Name: glaze
Description: Header-only C++ JSON and interface library
Version: $VERSION
Cflags: -I\${includedir}
EOF
}

install_local() {
  if is_ready; then
    log_success "Local glaze dependency already installed in $PREFIX"
    return 0
  fi

  if is_dry_run; then
    prepare_source
    printf 'mkdir -p %q\n' "$PREFIX/include"
    printf 'cp -a %q %q\n' "$SOURCE_DIR/include/glaze" "$PREFIX/include/"
    printf 'write %q\n' "$(pkgconfig_path)"
    return 0
  fi

  prepare_source
  if [[ ! -d "$SOURCE_DIR/include/glaze" ]]; then
    log_error "Downloaded glaze source does not contain include/glaze"
    exit 1
  fi

  rm -rf "$PREFIX/include/glaze"
  mkdir -p "$PREFIX/include"
  cp -a "$SOURCE_DIR/include/glaze" "$PREFIX/include/"
  write_pkgconfig
  log_success "Local glaze dependency installed in $PREFIX"
}

case "${1:-install}" in
  install) install_local ;;
  status|doctor) status ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown action: $1"; usage; exit 1 ;;
esac
