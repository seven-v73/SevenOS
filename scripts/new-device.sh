#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
source "$ROOT_DIR/scripts/lib.sh"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
LOG_FILE="$LOG_DIR/new-device.log"

usage() {
  cat <<'EOF'
SevenOS New Device Setup
========================

Usage:
  seven new
  ./scripts/new-device.sh [--yes] [--optional] [--rootfs]
  ./install.sh new --yes
  ./install.sh new-device --yes
  seven setup new-device --yes

Installs and applies the ergonomic defaults for a fresh SevenOS machine:
base desktop, CLI, fonts, visual layer, mini OS requirements, workspaces,
profile isolation, rootfs metadata, boot splash, theme, post-install checks.
EOF
}

OPTIONAL=0
ROOTFS=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --yes|-y) export SEVENOS_YES=1 ;;
    --optional) OPTIONAL=1 ;;
    --rootfs) ROOTFS=1 ;;
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown new-device option: $1"; usage; exit 1 ;;
  esac
  shift
done

step() {
  log_info "New device: $*"
}

run_optional() {
  "$@" || log_warn "Optional step failed: $*"
}

run_logged() {
  mkdir -p "$LOG_DIR"
  if is_dry_run; then
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  printf '[%s] %s\n' "$(date -Is)" "$*" >>"$LOG_FILE"
  "$@" >>"$LOG_FILE" 2>&1
}

open_first_run_surface() {
  if [[ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    return 0
  fi
  if is_dry_run; then
    printf 'open SevenOS welcome/hub surface when a graphical session is available\n'
    return 0
  fi
  if command -v seven-welcome >/dev/null 2>&1; then
    nohup seven-welcome >/dev/null 2>&1 &
  elif command -v seven-hub-native >/dev/null 2>&1; then
    nohup seven-hub-native >/dev/null 2>&1 &
  elif [[ -x "$ROOT_DIR/bin/seven-welcome" ]]; then
    nohup "$ROOT_DIR/bin/seven-welcome" >/dev/null 2>&1 &
  fi
}

yes_args=()
if [[ "${SEVENOS_YES:-0}" == "1" ]]; then
  yes_args=(--yes)
fi

step "installing base desktop, CLI, hub, AUR helpers and theme"
"$ROOT_DIR/bootstrap.sh"

step "applying font roles and refreshing font cache"
"$ROOT_DIR/scripts/fonts.sh" apply-default

step "installing visual polish packages when available"
run_optional "$ROOT_DIR/scripts/visual-packages.sh" install "${yes_args[@]}"

step "installing required mini OS dependencies"
run_logged "$ROOT_DIR/bin/seven-profile-requirements" ensure all --apply "${yes_args[@]}"

step "preparing Windows Bridge first-install path"
run_optional run_logged "$ROOT_DIR/bin/seven-windows-assistant" setup --yes --no-open

if [[ "$OPTIONAL" -eq 1 ]]; then
  step "installing optional mini OS dependencies"
  run_optional run_logged "$ROOT_DIR/bin/seven-profile-requirements" ensure all --optional --aur --apply "${yes_args[@]}"
fi

step "bootstrapping all mini OS workspaces and launchers"
"$ROOT_DIR/profiles/profile-manager.sh" bootstrap all

step "activating Equinox as the first balanced runtime"
"$ROOT_DIR/profiles/profile-manager.sh" activate equinox

step "applying profile isolation and command views"
run_logged "$ROOT_DIR/scripts/profile-isolation.sh" apply equinox --yes

step "preparing rootfs metadata for all mini OS"
run_logged "$ROOT_DIR/bin/seven-profile-rootfs" prepare all --apply --yes

if [[ "$ROOTFS" -eq 1 ]]; then
  step "building rootfs for all mini OS; this can take time and disk space"
  run_logged "$ROOT_DIR/bin/seven-profile-rootfs" build all --apply --yes
  run_logged "$ROOT_DIR/bin/seven-profile-rootfs" seal all --apply --yes
fi

step "reapplying SevenOS theme and branding"
"$ROOT_DIR/branding/apply-branding.sh"
"$ROOT_DIR/scripts/apply-theme.sh"

step "applying quiet SevenOS boot and shutdown splash"
run_optional "$ROOT_DIR/scripts/boot-splash.sh" apply

step "running post-install ergonomics check"
"$ROOT_DIR/scripts/post-install.sh"

step "opening SevenOS first-run surface when possible"
open_first_run_surface

log_success "New device setup completed."
log_info "Detailed setup log: $LOG_FILE"
