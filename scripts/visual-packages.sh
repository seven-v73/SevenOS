#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

PACMAN_PACKAGES=(
  adw-gtk-theme
  gnome-themes-extra
  kvantum
  kvantum-qt5
  nwg-look
  papirus-icon-theme
  sassc
  qt5ct
  qt6ct
)

AUR_PACKAGES=(
  catppuccin-gtk-theme-mocha
  catppuccin-gtk-theme-latte
  catppuccin-cursors-mocha
  catppuccin-cursors-latte
  kvantum-theme-catppuccin-git
  papirus-folders-catppuccin-git
  colloid-catppuccin-theme-git
)

usage() {
  cat <<'EOF'
SevenOS Visual Packages
=======================

Usage:
  seven identity visuals
  seven identity visuals install
  seven identity visuals install --yes
  ./scripts/visual-packages.sh [status|install] [--yes]

Installs and verifies the optional visual layer that makes SevenOS feel more
polished: Catppuccin GTK, cursors, Kvantum, Papirus folders and Qt support.
EOF
}

is_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

status() {
  local missing=0 package
  printf 'SevenOS Visual Package Layer\n'
  printf '============================\n\n'
  printf 'Official packages:\n'
  for package in "${PACMAN_PACKAGES[@]}"; do
    if is_installed "$package"; then
      printf '  [OK]   %s\n' "$package"
    else
      printf '  [MISS] %s\n' "$package"
      missing=$((missing + 1))
    fi
  done
  printf '\nAUR packages:\n'
  for package in "${AUR_PACKAGES[@]}"; do
    if is_installed "$package"; then
      printf '  [OK]   %s\n' "$package"
    else
      printf '  [MISS] %s\n' "$package"
      missing=$((missing + 1))
    fi
  done
  printf '\n'
  if [[ "$missing" -eq 0 ]]; then
    log_success "SevenOS visual package layer is complete."
  else
    log_warn "$missing visual package(s) missing."
    log_info "Run: sudo -v && seven identity visuals install --yes"
  fi
}

install_packages() {
  local yes=0
  if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
    yes=1
  fi

  if is_dry_run; then
    printf 'sudo pacman -S --needed %s %s\n' "$([[ "$yes" -eq 1 ]] && printf -- '--noconfirm')" "${PACMAN_PACKAGES[*]}"
    printf 'yay --needed %s -S %s\n' "$([[ "$yes" -eq 1 ]] && printf -- '--noconfirm')" "${AUR_PACKAGES[*]}"
    printf './install.sh theme\n'
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    log_error "sudo is required to install visual packages."
    exit 1
  fi
  if ! command -v yay >/dev/null 2>&1; then
    log_error "yay is required for Catppuccin AUR visual packages."
    log_info "Install yay first, then rerun: seven identity visuals install --yes"
    exit 1
  fi

  sudo -v
  if [[ "$yes" -eq 1 ]]; then
    sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
    yay --needed --noconfirm -S "${AUR_PACKAGES[@]}"
  else
    sudo pacman -S --needed "${PACMAN_PACKAGES[@]}"
    yay --needed -S "${AUR_PACKAGES[@]}"
  fi

  "$ROOT_DIR/install.sh" theme
  if [[ -x "$ROOT_DIR/bin/seven-waybar" ]]; then
    "$ROOT_DIR/bin/seven-waybar" restart || true
  fi
  status
}

ACTION="${1:-status}"
case "$ACTION" in
  status) status ;;
  install) install_packages "${2:-}" ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown visual package action: $ACTION"; usage; exit 1 ;;
esac
