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
  ./scripts/flatpak.sh [status|setup|install|install-defaults|list] [--json]

Actions:
  status            Show Flatpak and Flathub state
  setup             Install Flatpak and add Flathub
  install            Install SevenOS default Flatpak apps
  install-defaults   Install SevenOS default Flatpak apps
  list              Print default Flatpak app IDs
  --json            Emit machine-readable status for Seven Hub and Seven Core
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

app_status_tsv() {
  flatpak_apps | while IFS= read -r app; do
    local state="MISS"
    if command -v flatpak >/dev/null 2>&1 && flatpak info "$app" >/dev/null 2>&1; then
      state="OK"
    fi
    printf '%s\t%s\n' "$app" "$state"
  done
}

status_json() {
  local flatpak_state="MISS"
  local flathub_state="MISS"
  command -v flatpak >/dev/null 2>&1 && flatpak_state="OK"
  flathub_present && flathub_state="OK"

  FLATPAK_STATE="$flatpak_state" \
  FLATHUB_STATE="$flathub_state" \
  APP_STATUS="$(app_status_tsv)" \
  python - <<'PY'
import json
import os

apps = []
installed = 0
for raw in os.environ.get("APP_STATUS", "").splitlines():
    if not raw.strip():
        continue
    app_id, state = raw.split("\t", 1)
    if state == "OK":
        installed += 1
    apps.append({"id": app_id, "state": state})

total = len(apps)
print(json.dumps({
    "schema": "sevenos.flatpak.v1",
    "flatpak": os.environ.get("FLATPAK_STATE", "MISS"),
    "flathub": os.environ.get("FLATHUB_STATE", "MISS"),
    "total": total,
    "installed": installed,
    "missing": max(total - installed, 0),
    "ready": os.environ.get("FLATPAK_STATE") == "OK" and os.environ.get("FLATHUB_STATE") == "OK",
    "apps": apps,
}, indent=2))
PY
}

setup() {
  if is_dry_run; then
    if assume_yes; then
      printf 'sudo pacman -S --needed --noconfirm flatpak\n'
    else
      printf 'sudo pacman -S --needed flatpak\n'
    fi
    printf 'flatpak remote-add --if-not-exists flathub %q\n' "$FLATHUB_URL"
    return 0
  fi

  require_arch
  require_command sudo
  if ! command -v flatpak >/dev/null 2>&1; then
    log_info "Installing Flatpak package manager"
    if assume_yes; then
      sudo pacman -S --needed --noconfirm flatpak
    else
      sudo pacman -S --needed flatpak
    fi
  fi
  require_command flatpak
  flatpak remote-add --if-not-exists flathub "$FLATHUB_URL"
}

install_defaults() {
  setup

  if is_dry_run; then
    flatpak_apps | while IFS= read -r app; do
      printf 'flatpak install --noninteractive --or-update -y flathub %q\n' "$app"
    done
    return 0
  fi

  flatpak_apps | while IFS= read -r app; do
    if flatpak info "$app" >/dev/null 2>&1; then
      log_success "Flatpak app already installed: $app"
      continue
    fi
    log_info "Installing Flatpak app: $app"
    flatpak install --noninteractive --or-update -y flathub "$app"
  done
}

json_output=0
args=()
for arg in "$@"; do
  case "$arg" in
    --json|json) json_output=1 ;;
    *) args+=("$arg") ;;
  esac
done

action="${args[0]:-status}"
case "$action" in
  status) [[ "$json_output" -eq 1 ]] && status_json || status ;;
  setup) setup ;;
  install|install-defaults) install_defaults ;;
  list) flatpak_apps ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown Flatpak action: $action"; usage; exit 1 ;;
esac
