#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/hypr-lua"
EVENT_LOG="$STATE_DIR/events.jsonl"
CURRENT_STATE="$STATE_DIR/current.json"

usage() {
  cat <<'EOF'
SevenOS Hypr Lua Event Bridge

Usage:
  seven-hypr-lua-events status [--json]
  seven-hypr-lua-events once
  seven-hypr-lua-events watch

This is a lightweight bridge from Hyprland events to SevenOS state. It records
events and context for the Lua/runtime layer without replacing Hyprland.
EOF
}

json_escape() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

hypr_socket() {
  local signature="${HYPRLAND_INSTANCE_SIGNATURE:-}"
  [[ -n "$signature" ]] || return 1
  printf '%s/hypr/%s/.socket2.sock\n' "${XDG_RUNTIME_DIR:-/run/user/$UID}" "$signature"
}

transport() {
  if command -v socat >/dev/null 2>&1; then
    printf 'socat\n'
  elif command -v nc >/dev/null 2>&1 && nc -h 2>&1 | grep -q -- '-U'; then
    printf 'nc-unix\n'
  elif command -v ncat >/dev/null 2>&1; then
    printf 'ncat-unix\n'
  else
    printf 'polling\n'
  fi
}

stream_socket() {
  local socket="$1"
  case "$(transport)" in
    socat) socat -U - UNIX-CONNECT:"$socket" ;;
    nc-unix) nc -U "$socket" ;;
    ncat-unix) ncat --unixsock "$socket" ;;
    *) return 1 ;;
  esac
}

write_event() {
  local event="$1" payload="${2:-}"
  mkdir -p "$STATE_DIR"
  printf '{"schema":"sevenos.hypr-lua.event.v1","event":%s,"payload":%s,"time":%s}\n' \
    "$(printf '%s' "$event" | json_escape)" \
    "$(printf '%s' "$payload" | json_escape)" \
    "$(date +%s)" >> "$EVENT_LOG"
}

active_profile() {
  local env_file="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env"
  if [[ -r "$env_file" ]]; then
    sed -nE 's/^SEVENOS_ACTIVE_PROFILE="?([^"]+)"?$/\1/p;s/^SEVENOS_PROFILE="?([^"]+)"?$/\1/p' "$env_file" | head -n1
  else
    printf 'equinox\n'
  fi
}

classify_context() {
  local text="$1"
  case "$text" in
    *Code*|*jetbrains*|*localhost*|*SevenTerminal*) printf 'forge' ;;
    *steam*|*gamescope*|*lutris*|*heroic*|*MangoHud*) printf 'pulse' ;;
    *Wireshark*|*BurpSuite*|*burpsuite*|*Nmap*) printf 'shield' ;;
    *krita*|*Blender*|*Gimp*|*Inkscape*|*obs*|*kdenlive*) printf 'studio' ;;
    *virt-manager*|*Bottles*|*Windows*) printf 'windows' ;;
    *Grafana*|*Prometheus*|*Caddy*|*ssh*|*SSH*) printf 'forge' ;;
    *SevenReader*|*Foliate*|*foliate*) printf 'baobab' ;;
    *) printf 'equinox' ;;
  esac
}

write_current_state() {
  local event="$1" raw="$2" snapshot="${3:-}"
  mkdir -p "$STATE_DIR"
  python - "$CURRENT_STATE" "$event" "$raw" "$(active_profile)" "$(classify_context "$raw $snapshot")" "$snapshot" <<'PY'
import json
import sys
import time
from pathlib import Path

path, event, raw, profile, context, snapshot = sys.argv[1:]
payload = {
    "schema": "sevenos.hypr-lua.current.v1",
    "event": event,
    "raw": raw,
    "active_profile": profile or "equinox",
    "observed_context": context or "equinox",
    "action": "context-state-updated",
    "snapshot": snapshot,
    "time": int(time.time()),
}
Path(path).write_text(json.dumps(payload, separators=(",", ":")) + "\n")
PY
}

snapshot_state() {
  local workspace active_class active_title
  workspace="$(hyprctl activeworkspace -j 2>/dev/null | python -c 'import json,sys; print(json.load(sys.stdin).get("name","unknown"))' 2>/dev/null || printf unknown)"
  active_class="$(hyprctl activewindow -j 2>/dev/null | python -c 'import json,sys; print(json.load(sys.stdin).get("class","unknown"))' 2>/dev/null || printf unknown)"
  active_title="$(hyprctl activewindow -j 2>/dev/null | python -c 'import json,sys; print(json.load(sys.stdin).get("title","unknown"))' 2>/dev/null || printf unknown)"
  printf 'workspace=%s class=%s title=%s\n' "$workspace" "$active_class" "$active_title"
}

handle_event() {
  local line="$1" event="${line%%>>*}"
  local snapshot=""
  case "$event" in
    openwindow|closewindow|activewindow|workspace|focusedmon)
      snapshot="$(snapshot_state 2>/dev/null || true)"
      write_event "$event" "$line"
      write_current_state "$event" "$line" "$snapshot"
      ;;
  esac
}

status_json() {
  local socket=""
  socket="$(hypr_socket 2>/dev/null || true)"
  python - "$socket" "$EVENT_LOG" "$CURRENT_STATE" "$(transport)" <<'PY'
import json
import os
import shutil
import sys
from pathlib import Path

socket, log, current, transport = sys.argv[1:]
socket_ready = bool(socket and Path(socket).exists())
payload = {
    "schema": "sevenos.hypr-lua.events.v1",
    "hyprland": bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")),
    "socket": socket,
    "socket_ready": socket_ready,
    "socat": bool(shutil.which("socat")),
    "transport": transport,
    "realtime_ready": socket_ready and transport != "polling",
    "event_log": log,
    "event_log_ready": Path(log).exists(),
    "current_state": current,
    "current_state_ready": Path(current).exists(),
}
print(json.dumps(payload, separators=(",", ":")))
PY
}

status() {
  if [[ "${1:-}" == "--json" || "${1:-}" == "json" ]]; then
    status_json
    return
  fi
  printf 'SevenOS Hypr Lua Event Bridge\n'
  printf 'Hyprland:  %s\n' "$([[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && printf OK || printf MISS)"
  printf 'Socket:    %s\n' "$(hypr_socket 2>/dev/null || printf MISS)"
  printf 'Transport: %s\n' "$(transport)"
  printf 'Log:       %s\n' "$EVENT_LOG"
}

once() {
  local snapshot
  snapshot="$(snapshot_state)"
  write_event "snapshot" "$snapshot"
  write_current_state "snapshot" "$snapshot" "$snapshot"
  printf '%s\n' "$EVENT_LOG"
}

poll_watch() {
  local previous="" current=""
  write_event "watch-start" "polling"
  while :; do
    current="$(snapshot_state)"
    if [[ "$current" != "$previous" ]]; then
      write_event "state-change" "$current"
      write_current_state "state-change" "$current" "$current"
      previous="$current"
    fi
    sleep "${SEVENOS_HYPR_LUA_EVENT_INTERVAL:-1}"
  done
}

watch() {
  local socket
  socket="$(hypr_socket)"
  if [[ ! -S "$socket" ]]; then
    log_error "Hyprland event socket is not available."
    return 1
  fi
  if [[ "$(transport)" == "polling" ]]; then
    log_warn "No Unix socket stream helper found; falling back to lightweight polling."
    poll_watch
    return
  fi
  write_event "watch-start" "$socket transport=$(transport)"
  stream_socket "$socket" | while IFS= read -r line; do
    handle_event "$line"
  done
}

case "${1:-status}" in
  status) status "${2:-}" ;;
  once) once ;;
  watch) watch ;;
  help|-h|--help) usage ;;
  *) log_error "Unknown Hypr Lua event action: $1"; usage; exit 1 ;;
esac
