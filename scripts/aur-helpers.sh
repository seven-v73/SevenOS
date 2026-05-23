#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-install}"
shift || true

AUR_BUILD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos/aur"
HELPERS=(yay paru)

helper_state() {
  command -v "$1" >/dev/null 2>&1 && printf 'OK' || printf 'MISS'
}

status_json() {
  python - "$(helper_state yay)" "$(helper_state paru)" "$AUR_BUILD_DIR" <<'PY'
import json
import sys

yay, paru, build_dir = sys.argv[1:]
payload = {
    "schema": "sevenos.aur-helpers.v1",
    "yay": yay,
    "paru": paru,
    "build_dir": build_dir,
    "ready": yay == "OK" and paru == "OK",
    "preferred": "paru" if paru == "OK" else "yay" if yay == "OK" else None,
}
print(json.dumps(payload, indent=2))
PY
}

status_human() {
  printf 'SevenOS AUR helpers\n\n'
  printf '  %-8s %s\n' yay "$(helper_state yay)"
  printf '  %-8s %s\n' paru "$(helper_state paru)"
  printf '\n'
  printf 'SevenOS uses paru first, then yay as fallback.\n'
}

install_helper() {
  local helper="$1"
  local repo="https://aur.archlinux.org/${helper}.git"
  local target="$AUR_BUILD_DIR/$helper"

  if [[ "$(helper_state "$helper")" == "OK" ]]; then
    log_success "$helper already installed."
    return 0
  fi

  log_info "Building AUR helper: $helper"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$AUR_BUILD_DIR"
    printf 'git clone %q %q\n' "$repo" "$target"
    printf '(cd %q && makepkg -si%s)\n' "$target" "$(assume_yes && printf ' --noconfirm' || true)"
    return 0
  fi

  require_command git
  require_command makepkg
  mkdir -p "$AUR_BUILD_DIR"

  if [[ -d "$target/.git" ]]; then
    run_cmd git -C "$target" pull --ff-only || log_warn "Could not update $helper; using existing checkout."
  else
    rm -rf "$target"
    run_cmd git clone "$repo" "$target"
  fi

  if assume_yes; then
    (cd "$target" && makepkg -s --noconfirm)
  else
    (cd "$target" && makepkg -s)
  fi

  local built_packages=()
  mapfile -t built_packages < <(find "$target" -maxdepth 1 -type f -name "${helper}-*.pkg.tar.*" ! -name '*-debug-*' | sort)
  if [[ "${#built_packages[@]}" -eq 0 ]]; then
    log_error "No built package found for $helper in $target"
    return 1
  fi

  if command -v pkexec >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    run_cmd pkexec pacman -U --needed --noconfirm "${built_packages[@]}" || {
      log_warn "pkexec could not install $helper. Install manually with:"
      printf '  sudo pacman -U --needed %q\n' "${built_packages[@]}"
      return 1
    }
  elif [[ -t 0 ]]; then
    run_cmd sudo pacman -U --needed --noconfirm "${built_packages[@]}"
  else
    log_warn "$helper was built, but admin authentication is required to install it."
    printf '  sudo pacman -U --needed'
    printf ' %q' "${built_packages[@]}"
    printf '\n'
    return 1
  fi
}

install_all() {
  install_package_file "$ROOT_DIR/scripts/packages-aur-bootstrap.txt"
  local failed=0
  for helper in "${HELPERS[@]}"; do
    install_helper "$helper" || failed=1
  done
  status_human
  return "$failed"
}

case "$ACTION" in
  status)
    if [[ "${1:-}" == "--json" ]]; then
      status_json
    else
      status_human
    fi
    ;;
  install)
    install_all
    ;;
  --json)
    status_json
    ;;
  -h|--help|help)
    status_human
    ;;
  *)
    log_error "Unknown AUR helper action: $ACTION"
    status_human >&2
    exit 1
    ;;
esac
