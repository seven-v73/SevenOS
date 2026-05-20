#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

VERSION="0.2.0"
PREFIX="$HOME/.local/lib/sevenos/hyprsysteminfo-upstream"
GLAZE_PREFIX="${SEVENOS_GLAZE_PREFIX:-$HOME/.local/lib/sevenos/glaze}"
BUILD_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos/build/hyprsysteminfo"
SOURCE_DIR="$BUILD_ROOT/hyprsysteminfo-$VERSION"
TARBALL="$BUILD_ROOT/v$VERSION.tar.gz"
URL="https://github.com/hyprwm/hyprsysteminfo/archive/refs/tags/v$VERSION.tar.gz"

usage() {
  cat <<'EOF'
SevenOS hyprsysteminfo upstream installer

Usage:
  ./scripts/install-hyprsysteminfo.sh

Builds the upstream Hyprland hyprsysteminfo app into:
  ~/.local/lib/sevenos/hyprsysteminfo-upstream

This avoids an interactive sudo prompt while still giving SevenOS the real
upstream dashboard whenever system dependencies are already present.
EOF
}

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

doctor() {
  local glaze_state="MISS"
  if pacman -Q glaze >/dev/null 2>&1; then
    glaze_state="OK(system)"
  elif [[ -f "$GLAZE_PREFIX/include/glaze/glaze.hpp" ]]; then
    glaze_state="OK(local)"
  fi
  printf 'SevenOS hyprsysteminfo upstream build requirements\n'
  printf '  cmake:       %s\n' "$(command_state cmake)"
  printf '  c++:         %s\n' "$(command_state c++)"
  printf '  pkg-config:  %s\n' "$(command_state pkg-config)"
  printf '  curl:        %s\n' "$(command_state curl)"
  printf '  hyprtoolkit: %s\n' "$(pkg-config --exists hyprtoolkit && printf OK || printf MISS)"
  printf '  hyprutils:   %s\n' "$(pkg-config --exists 'hyprutils >= 0.10.2' && printf OK || printf MISS)"
  printf '  libdrm:      %s\n' "$(pkg-config --exists libdrm && printf OK || printf MISS)"
  printf '  libpci:      %s\n' "$(pkg-config --exists libpci && printf OK || printf MISS)"
  printf '  pixman-1:    %s\n' "$(pkg-config --exists pixman-1 && printf OK || printf MISS)"
  printf '  glaze:       %s\n' "$glaze_state"
}

prepare_source() {
  mkdir -p "$BUILD_ROOT"
  if [[ -d "$SOURCE_DIR" ]]; then
    return 0
  fi
  if [[ -f "$HOME/.cache/yay/hyprsysteminfo/v$VERSION.tar.gz" ]]; then
    cp "$HOME/.cache/yay/hyprsysteminfo/v$VERSION.tar.gz" "$TARBALL"
  elif [[ -f "$HOME/.cache/yay/hyprsysteminfo/hyprsysteminfo-$VERSION.tar.gz" ]]; then
    cp "$HOME/.cache/yay/hyprsysteminfo/hyprsysteminfo-$VERSION.tar.gz" "$TARBALL"
  else
    require_command curl
    curl -L "$URL" -o "$TARBALL"
  fi
  tar -xf "$TARBALL" -C "$BUILD_ROOT"
}

build_upstream() {
  require_command cmake
  require_command c++
  require_command pkg-config

  if ! pacman -Q glaze >/dev/null 2>&1 &&
     [[ ! -f "$GLAZE_PREFIX/include/glaze/glaze.hpp" ]] &&
     [[ -x "$ROOT_DIR/scripts/install-glaze-local.sh" ]]; then
    log_info "Installing local glaze dependency for non-root Hypr builds..."
    "$ROOT_DIR/scripts/install-glaze-local.sh" install
  fi

  for module in hyprtoolkit 'hyprutils >= 0.10.2' libdrm libpci pixman-1; do
    if ! pkg-config --exists "$module"; then
      log_error "Missing build dependency: $module"
      log_info "Run: sudo pacman -S --needed hyprtoolkit hyprutils libdrm pciutils pixman"
      exit 1
    fi
  done

  prepare_source
  local build_dir="$SOURCE_DIR/build"
  local initial_cxx_flags=""
  if [[ -d "$GLAZE_PREFIX/include" ]]; then
    initial_cxx_flags="-I$GLAZE_PREFIX/include"
  elif [[ -d "$PREFIX/include" ]]; then
    initial_cxx_flags="-I$PREFIX/include"
  fi
  cmake --no-warn-unused-cli \
    ${initial_cxx_flags:+-DCMAKE_CXX_FLAGS=$initial_cxx_flags} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -S "$SOURCE_DIR" \
    -B "$build_dir"

  local glaze_include="$build_dir/_deps/glaze-src/include"
  if [[ -d "$glaze_include" ]]; then
    cmake \
      -DCMAKE_CXX_FLAGS="-I$glaze_include" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -S "$SOURCE_DIR" \
      -B "$build_dir"
  fi

  cmake --build "$build_dir" -j"$(nproc)"
  cmake --install "$build_dir"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$ROOT_DIR/bin/hyprsysteminfo" "$HOME/.local/bin/hyprsysteminfo"
  log_success "Upstream hyprsysteminfo installed in $PREFIX"
}

case "${1:-install}" in
  install) build_upstream ;;
  doctor|status) doctor ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown action: $1"; usage; exit 1 ;;
esac
