#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
REFRESH_CACHE="${SEVENOS_UNIVERSES_REFRESH:-0}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
UNIVERSES_CACHE="$CACHE_DIR/universes-${ACTION}.json"
UNIVERSES_CACHE_TTL="${SEVENOS_UNIVERSES_CACHE_TTL:-300}"

usage() {
  cat <<'EOF'
SevenOS Universes

Usage:
  seven universes [status|doctor|plan|json] [--json]

Shows SevenOS as a modular ecosystem: SevenOS Core, Equinox as the control
center, and the seven user universes that adapt the whole experience.
EOF
}

for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    --refresh|--no-cache) REFRESH_CACHE=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done
[[ "$ACTION" == "--json" || "$ACTION" == "--refresh" || "$ACTION" == "--no-cache" ]] && ACTION="status"
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1
UNIVERSES_CACHE="$CACHE_DIR/universes-${ACTION}.json"

payload_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def run_json(command, fallback=None, timeout=20):
    fallback = fallback or {}
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
            env={**os.environ, "SEVENOS_ROOT": str(root)},
        )
        return json.loads(result.stdout) if result.stdout.strip() else fallback
    except Exception:
        return fallback


profile_health = run_json([str(root / "bin/seven"), "profile", "health", "--json"], {"profiles": [], "summary": {}})
bridge = run_json([str(root / "bin/seven"), "bridge", "graph", "--json"], {"nodes": [], "edges": []})
if os.environ.get("SEVENOS_UNIVERSES_FROM_EXPERIENCE") == "1":
    missions = {"missions": {"items": [], "bridge_state": "embedded"}}
else:
    missions = run_json([str(root / "bin/seven-experience-center"), "missions", "--json"], {"missions": {}})

profiles = {str(item.get("key")): item for item in profile_health.get("profiles", []) if isinstance(item, dict) and item.get("key")}
bridge_nodes = {str(item.get("id")): item for item in bridge.get("nodes", []) if isinstance(item, dict) and item.get("id")}

core = {
    "key": "sevenos-core",
    "title": "SevenOS Core",
    "role": "Arch-compatible system foundation",
    "capabilities": [
        "Arch Linux compatible base",
        "package and source orchestration",
        "system security and repair routes",
        "hardware and driver readiness",
        "user and profile account model",
        "SevenBus, Seven Core and local service contracts",
    ],
    "commands": ["seven core status", "seven health", "seven first-run verify"],
    "ready": (root / "scripts/core.sh").exists() and (root / "bin/seven").exists(),
}

universe_specs = [
    ("equinox", "Equinox", "Control center and balanced host OS", ["global dashboard", "resource and profile control", "settings sync", "module marketplace", "system AI", "automation"], ["seven settings", "seven experience-center --gui", "seven store"]),
    ("forge", "Forge", "Developer and deployment universe", ["IDEs and editors", "containers", "Python/Rust/Go/Node stacks", "Git workflows", "local services", "AI-assisted development"], ["seven profile activate forge", "seven deploy panel"]),
    ("shield", "Shield", "Cybersecurity and trust universe", ["isolated lab", "network analysis", "security monitoring", "encryption routes", "vault posture", "authorized audits"], ["seven profile activate shield", "seven shield audit"]),
    ("baobab", "Baobab", "African cultural immersion universe", ["African language library", "cultural mapping", "kingdoms and memory", "education tools", "African content creation", "culture-aware AI"], ["seven profile activate baobab", "seven baobab"]),
    ("pulse", "Pulse", "Gaming and performance universe", ["Steam/Proton route", "performance optimization", "capture", "mods route", "streaming route", "controller comfort"], ["seven profile activate pulse", "seven pulse doctor"]),
    ("studio", "Studio", "Creation and media universe", ["video editing", "streaming", "graphic design", "animation", "audio production", "multimedia AI route"], ["seven profile activate studio"]),
    ("atlas", "Atlas", "Exploration and knowledge universe", ["advanced research", "maps", "technical documentation", "technology watch", "scientific discovery", "personal knowledge management"], ["seven profile activate atlas", "seven atlas"]),
]

universes = []
for key, title, role, capabilities, commands in universe_specs:
    profile = profiles.get(key, {})
    node = bridge_nodes.get(key, {})
    ready = bool(profile.get("state") == "OK" and node.get("ready", True))
    universes.append({
        "key": key,
        "title": title,
        "role": role,
        "ready": ready,
        "state": "OK" if ready else "PART",
        "active": bool(profile.get("active")),
        "profile_title": profile.get("title", title),
        "accent": profile.get("accent_color", ""),
        "workspace": profile.get("workspace", ""),
        "installed": profile.get("installed", 0),
        "total": profile.get("total", 0),
        "capabilities": capabilities,
        "commands": commands,
    })

mission_data = missions.get("missions", {}) if isinstance(missions.get("missions"), dict) else {}
mission_items = mission_data.get("items", []) if isinstance(mission_data.get("items"), list) else []
ready_universes = sum(1 for item in universes if item["ready"])
all_ready = bool(core["ready"] and ready_universes == len(universes))

print(json.dumps({
    "schema": "sevenos.universes.v1",
    "state": "ready" if all_ready else "attention",
    "score": round((ready_universes + (1 if core["ready"] else 0)) / 8 * 100),
    "core": core,
    "summary": {
        "universes": len(universes),
        "ready": ready_universes,
        "active": next((item["key"] for item in universes if item["active"]), "equinox"),
        "bridge_edges": len(bridge.get("edges", [])),
        "missions": len(mission_items),
        "mission_state": mission_data.get("bridge_state", "unknown"),
    },
    "universes": universes,
    "equation": "Core + Equinox + six specialized universes = SevenOS experience",
    "ai_model": {
        "name": "Equinox AI",
        "contract": "A local-first system intelligence that understands universes, proposes routes and asks before switching or changing system state.",
        "example": "Je veux créer un jeu vidéo sur l’histoire du Mali",
        "route": ["baobab", "atlas", "forge", "studio", "pulse", "shield"],
        "command": "seven intent \"créer un jeu vidéo sur l'histoire du Mali\"",
    },
    "commands": {
        "status": "seven universes",
        "doctor": "seven universes doctor",
        "missions": "seven missions",
        "switch": "seven profile activate <universe>",
        "bridge": "seven bridge graph",
    },
}, ensure_ascii=False, indent=2))
PY
}

json_cache_valid() {
  python -m json.tool "$1" >/dev/null 2>&1
}

cache_is_fresh() {
  local path="$1" ttl="$2" now mtime
  [[ "$REFRESH_CACHE" == 1 ]] && return 1
  [[ -s "$path" ]] || return 1
  json_cache_valid "$path" || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || printf 0)"
  [[ $(( now - mtime )) -lt "$ttl" ]]
}

write_json_cache() {
  local path="$1" tmp
  mkdir -p "$(dirname "$path")"
  tmp="$path.tmp.$$"
  cat >"$tmp"
  if json_cache_valid "$tmp"; then
    mv -f "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
}

cached_payload_json() {
  local data
  if cache_is_fresh "$UNIVERSES_CACHE" "$UNIVERSES_CACHE_TTL"; then
    cat "$UNIVERSES_CACHE"
    return 0
  fi
  data="$(payload_json)"
  printf '%s\n' "$data" | write_json_cache "$UNIVERSES_CACHE" || true
  printf '%s\n' "$data"
}

print_status() {
  PAYLOAD="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PAYLOAD"])
summary = data.get("summary", {})
print("SevenOS Universes")
print("=================")
print(f"State: {data.get('state')} · Score: {data.get('score')}%")
print(f"Active: {summary.get('active')} · Bridge: {summary.get('bridge_edges')} relation(s) · Missions: {summary.get('missions')}")
print()
core = data.get("core", {})
print(f"{'OK' if core.get('ready') else 'PART':<4} {core.get('title')}: {core.get('role')}")
for item in data.get("universes", []):
    marker = "OK" if item.get("ready") else "PART"
    active = " · actif" if item.get("active") else ""
    print(f"{marker:<4} {item.get('title')}: {item.get('role')}{active}")
    print(f"     {item.get('installed', 0)}/{item.get('total', 0)} package(s) · {', '.join(item.get('capabilities', [])[:3])}")
PY
}

print_plan() {
  PAYLOAD="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PAYLOAD"])
print("SevenOS Universe Plan")
print("=====================")
for item in data.get("universes", []):
    if not item.get("ready"):
        print(f"- {item.get('title')}: {item.get('commands', ['seven profile health'])[0]}")
if all(item.get("ready") for item in data.get("universes", [])) and data.get("core", {}).get("ready"):
    print("All universes are ready. Use `seven missions` to orchestrate them.")
PY
}

payload="$(cached_payload_json)"
case "$ACTION" in
  status|json)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then printf '%s\n' "$payload"; else print_status "$payload"; fi
    ;;
  plan)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then printf '%s\n' "$payload"; else print_plan "$payload"; fi
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then printf '%s\n' "$payload"; else print_status "$payload"; echo; print_plan "$payload"; fi
    PAYLOAD="$payload" python - <<'PY'
import json, os, sys
data = json.loads(os.environ["PAYLOAD"])
sys.exit(0 if data.get("state") == "ready" else 1)
PY
    ;;
esac
