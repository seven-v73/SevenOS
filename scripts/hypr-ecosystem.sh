#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"
export PATH="$HOME/.cargo/bin:$PATH"

OFFICIAL_PACKAGES=(hyprpaper hyprpicker hyprsunset matugen hyprtoolkit glaze pciutils)
AUR_PACKAGES=(wallust hyprsysteminfo)

usage() {
  cat <<'EOF'
SevenOS Hypr ecosystem

Usage:
  ./scripts/hypr-ecosystem.sh status
  ./scripts/hypr-ecosystem.sh install [--yes]
  ./scripts/hypr-ecosystem.sh apply
  ./scripts/hypr-ecosystem.sh lua <status|profiles|plan|audit|generate|apply|doctor>

Installs and configures the premium Hyprland layer: hyprpaper, dynamic
wallpaper palette generation, hyprsunset, hyprpicker and system dashboard
support.
EOF
}

is_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

glaze_ready() {
  is_installed glaze ||
    [[ -f "$HOME/.local/lib/sevenos/glaze/include/glaze/glaze.hpp" ]]
}

command_label() {
  command -v "$1" >/dev/null 2>&1 && command -v "$1" || printf MISS
}

status() {
  local missing=0 package
  printf 'SevenOS Hypr Ecosystem\n'
  printf '======================\n\n'
  printf 'Official packages:\n'
  for package in "${OFFICIAL_PACKAGES[@]}"; do
    if [[ "$package" == "glaze" ]] && glaze_ready; then
      if is_installed glaze; then
        printf '  [OK]   %s\n' "$package"
      else
        printf '  [OK]   %s (SevenOS local)\n' "$package"
      fi
    elif is_installed "$package"; then
      printf '  [OK]   %s\n' "$package"
    else
      printf '  [MISS] %s\n' "$package"
      missing=$((missing + 1))
    fi
  done
  printf '\nAUR / optional tools:\n'
  for package in "${AUR_PACKAGES[@]}"; do
    if is_installed "$package" || command -v "$package" >/dev/null 2>&1; then
      printf '  [OK]   %s\n' "$package"
    else
      printf '  [MISS] %s\n' "$package"
      missing=$((missing + 1))
    fi
  done
  printf '\nRuntime commands:\n'
  for package in hyprpaper hyprpicker hyprsunset matugen wallust hyprsysteminfo; do
    printf '  %-15s %s\n' "$package" "$(command_label "$package")"
  done
  printf '\n'
  "$ROOT_DIR/scripts/wallpaper-theme.sh" status || true
  if [[ "$missing" -eq 0 ]]; then
    log_success "SevenOS Hypr ecosystem is complete."
  else
    log_warn "$missing Hypr ecosystem component(s) missing."
    log_info "Run: ./install.sh hypr-ecosystem --yes"
  fi
}

install_aur_packages() {
  local yes="$1"
  local missing=()
  local package
  for package in "${AUR_PACKAGES[@]}"; do
    if is_installed "$package" || command -v "$package" >/dev/null 2>&1; then
      continue
    fi
    missing+=("$package")
  done
  [[ "${#missing[@]}" -eq 0 ]] && return 0

  if is_dry_run; then
    printf 'yay --needed %s -S %s\n' "$([[ "$yes" -eq 1 ]] && printf -- '--noconfirm')" "${missing[*]}"
    return 0
  fi
  if command -v yay >/dev/null 2>&1; then
    if [[ "$yes" -eq 1 ]]; then
      yay --needed --noconfirm -S "${missing[@]}" || log_warn "Some optional AUR Hypr packages could not be installed."
    else
      yay --needed -S "${missing[@]}" || log_warn "Some optional AUR Hypr packages could not be installed."
    fi
  else
    log_warn "yay is missing; optional AUR tools skipped: ${missing[*]}"
  fi

  if ! command -v wallust >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
    log_info "Installing wallust through cargo fallback..."
    cargo install wallust || log_warn "wallust cargo installation failed."
  fi

  if ! [[ -x "$HOME/.local/lib/sevenos/hyprsysteminfo-upstream/bin/hyprsysteminfo" ]] &&
     [[ -x "$ROOT_DIR/scripts/install-hyprsysteminfo.sh" ]]; then
    log_info "Installing upstream hyprsysteminfo in user space..."
    "$ROOT_DIR/scripts/install-hyprsysteminfo.sh" install || log_warn "hyprsysteminfo user-space build failed; SevenOS fallback remains available."
  fi
}

install_all() {
  local yes=0
  if assume_yes || [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
    yes=1
  fi
  if ! is_installed glaze && [[ -x "$ROOT_DIR/scripts/install-glaze-local.sh" ]]; then
    log_info "Preparing local glaze dependency for non-interactive Hypr builds..."
    "$ROOT_DIR/scripts/install-glaze-local.sh" install
  fi
  install_package_file "$ROOT_DIR/scripts/packages-hypr-ecosystem.txt"
  install_aur_packages "$yes"
  apply
}

apply() {
  local active
  local systemd_user_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$systemd_user_dir"
    printf 'cp %q %q/\n' "$ROOT_DIR/systemd/user/sevenos-hyprsunset.service" "$systemd_user_dir"
    printf '%q apply current wallpaper palette\n' "$ROOT_DIR/scripts/wallpaper-theme.sh"
    printf 'systemctl --user enable sevenos-hyprsunset.service\n'
    printf 'hyprctl reload\n'
    return 0
  fi
  mkdir -p "$systemd_user_dir"
  cp "$ROOT_DIR/systemd/user/sevenos-hyprsunset.service" "$systemd_user_dir/"
  active="$("$ROOT_DIR/bin/seven-wallpaper" path 2>/dev/null || true)"
  if [[ -n "$active" && -f "$active" ]]; then
    "$ROOT_DIR/scripts/wallpaper-theme.sh" generate "$active" || true
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable sevenos-hyprsunset.service >/dev/null 2>&1 || true
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
      systemctl --user restart sevenos-hyprsunset.service >/dev/null 2>&1 || true
    fi
  fi
  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
}

case "${1:-status}" in
status) status ;;
install) install_all "${2:-}" ;;
apply) apply ;;
lua) shift; "$ROOT_DIR/scripts/hypr-lua.sh" "$@" ;;
-h|--help|help) usage ;;
*) log_error "Unknown Hypr ecosystem action: $1"; usage; exit 1 ;;
esac
