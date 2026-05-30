#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
SHELL_STATUS_CACHE="$CACHE_DIR/shell-status.json"
SHELL_STATUS_CACHE_TTL="${SEVENOS_SHELL_STATUS_CACHE_TTL:-120}"
REFRESH_CACHE="${SEVENOS_SHELL_REFRESH:-0}"

usage() {
  cat <<'EOF'
SevenOS Shell

Usage:
  seven shell [status|plan|doctor|preview]
  seven shell status --json
  seven shell plan --json
  ./scripts/shell.sh [status|plan|doctor|preview] [--json]

Seven Shell tracks the production fallback and the B3 AGS/TypeScript target.
The current shell is Native GTK + Waybar + Hyprland-managed dock; AGS replaces
surfaces gradually when its runtime policy is settled.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    --refresh|--no-cache) REFRESH_CACHE=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done

json_cache_valid() {
  [[ -s "$1" ]] || return 1
  python - "$1" "$ROOT_DIR" >/dev/null 2>&1 <<'PY'
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)
if data.get("root") != str(Path(sys.argv[2]).resolve()):
    raise SystemExit(1)
raise SystemExit(0)
PY
}

cache_is_fresh() {
  local path="$1"
  local ttl="$2"
  local now mtime
  [[ "$REFRESH_CACHE" == 1 ]] && return 1
  json_cache_valid "$path" || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || printf 0)"
  (( now - mtime < ttl ))
}

write_json_cache() {
  local path="$1"
  local tmp
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.XXXXXX")"
  cat >"$tmp"
  if json_cache_valid "$tmp"; then
    mv -f "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
}

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

package_state() {
  command -v pacman >/dev/null 2>&1 && pacman -Q "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

file_state() {
  [[ -s "$ROOT_DIR/$1" ]] && printf OK || printf MISS
}

runtime_state() {
  if command -v ags >/dev/null 2>&1; then
    printf READY
  elif [[ "$(file_state bin/seven-dock-native)" == OK &&
          "$(file_state bin/seven-waybar-center-native)" == OK &&
          "$(file_state bin/seven-settings-native)" == OK &&
          "$(file_state hyprland/waybar/config.jsonc)" == OK &&
          "$(file_state hyprland/waybar/style.css)" == OK &&
          "$(package_state waybar)" == OK &&
          "$(package_state gtk-layer-shell)" == OK ]]; then
    printf NATIVE_READY
  elif [[ "$(file_state seven-shell/ags/src/config.ts)" == OK &&
          "$(file_state seven-shell/ags/src/dock.ts)" == OK &&
          "$(file_state bin/seven-shell-panel)" == OK &&
          "$(file_state bin/seven-apps)" == OK &&
          "$(package_state typescript)" == OK &&
          "$(package_state gtk4)" == OK &&
          "$(package_state libadwaita)" == OK &&
          "$(command_state node)" == OK ]]; then
    printf FOUNDATION
  else
    printf PLANNED
  fi
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

core_health_json() {
  if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    if command -v timeout >/dev/null 2>&1; then
      timeout "${SEVENOS_SHELL_HEALTH_TIMEOUT:-4s}" "$ROOT_DIR/bin/seven-daemon" health --json 2>/dev/null || printf '{"schema":"sevenos.daemon.health.v1","state":"PART","name":"seven-daemon","timeout":true,"checks":[]}'
    else
      "$ROOT_DIR/bin/seven-daemon" health --json 2>/dev/null || printf 'null'
    fi
  else
    printf 'null'
  fi
}

status_json_uncached() {
  local runtime health
  runtime="$(runtime_state)"
  health="$(core_health_json)"
  printf '{'
  printf '"schema":"sevenos.shell.v1",'
  printf '"root":%s,' "$(printf '%s' "$(realpath "$ROOT_DIR")" | json_string)"
  printf '"phase":"B3",'
  printf '"state":%s,' "$(printf '%s' "$runtime" | json_string)"
  printf '"strategy":"Native GTK production fallback now; AGS + TypeScript as the B3 replacement path",'
  printf '"fallback":"Waybar, Native GTK panels, Hyprland-managed Dock and Rofi remain supported until AGS surfaces are ready",'
  printf '"runtime_health":'
  printf '%s' "$health"
  printf ','
  printf '"surfaces":['
  printf '{"key":"quick-settings","state":%s,"current":"Native GTK/Waybar","target":"AGS"},' "$(printf '%s' "$(file_state bin/seven-waybar-center-native)" | json_string)"
  printf '{"key":"notifications","state":%s,"current":"Native GTK notification center","target":"AGS"},' "$(printf '%s' "$(file_state bin/seven-notification-center-native)" | json_string)"
  printf '{"key":"launcher","state":%s,"current":"Native Launchpad with Rofi fallback","target":"AGS"},' "$(printf '%s' "$(file_state bin/seven-launchpad-native)" | json_string)"
  printf '{"key":"dock","state":%s,"current":"Native GTK Hyprland-managed dock","target":"AGS or stable layer-shell"}' "$(printf '%s' "$(file_state bin/seven-dock-native)" | json_string)"
  printf '],'
  printf '"dependencies":['
  printf '{"key":"gjs","state":%s},' "$(printf '%s' "$(package_state gjs)" | json_string)"
  printf '{"key":"typescript","state":%s},' "$(printf '%s' "$(package_state typescript)" | json_string)"
  printf '{"key":"gtk4","state":%s},' "$(printf '%s' "$(package_state gtk4)" | json_string)"
  printf '{"key":"libadwaita","state":%s},' "$(printf '%s' "$(package_state libadwaita)" | json_string)"
  printf '{"key":"gtk-layer-shell","state":%s},' "$(printf '%s' "$(package_state gtk-layer-shell)" | json_string)"
  printf '{"key":"nodejs","state":%s},' "$(printf '%s' "$(command_state node)" | json_string)"
  printf '{"key":"ags","state":%s,"package":"aylurs-gtk-shell","source":"AUR","warning":"Do not install AUR package ags; Seven Shell needs Aylur'\''s Gtk Shell."}' "$(printf '%s' "$(command_state ags)" | json_string)"
  printf '],'
  printf '"contracts":["seven state --json","seven actions --json","seven core snapshot --json","seven core health --json","seven profile current --json","seven shell status --json","seven deploy inspect . --json","seven deploy status --json","seven deploy services --json","seven deploy panel --json","seven deploy versions <project> --json","seven deploy domain <domain> --target tunnel|vps --json","seven deploy dns-check <domain> --expected-ip|--expected-cname ... --json","seven deploy route-check <project-or-domain> --json","seven deploy diagnose <project-or-domain> --json"],'
  printf '"profile_gates":{"deploy":{"required_profile":"forge","blocked_contract":"sevenos.profile-gate.v1","fallback_commands":["seven profile activate forge","seven-terminal forge"]}},'
  printf '"commands":{"install":"./install.sh shell-ags","runtime":"./install.sh shell-ags-runtime --yes","runtime_status":"scripts/shell-ags-runtime.sh status --json","plan":"seven shell plan","preview":"seven shell preview"}'
  printf '}\n'
}

status_json() {
  if cache_is_fresh "$SHELL_STATUS_CACHE" "$SHELL_STATUS_CACHE_TTL"; then
    cat "$SHELL_STATUS_CACHE"
    return 0
  fi

  local payload
  payload="$(status_json_uncached)"
  printf '%s\n' "$payload" | write_json_cache "$SHELL_STATUS_CACHE" || true
  printf '%s\n' "$payload"
}

plan_json() {
  SHELL_STATUS="$(status_json)" python - <<'PY'
import json
import os

status = json.loads(os.environ["SHELL_STATUS"])

meta = {
    "gjs": ("Install GJS runtime", "high", "packages", "AGS depends on GNOME JavaScript bindings."),
    "typescript": ("Install TypeScript", "medium", "packages", "Seven Shell source should be typed from the beginning."),
    "gtk4": ("Install GTK4", "medium", "packages", "AGS shell surfaces need GTK4 widgets."),
    "libadwaita": ("Install libadwaita", "medium", "packages", "Seven Shell should stay visually native with GNOME-like components."),
    "gtk-layer-shell": ("Install GTK layer shell support", "high", "packages", "Native SevenOS panels and dock need stable layer-shell support where the compositor allows it."),
    "nodejs": ("Install Node.js", "medium", "packages", "TypeScript tooling needs Node.js."),
    "ags": ("Install Aylur's Gtk Shell runtime", "high", "manual", "AGS is not in the core Arch repo here; install the explicit AUR package aylurs-gtk-shell only after review."),
}

actions = []
for dep in status.get("dependencies", []):
    if dep.get("state") == "OK":
        continue
    key = dep.get("key")
    title, severity, impact, reason = meta.get(key, (f"Prepare {key}", "medium", "packages", f"Prepare {key}."))
    command = "./install.sh shell-ags" if key != "ags" else "./install.sh shell-ags-runtime --yes"
    actions.append({
        "key": key,
        "title": title,
        "severity": severity,
        "impact": impact,
        "reason": reason,
        "command": command,
    })

for surface in status.get("surfaces", []):
    if surface.get("state") != "OK":
        actions.append({
            "key": surface.get("key"),
            "title": f"Scaffold {surface.get('key')} surface",
            "severity": "medium",
            "impact": "safe",
            "reason": f"Seven Shell needs a planned {surface.get('target')} version of {surface.get('key')}.",
            "command": "seven shell preview",
        })

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions.sort(key=lambda item: (rank.get(item["severity"], 9), item["key"]))

print(json.dumps({
    "schema": "sevenos.shell-plan.v1",
    "summary": {
        "total": len(actions),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
    },
    "next": actions,
}, indent=2))
PY
}

status() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    status_json
    return 0
  fi

  printf 'SevenOS Shell Status\n'
  printf '====================\n'
  printf 'state:       %s\n' "$(runtime_state)"
  printf 'strategy:    Native GTK production fallback now; AGS + TypeScript target next\n'
  printf 'fallback:    Waybar, Native GTK panels, Hyprland-managed Dock and Rofi stay active\n'
  CORE_HEALTH="$(core_health_json)" python - <<'PY'
import json
import os

try:
    health = json.loads(os.environ.get("CORE_HEALTH") or "null") or {}
except json.JSONDecodeError:
    health = {}

runtime = health.get("runtime", {})
memory = runtime.get("memory", {})
session = health.get("session", {})
if health:
    print(f"core health: {health.get('state', 'unknown')}")
    print(f"session:     {session.get('desktop') or 'unknown'} / {session.get('wayland_display') or 'no-wayland'}")
    print(f"memory:      {memory.get('used_percent', 0)}% used")
PY
  printf 'install:     ./install.sh shell-ags\n'
  printf 'next:        seven shell plan\n'
}

plan() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    plan_json
    return 0
  fi

  SHELL_PLAN="$(plan_json)" python - <<'PY'
import json
import os

plan = json.loads(os.environ["SHELL_PLAN"])
summary = plan.get("summary", {})
print("SevenOS Shell Plan")
print("==================")
print(f"Open actions: {summary.get('total', 0)}")
print()
for item in plan.get("next", []):
    print(f"{item.get('severity', 'medium'):<8} {item.get('command', 'seven shell plan')}")
    print(f"         {item.get('reason', '')}")
PY
}

doctor() {
  local failures=0
  printf 'SevenOS Shell Doctor\n'
  printf '====================\n'
  for file in \
    "seven-shell/README.md" \
    "seven-shell/ags/README.md" \
    "seven-shell/ags/package.json" \
    "seven-shell/ags/tsconfig.json" \
    "seven-shell/ags/src/config.ts" \
    "scripts/packages-shell-ags.txt"; do
    if [[ -s "$ROOT_DIR/$file" ]]; then
      printf '[OK] %s\n' "$file"
    else
      printf '[MISS] %s\n' "$file"
      failures=$((failures + 1))
    fi
  done

  printf '[%s] gjs\n' "$(package_state gjs)"
  printf '[%s] typescript\n' "$(package_state typescript)"
  printf '[%s] gtk4\n' "$(package_state gtk4)"
  printf '[%s] gtk-layer-shell\n' "$(package_state gtk-layer-shell)"
  [[ -x "$ROOT_DIR/bin/seven-dock-canvas" ]] && printf '[OK] canvas dock\n' || printf '[MISS] canvas dock\n'
  [[ -x "$ROOT_DIR/bin/seven-dock-native" ]] && printf '[OK] native dock fallback\n' || printf '[MISS] native dock fallback\n'
  [[ -s "$ROOT_DIR/hyprland/waybar/config.jsonc" ]] && printf '[OK] waybar config\n' || printf '[MISS] waybar config\n'
  command -v ags >/dev/null 2>&1 && printf '[OK] ags\n' || printf '[AUR] ags runtime pending explicit workflow\n'
  "$ROOT_DIR/scripts/shell-ags-runtime.sh" status --json >/dev/null && printf '[OK] ags runtime contract\n' || { printf '[MISS] ags runtime contract\n'; failures=$((failures + 1)); }
  if [[ -f "$ROOT_DIR/seven-shell/ags/package.json" && "$(command_state npm)" == OK ]]; then
    if (cd "$ROOT_DIR/seven-shell/ags" && npm run typecheck >/dev/null 2>&1); then
      printf '[OK] ags typecheck\n'
    else
      printf '[MISS] ags typecheck\n'
      failures=$((failures + 1))
    fi
  else
    printf '[SKIP] ags typecheck (npm unavailable)\n'
  fi

  if [[ "$failures" -gt 0 ]]; then
    log_error "Seven Shell foundation has $failures missing file(s)."
    return 1
  fi

  log_success "Seven Shell foundation is coherent."
}

preview() {
  printf 'SevenOS Shell Preview\n'
  printf '=====================\n'
  printf 'B3 target: AGS + TypeScript shell\n'
  printf 'Current production fallback: Waybar + Native GTK panels + Hyprland-managed Dock + Rofi\n\n'
  printf 'Surfaces:\n'
  printf '  - Quick Settings: Native GTK now -> AGS panel next\n'
  printf '  - Notifications: Native GTK now -> AGS center next\n'
  printf '  - Launcher: Native Launchpad now -> AGS launcher next\n'
  printf '  - Dock: Native Hyprland-managed dock now -> AGS or stable layer-shell next\n\n'
  printf 'Contracts consumed:\n'
  printf '  - seven state --json\n'
  printf '  - seven actions --json\n'
  printf '  - seven core snapshot --json\n'
  printf '  - seven profile current --json\n'
  printf '  - seven core health --json\n'
  printf '  - seven shell status --json\n'
  printf '  - seven deploy inspect/status/services/panel --json (Forge only)\n'
  printf '  - seven deploy domain/dns-check/route-check/diagnose --json (Forge only)\n'
  printf '\nAGS runtime:\n'
  printf '  - status: scripts/shell-ags-runtime.sh status --json\n'
  printf '  - install: ./install.sh shell-ags-runtime --yes\n'
  printf '  - package: aylurs-gtk-shell (AUR), not ags\n'
}

case "$ACTION" in
  status) status ;;
  plan) plan ;;
  doctor) doctor ;;
  preview) preview ;;
  json|--json) JSON_OUTPUT=1; status ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown shell action: $ACTION"; usage; exit 1 ;;
esac
