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
  seven setup doctor
  ./scripts/new-device.sh [--yes] [--optional] [--rootfs]
  ./scripts/new-device.sh doctor
  ./install.sh new --yes
  ./install.sh new-device --yes
  seven setup new-device --yes

Installs and applies the ergonomic defaults for a fresh SevenOS machine:
base desktop, CLI, fonts, French/English language packs, visual identity, mini OS requirements, workspaces,
profile isolation, rootfs metadata, boot splash, login theme, post-install checks.
EOF
}

OPTIONAL=0
ROOTFS=0
ACTION="apply"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    doctor|check|status) ACTION="doctor" ;;
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
    "$@"
    return $?
  fi
  printf '[%s] %s\n' "$(date -Is)" "$*" >>"$LOG_FILE"
  "$@" >>"$LOG_FILE" 2>&1
}

run_required_logged() {
  mkdir -p "$LOG_DIR"
  if is_dry_run; then
    "$@"
    return $?
  fi
  printf '[%s] %s\n' "$(date -Is)" "$*" >>"$LOG_FILE"
  if "$@" 2>&1 | tee -a "$LOG_FILE"; then
    return 0
  fi
  log_error "Required setup step failed: $*"
  log_info "Install log: $LOG_FILE"
  log_info "Last log lines:"
  tail -n 24 "$LOG_FILE" >&2 || true
  return 1
}

doctor_ok() {
  printf '[OK] %s\n' "$*"
}

doctor_warn() {
  printf '[WARN] %s\n' "$*"
}

doctor_fail() {
  printf '[FAIL] %s\n' "$*" >&2
}

check_file() {
  local label="$1"
  local path="$2"
  if [[ -s "$path" ]]; then
    doctor_ok "$label"
    return 0
  fi
  doctor_fail "$label missing: ${path#$ROOT_DIR/}"
  return 1
}

setup_doctor() {
  local failed=0
  local package_file script_file
  local package_files=(
    scripts/packages-base.txt
    scripts/packages-identity.txt
    scripts/packages-network.txt
    scripts/packages-visual-aur.txt
    scripts/packages-dev.txt
    scripts/packages-cybersecurity.txt
    scripts/packages-creation.txt
    scripts/packages-atlas.txt
    scripts/packages-performance.txt
    scripts/packages-culture.txt
    scripts/packages-runtime-optional.txt
    scripts/packages-windows-compat.txt
  )
  local script_files=(
    bootstrap.sh
    scripts/network.sh
    scripts/fonts.sh
    bin/seven-language
    bin/seven-waybar-language
    scripts/apply-theme.sh
    scripts/boot-splash.sh
    scripts/login-theme.sh
    scripts/identity-assets.sh
    scripts/post-install.sh
    scripts/system-profile.sh
    scripts/system-install.sh
    scripts/public-experience.sh
    scripts/shell-ags-runtime.sh
    profiles/profile-manager.sh
    bin/seven-profile-requirements
    bin/seven-profile-rootfs
    bin/seven-profile-theme
  )

  printf 'SevenOS New Device Doctor\n'
  printf '=========================\n'

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    doctor_fail "installer must run as a normal user, not root"
    failed=1
  else
    doctor_ok "normal user context: $USER"
  fi

  for package_file in "${package_files[@]}"; do
    check_file "package file ${package_file}" "$ROOT_DIR/$package_file" || failed=1
  done

  for script_file in "${script_files[@]}"; do
    check_file "setup component ${script_file}" "$ROOT_DIR/$script_file" || failed=1
  done

  if "$ROOT_DIR/scripts/network.sh" status --json >/dev/null 2>&1; then
    doctor_ok "network status contract"
  else
    doctor_warn "network status is incomplete; run ./install.sh network --yes after connecting"
  fi

  if "$ROOT_DIR/bin/seven-profile-requirements" status all --json >/dev/null 2>&1; then
    doctor_ok "mini OS requirements contract"
  else
    doctor_fail "mini OS requirements contract failed"
    failed=1
  fi

  if "$ROOT_DIR/scripts/public-experience.sh" json >/dev/null 2>&1; then
    doctor_ok "public quality contract"
  else
    doctor_warn "public quality contract reports remaining release/runtime actions"
  fi

  if "$ROOT_DIR/scripts/fonts.sh" status >/dev/null 2>&1; then
    doctor_ok "font status contract"
  else
    doctor_warn "font status is incomplete; new-device will run scripts/fonts.sh apply-default"
  fi

  if "$ROOT_DIR/bin/seven-language" doctor --json >/dev/null 2>&1; then
    doctor_ok "French/English language contract"
  else
    doctor_warn "language packs are incomplete; new-device will run ./install.sh language"
  fi

  if "$ROOT_DIR/scripts/boot-splash.sh" doctor >/dev/null 2>&1; then
    doctor_ok "boot splash contract"
  else
    doctor_fail "boot splash contract failed"
    failed=1
  fi

  if "$ROOT_DIR/scripts/login-theme.sh" doctor >/dev/null 2>&1; then
    doctor_ok "login theme contract"
  else
    doctor_fail "login theme contract failed"
    failed=1
  fi

  if SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/login-theme.sh" apply --yes >/dev/null 2>&1; then
    doctor_ok "login theme dry-run apply"
  else
    doctor_fail "login theme dry-run apply failed"
    failed=1
  fi

  if "$ROOT_DIR/scripts/identity-assets.sh" doctor >/dev/null 2>&1; then
    doctor_ok "SevenOS identity assets contract"
  else
    doctor_fail "SevenOS identity assets contract failed"
    failed=1
  fi

  if SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/boot-splash.sh" apply --yes >/dev/null 2>&1; then
    doctor_ok "boot splash dry-run apply"
  else
    doctor_fail "boot splash dry-run apply failed"
    failed=1
  fi

  if [[ -s "$ROOT_DIR/hyprland/waybar/config.jsonc" && -s "$ROOT_DIR/hyprland/hyprlock.conf" ]]; then
    doctor_ok "desktop config templates"
  else
    doctor_fail "desktop config templates incomplete"
    failed=1
  fi

  if (( failed )); then
    return 1
  fi
  log_success "New device setup contract is ready"
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

if [[ "$ACTION" == "doctor" ]]; then
  setup_doctor
  exit $?
fi

step "installing base desktop, CLI, hub, AUR helpers and theme"
run_required_logged "$ROOT_DIR/bootstrap.sh"

step "installing SevenOS into /opt/SevenOS for public updates"
run_optional "$ROOT_DIR/scripts/system-install.sh" "${yes_args[@]}"

step "preparing NetworkManager and Wi-Fi before dependency installs"
run_optional "$ROOT_DIR/scripts/network.sh" bootstrap "${yes_args[@]}"

step "applying font roles and refreshing font cache"
"$ROOT_DIR/scripts/fonts.sh" apply-default

step "preparing French and English language packs"
"$ROOT_DIR/bin/seven-language" ensure en_US.UTF-8
"$ROOT_DIR/bin/seven-language" ensure fr_FR.UTF-8

step "installing visual polish packages when available"
run_optional "$ROOT_DIR/scripts/visual-packages.sh" install "${yes_args[@]}"

step "installing SevenOS identity packages for splash, login and graphical admin prompts"
run_optional install_package_file "$ROOT_DIR/scripts/packages-identity.txt"

step "installing required mini OS dependencies"
run_logged "$ROOT_DIR/bin/seven-profile-requirements" ensure all --apply "${yes_args[@]}"

step "preparing Atlas Explorer first-install path"
run_optional run_logged "$ROOT_DIR/bin/seven-profile-requirements" status atlas --json

if [[ "$OPTIONAL" -eq 1 ]]; then
  step "installing optional mini OS dependencies"
  run_optional run_logged "$ROOT_DIR/bin/seven-profile-requirements" ensure all --optional --aur --apply "${yes_args[@]}"

  step "installing global Windows app compatibility layer"
  run_optional "$ROOT_DIR/install.sh" windows-compat "${yes_args[@]}"

  step "installing Seven Shell AGS runtime"
  run_optional "$ROOT_DIR/scripts/shell-ags-runtime.sh" install
fi

step "bootstrapping all mini OS workspaces and launchers"
"$ROOT_DIR/profiles/profile-manager.sh" bootstrap all

step "activating Equinox as the first balanced runtime"
"$ROOT_DIR/profiles/profile-manager.sh" activate equinox

step "applying Equinox system profile and mini OS command views"
run_logged "$ROOT_DIR/scripts/system-profile.sh" apply --yes

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

step "applying SevenOS Prism login theme"
run_optional "$ROOT_DIR/scripts/login-theme.sh" apply

step "running post-install ergonomics check"
"$ROOT_DIR/scripts/post-install.sh"

step "running public quality gate"
run_optional "$ROOT_DIR/scripts/public-experience.sh" doctor

step "opening SevenOS first-run surface when possible"
open_first_run_surface

log_success "New device setup completed."
log_info "Detailed setup log: $LOG_FILE"
