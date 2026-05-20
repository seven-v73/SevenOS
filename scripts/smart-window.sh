#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
MODE_ENV="$STATE_DIR/window-mode.env"
MODE_JSON="$STATE_DIR/window-mode.json"
DRY_RUN="${SEVENOS_DRY_RUN:-0}"

usage() {
  cat <<'EOF'
Seven Smart Window System

Usage:
  seven-window status [--json]
  seven-window mode <smart|focus|creative|studio>
  seven-window toggle-float
  seven-window smart-maximize
  seven-window fullscreen
  seven-window split-left
  seven-window split-right
  seven-window mosaic
  seven-window layout-menu
  seven-window decor-status [--json]
  seven-window decor-apply
  seven-window doctor
EOF
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
}

current_mode() {
  if [[ -r "$MODE_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$MODE_ENV"
    printf '%s\n' "${SEVENOS_WINDOW_MODE:-smart}"
  else
    printf 'smart\n'
  fi
}

active_profile() {
  local profile_env="$STATE_DIR/profile.env"
  if [[ -r "$profile_env" ]]; then
    # shellcheck disable=SC1090
    source "$profile_env"
    printf '%s\n' "${SEVENOS_PROFILE:-equinox}"
  else
    printf 'equinox\n'
  fi
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))' <<<"${1:-}"
}

hypr_available() {
  command -v hyprctl >/dev/null 2>&1
}

notify() {
  local title="$1"
  local body="$2"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$body" >/dev/null 2>&1 || true
  fi
}

run_hypr() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY-RUN > hyprctl %s\n' "$*"
    return 0
  fi
  if hypr_available; then
    hyprctl "$@" >/dev/null 2>&1 || true
  else
    printf 'seven-window: hyprctl unavailable; skipped: hyprctl %s\n' "$*" >&2
  fi
}

active_window_json() {
  if hypr_available; then
    hyprctl -j activewindow 2>/dev/null || printf '{}\n'
  else
    printf '{}\n'
  fi
}

active_is_floating() {
  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  active_window_json | jq -e '.floating == true' >/dev/null 2>&1
}

write_mode() {
  local mode="$1"
  ensure_state_dir
  printf 'SEVENOS_WINDOW_MODE=%s\n' "$mode" >"$MODE_ENV"
  cat >"$MODE_JSON" <<EOF
{
  "schema": "sevenos.smart-window.mode.v1",
  "mode": "$mode",
  "profile": "$(active_profile)",
  "updated_at": "$(date -Iseconds)"
}
EOF
}

apply_mode() {
  local mode="$1"
  case "$mode" in
    smart)
      run_hypr keyword general:gaps_in 5
      run_hypr keyword general:gaps_out 10
      run_hypr keyword decoration:rounding 26
      run_hypr keyword decoration:dim_strength 0.06
      ;;
    focus)
      run_hypr keyword general:gaps_in 8
      run_hypr keyword general:gaps_out 28
      run_hypr keyword decoration:rounding 28
      run_hypr keyword decoration:dim_strength 0.12
      ;;
    creative)
      run_hypr keyword general:gaps_in 10
      run_hypr keyword general:gaps_out 18
      run_hypr keyword decoration:rounding 30
      run_hypr keyword decoration:dim_strength 0.04
      ;;
    studio)
      run_hypr keyword general:gaps_in 4
      run_hypr keyword general:gaps_out 8
      run_hypr keyword decoration:rounding 22
      run_hypr keyword decoration:dim_strength 0.08
      ;;
    *)
      printf 'seven-window: unknown mode: %s\n' "$mode" >&2
      return 1
      ;;
  esac
}

set_mode() {
  local mode="${1:-}"
  case "$mode" in
    smart|focus|creative|studio) ;;
    "")
      printf 'seven-window: missing mode\n' >&2
      return 1
      ;;
    *)
      printf 'seven-window: unsupported mode: %s\n' "$mode" >&2
      return 1
      ;;
  esac
  write_mode "$mode"
  apply_mode "$mode"
  notify "Seven Smart Windows" "Mode: $mode"
  printf 'Seven Smart Windows: %s mode active\n' "$mode"
}

toggle_float() {
  run_hypr dispatch togglefloating active
  run_hypr dispatch centerwindow
  notify "Seven Smart Windows" "Tiling / floating toggled"
}

smart_maximize() {
  run_hypr dispatch fullscreen 1
  notify "Seven Smart Windows" "Smart maximize"
}

fullscreen() {
  run_hypr dispatch fullscreen 0
  notify "Seven Smart Windows" "Fullscreen"
}

split_left() {
  active_is_floating && run_hypr dispatch togglefloating active
  run_hypr dispatch movewindow l
  run_hypr dispatch splitratio exact 0.50
  notify "Seven Smart Windows" "Split left"
}

split_right() {
  active_is_floating && run_hypr dispatch togglefloating active
  run_hypr dispatch movewindow r
  run_hypr dispatch splitratio exact 0.50
  notify "Seven Smart Windows" "Split right"
}

mosaic() {
  run_hypr dispatch togglesplit
  run_hypr dispatch pseudo
  notify "Seven Smart Windows" "Mosaic layout"
}

layout_menu() {
  local choice=""
  local options
  options=$'Smart maximize\nFullscreen\nSplit left\nSplit right\nToggle floating\nMosaic\nMode: Smart\nMode: Focus\nMode: Creative\nMode: Studio'

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s\n' "$options"
    return 0
  fi

  if command -v rofi >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$options" | rofi -dmenu -i -p "Window" -theme-str 'window { width: 28%; } listview { lines: 10; }' || true)"
  elif command -v wofi >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$options" | wofi --dmenu --prompt "Window" || true)"
  else
    printf '%s\n' "$options"
    return 0
  fi

  case "$choice" in
    "Smart maximize") smart_maximize ;;
    "Fullscreen") fullscreen ;;
    "Split left") split_left ;;
    "Split right") split_right ;;
    "Toggle floating") toggle_float ;;
    "Mosaic") mosaic ;;
    "Mode: Smart") set_mode smart ;;
    "Mode: Focus") set_mode focus ;;
    "Mode: Creative") set_mode creative ;;
    "Mode: Studio") set_mode studio ;;
  esac
}

gtk_decoration_layout() {
  local settings_file="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/settings.ini"
  local value=""
  if command -v gsettings >/dev/null 2>&1; then
    value="$(gsettings get org.gnome.desktop.interface gtk-decoration-layout 2>/dev/null | tr -d "'" || true)"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  fi
  if [[ -r "$settings_file" ]]; then
    awk -F= '$1 == "gtk-decoration-layout" {print $2; found=1} END {if (!found) exit 1}' "$settings_file" 2>/dev/null || true
  fi
}

copy_gtk_decor_theme() {
  local theme_mode source_dir config_home
  config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  theme_mode="${SEVENOS_THEME_MODE:-}"
  if [[ -z "$theme_mode" && -r "$STATE_DIR/theme.conf" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_DIR/theme.conf" || true
    theme_mode="${SEVENOS_THEME_MODE:-}"
  fi
  if [[ "$theme_mode" == "light" ]]; then
    source_dir="$ROOT_DIR/hyprland-light"
  else
    source_dir="$ROOT_DIR/hyprland"
  fi

  mkdir -p "$config_home/gtk-3.0" "$config_home/gtk-4.0"
  cp "$source_dir/gtk-3.0/gtk.css" "$config_home/gtk-3.0/gtk.css"
  cp "$source_dir/gtk-4.0/gtk.css" "$config_home/gtk-4.0/gtk.css"
  cp "$source_dir/gtk-3.0/settings.ini" "$config_home/gtk-3.0/settings.ini"
  cp "$source_dir/gtk-4.0/settings.ini" "$config_home/gtk-4.0/settings.ini"
}

decor_apply() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY-RUN > gsettings set org.gnome.desktop.interface gtk-decoration-layout close,minimize,maximize:\n'
    printf 'DRY-RUN > copy GTK SevenDecor traffic-light theme to ~/.config/gtk-3.0 and ~/.config/gtk-4.0\n'
    return 0
  fi

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-decoration-layout 'close,minimize,maximize:' >/dev/null 2>&1 || true
  fi
  copy_gtk_decor_theme
  notify "SevenDecor" "GTK traffic-light coverage applied"
  printf 'SevenDecor: GTK traffic-light coverage applied\n'
  printf 'Note: Qt, Electron, Java and XWayland apps still need the future compositor SevenDecor layer for universal buttons.\n'
}

decor_status_json() {
  local layout gtk_css
  layout="$(gtk_decoration_layout)"
  gtk_css="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/gtk.css"
  cat <<EOF
{
  "schema": "sevenos.decor-coverage.v1",
  "decor_engine": "SevenDecor",
  "phase": "phase-1-user-space",
  "gtk": {
    "layout": $(json_string "${layout:-unknown}"),
    "traffic_css": $([[ -r "$gtk_css" ]] && grep -q 'SevenDecor phase 1' "$gtk_css" && printf true || printf false),
    "coverage": "good-for-gtk-csd"
  },
  "sevenos_native": {
    "coverage": "full",
    "notes": "SevenOS native apps draw their own traffic lights."
  },
  "qt": {
    "coverage": "partial",
    "notes": "Qt title buttons depend on toolkit/window decoration behavior."
  },
  "electron": {
    "coverage": "partial",
    "notes": "Electron apps often draw custom titlebars and cannot be fully restyled by Hyprland rules."
  },
  "xwayland": {
    "coverage": "rules-only",
    "notes": "Hyprland can place and animate these windows, but cannot inject real titlebar buttons in phase 1."
  },
  "future": "SevenDecor compositor/plugin layer for universal traffic-light override"
}
EOF
}

decor_status_text() {
  printf 'SevenDecor Coverage\n'
  printf 'SevenOS native: full traffic lights\n'
  printf 'GTK CSD:        %s\n' "$(gtk_decoration_layout || printf unknown)"
  printf 'Qt/Electron:    partial, app-dependent\n'
  printf 'XWayland:       placement/actions only\n'
  printf '\nRun: seven-window decor-apply\n'
}

status_json() {
  local mode profile hypr
  mode="$(current_mode)"
  profile="$(active_profile)"
  hypr="false"
  hypr_available && hypr="true"
  cat <<EOF
{
  "schema": "sevenos.smart-window.v1",
  "name": "Seven Smart Window System",
  "mode": $(json_string "$mode"),
  "profile": $(json_string "$profile"),
  "hyprland": $hypr,
  "engines": {
    "decor": "phase-1-contract",
    "layout": "hyprland-backed",
    "effects": "hyprland-backed",
    "ai": "planned-workspace-memory"
  },
  "traffic_lights": {
    "red": "close",
    "yellow": "toggle-floating",
    "green": "smart-maximize",
    "green_double": "fullscreen",
    "green_hold": "layout-menu"
  },
  "decor_coverage": {
    "sevenos_native": "full",
    "gtk": "good-for-csd",
    "qt": "partial",
    "electron": "partial",
    "xwayland": "rules-only",
    "universal_override": "planned-seven-decor-compositor-layer"
  },
  "state_files": {
    "env": $(json_string "$MODE_ENV"),
    "json": $(json_string "$MODE_JSON")
  }
}
EOF
}

status_text() {
  printf 'Seven Smart Window System\n'
  printf 'Mode:    %s\n' "$(current_mode)"
  printf 'Profile: %s\n' "$(active_profile)"
  if hypr_available; then
    printf 'Hyprland: OK\n'
  else
    printf 'Hyprland: MISS\n'
  fi
  printf '\nActions: toggle-float, smart-maximize, fullscreen, split-left, split-right, mosaic, layout-menu\n'
}

doctor() {
  local failed=0
  hypr_available || { printf 'MISS hyprctl\n'; failed=1; }
  [[ -s "$ROOT_DIR/hyprland/conf/sevenos-windows.conf" ]] || { printf 'MISS hyprland/conf/sevenos-windows.conf\n'; failed=1; }
  grep -q 'sevenos-windows.conf' "$ROOT_DIR/hyprland/hyprland.conf" || { printf 'MISS hyprland source include\n'; failed=1; }
  grep -q 'seven-window toggle-float' "$ROOT_DIR/hyprland/hyprland.conf" || { printf 'MISS toggle-float bind\n'; failed=1; }
  grep -q 'SevenDecor phase 1' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" || { printf 'MISS GTK4 SevenDecor traffic CSS\n'; failed=1; }
  grep -q 'gtk-decoration-layout=close,minimize,maximize:' "$ROOT_DIR/hyprland/gtk-4.0/settings.ini" || { printf 'MISS GTK decoration layout\n'; failed=1; }
  if [[ "$failed" == "0" ]]; then
    printf 'Seven Smart Window System: OK\n'
  else
    return 1
  fi
}

main() {
  local action="${1:-status}"
  shift || true
  case "$action" in
    status)
      if [[ "${1:-}" == "--json" || "${1:-}" == "json" ]]; then
        status_json
      else
        status_text
      fi
      ;;
    json) status_json ;;
    mode) set_mode "${1:-}" ;;
    apply) apply_mode "$(current_mode)" ;;
    toggle-float|toggle-floating) toggle_float ;;
    smart-maximize|maximize) smart_maximize ;;
    fullscreen) fullscreen ;;
    split-left) split_left ;;
    split-right) split_right ;;
    mosaic) mosaic ;;
    layout-menu|menu) layout_menu ;;
    decor-status)
      if [[ "${1:-}" == "--json" || "${1:-}" == "json" ]]; then
        decor_status_json
      else
        decor_status_text
      fi
      ;;
    decor-apply) decor_apply ;;
    doctor) doctor ;;
    help|-h|--help) usage ;;
    *)
      usage >&2
      return 1
      ;;
  esac
}

main "$@"
