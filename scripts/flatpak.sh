#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
APP_FILE="$ROOT_DIR/scripts/flatpak-apps.txt"

usage() {
  cat <<'EOF'
SevenOS Flatpak bridge

Usage:
  ./scripts/flatpak.sh [status|setup|install|install-defaults|list]

Actions:
  status            Show Flatpak and Flathub state
  setup             Install Flatpak and add Flathub
  install            Install SevenOS default Flatpak apps
  install-defaults   Install SevenOS default Flatpak apps
  list              Print default Flatpak app IDs
EOF
}

flatpak_apps() {
  while IFS= read -r app; do
    app="${app%%#*}"
    app="${app//[[:space:]]/}"
    [[ -n "$app" ]] && printf '%s\n' "$app"
  done < "$APP_FILE"
}

flathub_present() {
  command -v flatpak >/dev/null 2>&1 &&
    flatpak remotes --columns=name 2>/dev/null | grep -qx 'flathub'
}

status() {
  printf 'SevenOS Flatpak Status\n'
  printf '======================\n'
  printf 'flatpak: %s\n' "$(command -v flatpak >/dev/null 2>&1 && printf OK || printf MISS)"
  printf 'flathub: %s\n' "$(flathub_present && printf OK || printf MISS)"
  printf '\nDefault candidates:\n'
  flatpak_apps | sed 's/^/  - /'
}

setup() {
  if is_dry_run; then
    printf 'sudo pacman -S --needed flatpak\n'
    printf 'flatpak remote-add --if-not-exists flathub %q\n' "$FLATHUB_URL"
    return 0
  fi

  require_arch
  require_command sudo
  install_packages flatpak
  flatpak remote-add --if-not-exists flathub "$FLATHUB_URL"
}

install_defaults() {
  setup

  if is_dry_run; then
    flatpak_apps | while IFS= read -r app; do
      printf 'flatpak install -y flathub %q\n' "$app"
    done
    return 0
  fi

  flatpak_apps | while IFS= read -r app; do
    flatpak install -y flathub "$app"
  done
}

action="${1:-status}"
case "$action" in
  status) status ;;
  setup) setup ;;
  install|install-defaults) install_defaults ;;
  list) flatpak_apps ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown Flatpak action: $action"; usage; exit 1 ;;
esac
