#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STRAP_URL="https://blackarch.org/strap.sh"
STRAP_SHA1="${BLACKARCH_STRAP_SHA1:-00688950aaf5e5804d2abebb8d3d3ea1d28525ed}"
STRAP_PATH="${TMPDIR:-/tmp}/sevenos-blackarch-strap.sh"

usage() {
  cat <<'EOF'
SevenOS BlackArch bridge

Usage:
  ./install.sh blackarch-setup [--yes] [--dry-run]
  ./install.sh blackarch-category <category> [--dry-run]
  ./install.sh blackarch-tool <package> [--dry-run]

Examples:
  ./install.sh blackarch-setup --dry-run
  ./install.sh blackarch-setup --yes
  ./install.sh blackarch-category webapp
  ./install.sh blackarch-tool feroxbuster

Notes:
  BlackArch is optional. SevenOS installs a strong official Arch cyber base
  before this bridge is needed.
EOF
}

repo_enabled() {
  pacman-conf --repo-list 2>/dev/null | grep -qx 'blackarch'
}

require_blackarch_repo() {
  if ! repo_enabled; then
    log_error "BlackArch repository is not enabled yet."
    log_info "Run './install.sh blackarch-setup --yes' first, after reviewing the dry-run."
    exit 1
  fi
}

setup_repo() {
  local assume_yes=0

  for arg in "$@"; do
    case "$arg" in
      --yes) assume_yes=1 ;;
      --dry-run) ;;
      -h|--help) usage; exit 0 ;;
      *) log_error "Unknown blackarch-setup option: $arg"; usage; exit 1 ;;
    esac
  done

  log_warn "This adds the external BlackArch package repository to pacman."
  log_warn "Review this step before using it on a production workstation."

  if is_dry_run; then
    log_info "Would download: $STRAP_URL"
    log_info "Would verify SHA1: $STRAP_SHA1"
    log_info "Would run: sudo bash $STRAP_PATH"
    log_info "Would refresh pacman databases."
    return 0
  fi

  if [[ "$assume_yes" -ne 1 ]]; then
    log_error "Refusing to add BlackArch without --yes."
    log_info "Preview first: ./install.sh blackarch-setup --dry-run"
    exit 1
  fi

  require_command curl
  require_command sha1sum

  run_cmd curl -fsSL "$STRAP_URL" -o "$STRAP_PATH"
  printf '%s  %s\n' "$STRAP_SHA1" "$STRAP_PATH" | sha1sum -c -
  run_cmd chmod +x "$STRAP_PATH"
  run_cmd sudo bash "$STRAP_PATH"
  run_cmd sudo pacman -Syy
}

install_category() {
  local category="${1:-}"
  [[ -n "$category" ]] || { log_error "Missing BlackArch category."; usage; exit 1; }
  [[ "$category" =~ ^[a-z0-9._+-]+$ ]] || { log_error "Invalid category: $category"; exit 1; }

  if is_dry_run; then
    log_info "Would install BlackArch category: blackarch-$category"
    return 0
  fi

  require_blackarch_repo
  run_cmd sudo pacman -S --needed "blackarch-$category"
}

install_tool() {
  local package="${1:-}"
  [[ -n "$package" ]] || { log_error "Missing BlackArch package."; usage; exit 1; }
  [[ "$package" =~ ^[a-z0-9._+-]+$ ]] || { log_error "Invalid package: $package"; exit 1; }

  if is_dry_run; then
    log_info "Would install BlackArch package: $package"
    return 0
  fi

  require_blackarch_repo
  run_cmd sudo pacman -S --needed "$package"
}

command_name="${1:-setup}"
shift || true

case "$command_name" in
  setup)
    setup_repo "$@"
    ;;
  category)
    install_category "$@"
    ;;
  tool)
    install_tool "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "Unknown BlackArch command: $command_name"
    usage
    exit 1
    ;;
esac
