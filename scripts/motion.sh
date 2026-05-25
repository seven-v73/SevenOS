#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

host_home() {
  local home="${SEVENOS_HOST_HOME:-$HOME}"
  case "$home" in
    */.local/share/sevenos/profile-containers/*/home)
      printf '%s\n' "${home%%/.local/share/sevenos/profile-containers/*}"
      ;;
    *)
      printf '%s\n' "$home"
      ;;
  esac
}

HOST_HOME="$(host_home)"
CONFIG_HOME="${SEVENOS_HOST_CONFIG_HOME:-$HOST_HOME/.config}"
HYPR_CONF="$CONFIG_HOME/hypr/hyprland.conf"
MOTION_CONF="$CONFIG_HOME/hypr/conf/sevenos-motion.conf"
STATE_CONF="$CONFIG_HOME/sevenos/motion.conf"
SOURCE_LINE='source = ~/.config/hypr/conf/sevenos-motion.conf'

usage() {
  cat <<'EOF'
SevenOS Motion

Usage:
  seven motion status [--json]
  seven motion doctor
  seven motion ux-doctor
  seven motion profile [mini-os]
  seven motion set [auto|premium|balanced|reduced|off]
  seven motion apply [premium|balanced|reduced]
  seven motion premium
  seven motion balanced
  seven motion reduced
  seven motion off

SevenOS Motion owns the visible compositor animation layer. It keeps
Hyprland technical details behind a SevenOS control surface.
EOF
}

motion_preset="${2:-premium}"

active_profile() {
  local profile_file="$CONFIG_HOME/sevenos/profile.env"
  if [[ -f "$profile_file" ]]; then
    # shellcheck disable=SC1090
    source "$profile_file"
  fi
  printf '%s\n' "${SEVENOS_PROFILE:-equinox}"
}

current_preset() {
  if [[ -f "$STATE_CONF" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_CONF"
  fi
  printf '%s\n' "${SEVENOS_MOTION_PRESET:-unknown}"
}

current_mode() {
  if [[ -f "$STATE_CONF" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_CONF"
  fi
  printf '%s\n' "${SEVENOS_MOTION_MODE:-auto}"
}

profile_motion_name() {
  case "$1" in
    equinox) printf 'balanced fade' ;;
    baobab) printf 'root growth' ;;
    forge) printf 'tool snap' ;;
    shield) printf 'secure gate' ;;
    studio) printf 'canvas reveal' ;;
    windows) printf 'bridge slide' ;;
    pulse) printf 'hud sweep' ;;
    *) printf 'balanced fade' ;;
  esac
}

effective_profile_preset() {
  local profile="$1"
  local mode
  mode="$(current_mode)"
  case "$mode" in
    premium|balanced|reduced|off) printf '%s\n' "$mode" ;;
    auto|"")
      case "$profile" in
        forge|shield|windows) printf 'balanced' ;;
        pulse) printf 'latency' ;;
        *) printf 'premium' ;;
      esac
      ;;
    *) printf 'premium' ;;
  esac
}

hypr_animations_enabled() {
  if ! command -v hyprctl >/dev/null 2>&1; then
    printf 'unknown'
    return 0
  fi
  local output
  output="$(hyprctl getoption animations:enabled 2>/dev/null || true)"
  if grep -q 'int: 1' <<<"$output"; then
    printf 'true'
  elif grep -q 'int: 0' <<<"$output"; then
    printf 'false'
  else
    printf 'unknown'
  fi
}

config_errors() {
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl configerrors 2>/dev/null || true
  fi
}

write_motion_conf() {
  local preset="$1"
  local profile="${2:-$(active_profile)}"
  mkdir -p "$(dirname "$MOTION_CONF")" "$(dirname "$STATE_CONF")"

  case "$preset" in
    premium)
      cat >"$MOTION_CONF" <<EOF
# SevenOS Motion layer
# Preset: premium
# Profile: $profile
# Motion: $(profile_motion_name "$profile")
# This file is managed by \`seven motion\`.

animations {
    enabled = true
    bezier = sevenMotion, 0.12, 0.92, 0.18, 1.00
    bezier = sevenMotionOpen, 0.10, 1.00, 0.20, 1.00
    bezier = sevenMotionExit, 0.36, 0.00, 0.88, 0.18
    bezier = sevenMotionWorkspace, 0.10, 0.95, 0.12, 1.00
    bezier = sevenMotionLayer, 0.08, 1.00, 0.00, 1.00
    animation = windows, 1, 7, sevenMotionOpen, popin 78%
    animation = windowsOut, 1, 5, sevenMotionExit, popin 86%
    animation = border, 1, 9, sevenMotion
    animation = fade, 1, 7, sevenMotion
    animation = layers, 1, 7, sevenMotionLayer, popin 88%
    animation = workspaces, 1, 8, sevenMotionWorkspace, slidefade 45%
    animation = specialWorkspace, 1, 6, sevenMotionWorkspace, slidevert
}
EOF
      ;;
    profile)
      write_motion_conf "$(effective_profile_preset "$profile")" "$profile"
      return 0
      ;;
    latency)
      cat >"$MOTION_CONF" <<EOF
# SevenOS Motion layer
# Preset: latency
# Profile: $profile
# Motion: $(profile_motion_name "$profile")
# This file is managed by \`seven motion\`.

animations {
    enabled = true
    bezier = sevenMotionLatency, 0.20, 0.00, 0.18, 1.00
    animation = windows, 1, 2, sevenMotionLatency, popin 96%
    animation = windowsOut, 1, 2, sevenMotionLatency, popin 98%
    animation = border, 1, 2, sevenMotionLatency
    animation = fade, 1, 2, sevenMotionLatency
    animation = layers, 1, 2, sevenMotionLatency, fade
    animation = workspaces, 1, 2, sevenMotionLatency, slidefade 10%
    animation = specialWorkspace, 1, 2, sevenMotionLatency, fade
}
EOF
      ;;
    balanced)
      cat >"$MOTION_CONF" <<EOF
# SevenOS Motion layer
# Preset: balanced
# Profile: $profile
# Motion: $(profile_motion_name "$profile")
# This file is managed by \`seven motion\`.

animations {
    enabled = true
    bezier = sevenMotion, 0.16, 1.00, 0.30, 1.00
    bezier = sevenMotionOpen, 0.18, 1.00, 0.22, 1.00
    bezier = sevenMotionExit, 0.30, 0.00, 0.80, 0.15
    bezier = sevenMotionWorkspace, 0.16, 1.00, 0.24, 1.00
    bezier = sevenMotionLayer, 0.10, 1.00, 0.00, 1.00
    animation = windows, 1, 5, sevenMotionOpen, popin 84%
    animation = windowsOut, 1, 4, sevenMotionExit, popin 90%
    animation = border, 1, 8, sevenMotion
    animation = fade, 1, 5, sevenMotion
    animation = layers, 1, 5, sevenMotionLayer, popin 94%
    animation = workspaces, 1, 7, sevenMotionWorkspace, slidefade 32%
    animation = specialWorkspace, 1, 5, sevenMotionWorkspace, slidevert
}
EOF
      ;;
    reduced)
      cat >"$MOTION_CONF" <<EOF
# SevenOS Motion layer
# Preset: reduced
# Profile: $profile
# Motion: $(profile_motion_name "$profile")
# This file is managed by \`seven motion\`.

animations {
    enabled = true
    bezier = sevenMotionReduced, 0.20, 0.00, 0.20, 1.00
    animation = windows, 1, 2, sevenMotionReduced, fade
    animation = windowsOut, 1, 2, sevenMotionReduced, fade
    animation = border, 1, 2, sevenMotionReduced
    animation = fade, 1, 2, sevenMotionReduced
    animation = layers, 1, 2, sevenMotionReduced, fade
    animation = workspaces, 1, 2, sevenMotionReduced, fade
    animation = specialWorkspace, 1, 2, sevenMotionReduced, fade
}
EOF
      ;;
    off)
      cat >"$MOTION_CONF" <<'EOF'
# SevenOS Motion layer
# Preset: off
# This file is managed by `seven motion`.

animations {
    enabled = false
}
EOF
      ;;
    *)
      log_error "Unknown motion preset: $preset"
      exit 1
      ;;
  esac

  cat >"$STATE_CONF" <<EOF
SEVENOS_MOTION_PRESET=$preset
SEVENOS_MOTION_MODE=$(current_mode)
SEVENOS_MOTION_PROFILE=$profile
SEVENOS_MOTION_UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

set_motion_mode() {
  local mode="$1"
  case "$mode" in
    auto|premium|balanced|reduced|off) ;;
    *)
      log_error "Unknown motion mode: $mode"
      exit 1
      ;;
  esac
  mkdir -p "$(dirname "$STATE_CONF")"
  cat >"$STATE_CONF" <<EOF
SEVENOS_MOTION_PRESET=$(current_preset)
SEVENOS_MOTION_MODE=$mode
SEVENOS_MOTION_PROFILE=$(active_profile)
SEVENOS_MOTION_UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  apply_profile_preset "$(active_profile)"
}

ensure_hypr_source() {
  [[ -f "$HYPR_CONF" ]] || return 0
  if grep -Fxq "$SOURCE_LINE" "$HYPR_CONF"; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v line="$SOURCE_LINE" '
    $0 == "source = ~/.config/hypr/conf/custom.conf" && !done {
      print line
      done = 1
    }
    { print }
    END {
      if (!done) print line
    }
  ' "$HYPR_CONF" >"$tmp"
  mv "$tmp" "$HYPR_CONF"
}

reload_motion() {
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
}

status_json() {
  local preset mode enabled source_state conf_state errors
  preset="$(current_preset)"
  mode="$(current_mode)"
  enabled="$(hypr_animations_enabled)"
  source_state="missing"
  conf_state="missing"
  [[ -f "$HYPR_CONF" ]] && grep -Fxq "$SOURCE_LINE" "$HYPR_CONF" && source_state="ready"
  [[ -f "$MOTION_CONF" ]] && conf_state="ready"
  errors="$(config_errors | sed '/^[[:space:]]*$/d' | sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g')"
  cat <<EOF
{
  "schema": "sevenos.motion.v1",
  "state": "$([[ "$source_state" == "ready" && "$conf_state" == "ready" && "$enabled" != "false" ]] && printf ready || printf action-needed)",
  "profile": "$(active_profile)",
  "preset": "$preset",
  "mode": "$mode",
  "profile_motion": "$(profile_motion_name "$(active_profile)")",
  "hypr_animations_enabled": "$enabled",
  "motion_source": "$source_state",
  "motion_config": "$conf_state",
  "motion_config_path": "$MOTION_CONF",
  "config_errors": "$errors"
}
EOF
}

status_human() {
  local preset mode enabled source_state conf_state
  preset="$(current_preset)"
  mode="$(current_mode)"
  enabled="$(hypr_animations_enabled)"
  source_state="MISS"
  conf_state="MISS"
  [[ -f "$HYPR_CONF" ]] && grep -Fxq "$SOURCE_LINE" "$HYPR_CONF" && source_state="OK"
  [[ -f "$MOTION_CONF" ]] && conf_state="OK"

  cat <<EOF
SevenOS Motion
==============
Profile: $(active_profile)
Preset: $preset
Mode: $mode
Profile motion: $(profile_motion_name "$(active_profile)")
Hyprland animations: $enabled
Motion source: $source_state
Motion config: $conf_state
Config: $MOTION_CONF
EOF

  local errors
  errors="$(config_errors)"
  if [[ -n "$errors" ]]; then
    printf '\nConfig errors:\n%s\n' "$errors"
  fi
}

apply_preset() {
  local preset="$1"
  write_motion_conf "$preset" "$(active_profile)"
  ensure_hypr_source
  reload_motion
  log_success "SevenOS Motion preset applied: $preset"
}

apply_profile_preset() {
  local profile="${1:-$(active_profile)}"
  local preset
  preset="$(effective_profile_preset "$profile")"
  write_motion_conf "$preset" "$profile"
  ensure_hypr_source
  reload_motion
  log_success "SevenOS Motion profile applied: $profile ($preset · $(profile_motion_name "$profile"))"
}

doctor() {
  local status
  status="$(status_json)"
  if grep -q '"state": "ready"' <<<"$status"; then
    printf 'SevenOS Motion doctor: ready\n'
    return 0
  fi
  printf 'SevenOS Motion doctor: action-needed\n'
  status_human
  return 1
}

ux_doctor() {
  local ok=1 profile passage
  [[ -x "$ROOT_DIR/bin/seven-passage-overlay" ]] || ok=0
  [[ -x "$ROOT_DIR/bin/seven-passage-sound" ]] || ok=0
  "$ROOT_DIR/bin/seven-passage-overlay" --probe >/dev/null 2>&1 || ok=0
  "$ROOT_DIR/bin/seven-passage-sound" --probe >/dev/null 2>&1 || ok=0
  for profile in equinox baobab forge shield studio windows pulse; do
    passage="$CONFIG_HOME/sevenos/profiles/$profile/passage.json"
    if [[ ! -f "$passage" ]] ||
       ! grep -q '"motion"' "$passage" ||
       ! grep -q '"sound"' "$passage"; then
      ok=0
    fi
  done
  if [[ "$ok" == "1" ]]; then
    printf 'SevenOS Motion UX doctor: ready\n'
    return 0
  fi
  printf 'SevenOS Motion UX doctor: action-needed\n'
  return 1
}

action="${1:-status}"
case "$action" in
  status)
    if [[ "${2:-}" == "--json" || "${SEVENOS_JSON:-0}" == "1" ]]; then
      status_json
    else
      status_human
    fi
    ;;
  json)
    status_json
    ;;
  doctor)
    doctor
    ;;
  ux-doctor)
    ux_doctor
    ;;
  apply)
    apply_preset "$motion_preset"
    ;;
  profile)
    apply_profile_preset "${2:-$(active_profile)}"
    ;;
  set)
    set_motion_mode "${2:-auto}"
    ;;
  premium|balanced|reduced|latency|off)
    apply_preset "$action"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
