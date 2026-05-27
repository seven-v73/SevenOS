#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
source "$ROOT_DIR/scripts/lib.sh"

failures=0
warnings=0

TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout --kill-after=2s)
fi

fail_step() {
  log_error "$1"
  failures=$((failures + 1))
}

warn_step() {
  log_warn "$1"
  warnings=$((warnings + 1))
}

run_required() {
  local label="$1"
  shift
  log_info "Pre-push: $label"
  if "$@"; then
    log_success "$label"
  else
    fail_step "$label failed"
  fi
}

run_required_timeout() {
  local seconds="$1"
  local label="$2"
  shift 2
  if [[ "${#TIMEOUT_CMD[@]}" -gt 0 && -z "$(declare -F "$1" || true)" ]]; then
    run_required "$label" "${TIMEOUT_CMD[@]}" "$seconds" "$@"
  else
    run_required "$label" "$@"
  fi
}

run_optional_timeout() {
  local seconds="$1"
  local label="$2"
  shift 2
  log_info "Pre-push: $label"
  if [[ "${#TIMEOUT_CMD[@]}" -gt 0 && -z "$(declare -F "$1" || true)" ]]; then
    if "${TIMEOUT_CMD[@]}" "$seconds" "$@"; then
      log_success "$label"
    else
      warn_step "$label did not complete; run the full audit manually."
    fi
  elif "$@"; then
    log_success "$label"
  else
    warn_step "$label did not complete; run the full audit manually."
  fi
}

syntax_check() {
  bash -n \
    "$ROOT_DIR/install.sh" \
    "$ROOT_DIR/bootstrap.sh" \
    "$ROOT_DIR/scripts/new-device.sh" \
    "$ROOT_DIR/scripts/actions.sh" \
    "$ROOT_DIR/scripts/check.sh" \
    "$ROOT_DIR/scripts/ux-check.sh" \
    "$ROOT_DIR/scripts/design-check.sh" \
    "$ROOT_DIR/scripts/system-assets.sh" \
    "$ROOT_DIR/scripts/identity-assets.sh" \
    "$ROOT_DIR/scripts/distribution.sh" \
    "$ROOT_DIR/scripts/identity-experience.sh" \
    "$ROOT_DIR/scripts/lifecycle.sh" \
    "$ROOT_DIR/bin/seven-windows-assistant" \
    "$ROOT_DIR/bin/seven-help" \
    "$ROOT_DIR/bin/seven-help-native"
}

python_check() {
  PYTHONDONTWRITEBYTECODE=1 python -m py_compile \
    "$ROOT_DIR/bin/seven" \
    "$ROOT_DIR/bin/seven-profile-requirements" \
    "$ROOT_DIR/bin/seven-profile-rootfs" \
    "$ROOT_DIR/bin/seven-profile-run" \
    "$ROOT_DIR/bin/seven-waybar-context" \
    "$ROOT_DIR/bin/seven-help-native" \
    "$ROOT_DIR/bin/seven-identity-native" \
    "$ROOT_DIR/bin/seven_waybar_app_profiles.py" \
    "$ROOT_DIR/scripts/seven_ai_agent.py" \
    "$ROOT_DIR/scripts/seven_ai_provider.py" \
    "$ROOT_DIR/scripts/seven_theme.py"
}

json_check() {
  python -m json.tool "$ROOT_DIR/sevenos.dotinst" >/dev/null
  python -m json.tool "$ROOT_DIR/profiles/catalog.json" >/dev/null
  python -m json.tool "$ROOT_DIR/identity/profile-themes.json" >/dev/null
  python -m json.tool "$ROOT_DIR/identity/design-engine.json" >/dev/null
  python -m json.tool "$ROOT_DIR/identity/wallpaper/dynamic/manifest.json" >/dev/null
  "$ROOT_DIR/scripts/system-assets.sh" json | python -m json.tool >/dev/null
  "$ROOT_DIR/scripts/identity-assets.sh" json | python -m json.tool >/dev/null
  if command -v jq >/dev/null 2>&1; then
    jq empty "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null
    jq empty "$ROOT_DIR/hyprland-light/waybar/config.jsonc" >/dev/null
    jq empty "$ROOT_DIR/archiso/profile/airootfs/etc/skel/.config/fastfetch/config.jsonc" >/dev/null
  fi
}

smoke_check() {
  SEVENOS_DISTRIBUTION_FAST=1 \
  SEVENOS_HEALTH_FAST=1 \
  SEVENOS_UPDATE_FAST=1 \
  SEVENOS_DRY_RUN=0 \
    "$ROOT_DIR/bin/seven" smoke --json | python -m json.tool >/dev/null
}

surfaces_check() {
  "$ROOT_DIR/bin/seven" surfaces json | python -m json.tool >/dev/null
  "$ROOT_DIR/bin/seven" surfaces doctor >/dev/null
}

identity_experience_check() {
  "$ROOT_DIR/bin/seven" identity experience --json | python -m json.tool >/dev/null
  "$ROOT_DIR/bin/seven" identity experience >/dev/null
}

public_quality_check() {
  SEVENOS_DISTRIBUTION_FAST=1 \
  SEVENOS_HEALTH_FAST=1 \
  SEVENOS_UPDATE_FAST=1 \
    "$ROOT_DIR/bin/seven" quality doctor --json | python -m json.tool >/dev/null
}

state_check() {
  SEVENOS_DISTRIBUTION_FAST=1 \
  SEVENOS_HEALTH_FAST=1 \
  SEVENOS_UPDATE_FAST=1 \
  SEVENOS_LIFECYCLE_FAST=1 \
  SEVENOS_DRY_RUN=0 \
    "$ROOT_DIR/bin/seven" state --json | python -m json.tool >/dev/null
}

new_device_dry_run() {
  SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/new-device.sh" --yes >/dev/null
}

windows_dry_run() {
  SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-windows-assistant" setup --yes --no-open >/dev/null
}

run_required "shell syntax" syntax_check
run_required "Python entrypoints" python_check
run_required "JSON and JSONC contracts" json_check
run_required "git diff whitespace" git -C "$ROOT_DIR" diff --check
run_required "SevenOS design contract" "$ROOT_DIR/scripts/design-check.sh"
run_required_timeout "${SEVENOS_PRE_PUSH_IDENTITY_TIMEOUT:-45s}" "SevenOS identity experience contract" identity_experience_check
run_required_timeout "${SEVENOS_PRE_PUSH_SMOKE_TIMEOUT:-60s}" "SevenOS smoke contract" smoke_check
run_required_timeout "${SEVENOS_PRE_PUSH_SURFACES_TIMEOUT:-30s}" "SevenOS native surfaces contract" surfaces_check
run_required_timeout "${SEVENOS_PRE_PUSH_STATE_TIMEOUT:-90s}" "SevenOS state contract" state_check
run_required_timeout "${SEVENOS_PRE_PUSH_NEW_TIMEOUT:-120s}" "new machine dry-run" new_device_dry_run
run_required_timeout "${SEVENOS_PRE_PUSH_WINDOWS_TIMEOUT:-60s}" "Windows Bridge first-run dry-run" windows_dry_run
run_optional_timeout "${SEVENOS_PRE_PUSH_UX_TIMEOUT:-180s}" "deep UX smoke window" \
  env \
  SEVENOS_DRY_RUN=1 \
  SEVENOS_DISTRIBUTION_FAST=1 \
  SEVENOS_HEALTH_FAST=1 \
  SEVENOS_UPDATE_FAST=1 \
  SEVENOS_LIFECYCLE_FAST=1 \
  bash -c '"$1" >/dev/null' _ "$ROOT_DIR/scripts/ux-check.sh"
run_optional_timeout "${SEVENOS_PRE_PUSH_QUALITY_TIMEOUT:-180s}" "public quality aggregate" public_quality_check

if [[ "$failures" -gt 0 ]]; then
  log_error "Pre-push fast gate failed: $failures failure(s), $warnings warning(s)."
  exit 1
fi

if [[ "$warnings" -gt 0 ]]; then
  log_warn "Pre-push fast gate passed with $warnings warning(s). Run ./scripts/ux-check.sh for the deep audit before a release tag."
else
  log_success "Pre-push fast gate passed."
fi
