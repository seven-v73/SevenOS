#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
WINDOW_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/window"
MODE_ENV="$STATE_DIR/window-mode.env"
MODE_JSON="$STATE_DIR/window-mode.json"
WINDOW_MEMORY_JSON="$WINDOW_STATE_DIR/memory.json"
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
  seven-window controls
  seven-window remember
  seven-window memory [--json]
  seven-window restore [class]
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
  experience_focus "$title" "$body"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$body" >/dev/null 2>&1 || true
  fi
}

experience_focus() {
  local title="$1"
  local body="${2:-}"
  if [[ -x "$ROOT_DIR/scripts/shell-experience.sh" ]]; then
    "$ROOT_DIR/scripts/shell-experience.sh" focus "$title" "$body" >/dev/null 2>&1 || true
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

window_memory_snapshot() {
  local profile now active clients_json
  profile="$(active_profile)"
  now="$(date -Iseconds)"
  active="$(active_window_json)"
  clients_json="[]"
  if hypr_available; then
    clients_json="$(hyprctl -j clients 2>/dev/null || printf '[]')"
  fi
  PROFILE="$profile" UPDATED_AT="$now" ACTIVE_WINDOW_JSON="$active" CLIENTS_JSON="$clients_json" python - <<'PY'
import json
import os

def norm_window(item):
    workspace = item.get("workspace") if isinstance(item.get("workspace"), dict) else {}
    return {
        "address": item.get("address", ""),
        "class": item.get("class") or item.get("initialClass") or "",
        "title": item.get("title", ""),
        "workspace": workspace.get("name") or workspace.get("id") or "",
        "floating": bool(item.get("floating")),
        "fullscreen": item.get("fullscreen", False),
        "at": item.get("at") if isinstance(item.get("at"), list) else [],
        "size": item.get("size") if isinstance(item.get("size"), list) else [],
    }

try:
    active = json.loads(os.environ.get("ACTIVE_WINDOW_JSON") or "{}")
except Exception:
    active = {}
try:
    clients = json.loads(os.environ.get("CLIENTS_JSON") or "[]")
except Exception:
    clients = []

windows = [norm_window(item) for item in clients if isinstance(item, dict)]
classes = {}
for item in windows:
    key = str(item.get("class") or "window").lower()
    if key and key not in classes:
        classes[key] = item
active_item = norm_window(active) if isinstance(active, dict) else {}
if active_item.get("class"):
    classes[str(active_item["class"]).lower()] = active_item

print(json.dumps({
    "schema": "sevenos.window-memory.v1",
    "profile": os.environ.get("PROFILE", "equinox"),
    "updated_at": os.environ.get("UPDATED_AT", ""),
    "active": active_item,
    "classes": classes,
    "windows": windows,
}, ensure_ascii=False, indent=2))
PY
}

remember_window() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY-RUN > Seven Window Memory > remember active window\n'
    return 0
  fi
  mkdir -p "$WINDOW_STATE_DIR"
  window_memory_snapshot >"$WINDOW_MEMORY_JSON"
  experience_focus "Window memory" "remembered"
}

window_memory_json() {
  mkdir -p "$WINDOW_STATE_DIR"
  if [[ ! -s "$WINDOW_MEMORY_JSON" ]]; then
    window_memory_snapshot >"$WINDOW_MEMORY_JSON"
  fi
  cat "$WINDOW_MEMORY_JSON"
}

restore_window() {
  local requested="${1:-}"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY-RUN > Seven Window Memory > restore %s\n' "${requested:-active}"
    return 0
  fi
  remember_window >/dev/null 2>&1 || true
  local restore_json
  restore_json="$(REQUESTED_CLASS="$requested" python - "$WINDOW_MEMORY_JSON" <<'PY'
import json
import os
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8") or "{}")
requested = os.environ.get("REQUESTED_CLASS", "").lower()
item = {}
if requested:
    item = (data.get("classes") or {}).get(requested, {})
if not item:
    item = data.get("active") or {}
print(json.dumps(item))
PY
)"
  local address workspace floating fullscreen at_x at_y size_w size_h
  address="$(python -c 'import json,sys; print(json.loads(sys.argv[1]).get("address",""))' "$restore_json")"
  workspace="$(python -c 'import json,sys; print(json.loads(sys.argv[1]).get("workspace",""))' "$restore_json")"
  floating="$(python -c 'import json,sys; print("true" if json.loads(sys.argv[1]).get("floating") else "false")' "$restore_json")"
  fullscreen="$(python -c 'import json,sys; print(json.loads(sys.argv[1]).get("fullscreen", False))' "$restore_json")"
  at_x="$(python -c 'import json,sys; d=json.loads(sys.argv[1]); a=d.get("at") or []; print(a[0] if len(a)>0 else "")' "$restore_json")"
  at_y="$(python -c 'import json,sys; d=json.loads(sys.argv[1]); a=d.get("at") or []; print(a[1] if len(a)>1 else "")' "$restore_json")"
  size_w="$(python -c 'import json,sys; d=json.loads(sys.argv[1]); s=d.get("size") or []; print(s[0] if len(s)>0 else "")' "$restore_json")"
  size_h="$(python -c 'import json,sys; d=json.loads(sys.argv[1]); s=d.get("size") or []; print(s[1] if len(s)>1 else "")' "$restore_json")"

  [[ -n "$workspace" ]] && run_hypr dispatch workspace "$workspace"
  [[ -n "$address" ]] && run_hypr dispatch focuswindow "address:$address"
  if [[ "$floating" == "true" ]]; then
    active_is_floating || run_hypr dispatch togglefloating active
    [[ -n "$size_w" && -n "$size_h" ]] && run_hypr dispatch resizeactive exact "$size_w" "$size_h"
    [[ -n "$at_x" && -n "$at_y" ]] && run_hypr dispatch moveactive exact "$at_x" "$at_y"
  fi
  [[ "$fullscreen" == "1" || "$fullscreen" == "true" || "$fullscreen" == "2" ]] && run_hypr dispatch fullscreen 0
  experience_focus "Window memory" "restored ${requested:-active}"
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
    printf 'DRY-RUN > SevenDecor > Open native layout menu\n'
    printf '%s\n' "$options"
    return 0
  fi

  if command -v seven-window-controls-native >/dev/null 2>&1 && seven-window-controls-native --probe >/dev/null 2>&1; then
    seven-window-controls-native --menu
    return 0
  fi

  if [[ -x "$ROOT_DIR/bin/seven-window-controls-native" ]] && "$ROOT_DIR/bin/seven-window-controls-native" --probe >/dev/null 2>&1; then
    "$ROOT_DIR/bin/seven-window-controls-native" --menu
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

controls() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY-RUN > SevenDecor > Open universal window controls overlay\n'
    return 0
  fi
  if command -v seven-window-controls-native >/dev/null 2>&1 && seven-window-controls-native --probe >/dev/null 2>&1; then
    setsid -f seven-window-controls-native >/tmp/sevenos-window-controls.log 2>&1 || return 1
    return 0
  fi
  if [[ -x "$ROOT_DIR/bin/seven-window-controls-native" ]] && "$ROOT_DIR/bin/seven-window-controls-native" --probe >/dev/null 2>&1; then
    setsid -f "$ROOT_DIR/bin/seven-window-controls-native" >/tmp/sevenos-window-controls.log 2>&1 || return 1
    return 0
  fi
  layout_menu
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
    "decor": "phase-2-overlay",
    "layout": "hyprland-backed",
    "effects": "hyprland-backed",
    "memory": "sevenos.window-memory.v1",
    "experience": "sevenos.shell-experience.v1"
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
    "universal_override": "seven-window-controls-native-overlay"
  },
  "overlay": {
    "command": "seven-window controls",
    "native": $([[ -x "$ROOT_DIR/bin/seven-window-controls-native" ]] && "$ROOT_DIR/bin/seven-window-controls-native" --probe >/dev/null 2>&1 && printf true || printf false)
  },
  "state_files": {
    "env": $(json_string "$MODE_ENV"),
    "json": $(json_string "$MODE_JSON"),
    "window_memory": $(json_string "$WINDOW_MEMORY_JSON")
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
  printf '\nActions: controls, toggle-float, smart-maximize, fullscreen, split-left, split-right, mosaic, layout-menu, remember, restore\n'
}

doctor() {
  local failed=0
  hypr_available || { printf 'MISS hyprctl\n'; failed=1; }
  [[ -s "$ROOT_DIR/hyprland/conf/sevenos-windows.conf" ]] || { printf 'MISS hyprland/conf/sevenos-windows.conf\n'; failed=1; }
  grep -q 'sevenos-windows.conf' "$ROOT_DIR/hyprland/hyprland.conf" || { printf 'MISS hyprland source include\n'; failed=1; }
  grep -q 'seven-window toggle-float' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" || { printf 'MISS toggle-float bind\n'; failed=1; }
  [[ -x "$ROOT_DIR/bin/seven-window-controls-native" ]] || { printf 'MISS seven-window-controls-native\n'; failed=1; }
  grep -q 'SevenDecor phase 1' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" || { printf 'MISS GTK4 SevenDecor traffic CSS\n'; failed=1; }
  grep -q 'gtk-decoration-layout=close,minimize,maximize:' "$ROOT_DIR/hyprland/gtk-4.0/settings.ini" || { printf 'MISS GTK decoration layout\n'; failed=1; }
  grep -q 'sevenos.window-memory.v1' "$ROOT_DIR/scripts/smart-window.sh" || { printf 'MISS window memory contract\n'; failed=1; }
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
    controls|overlay) controls ;;
    remember) remember_window ;;
    memory)
      if [[ "${1:-}" == "--json" || "${1:-}" == "json" ]]; then
        window_memory_json
      else
        window_memory_json | python -m json.tool
      fi
      ;;
    restore) restore_window "${1:-}" ;;
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
