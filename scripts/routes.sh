#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS user routes

Usage:
  seven routes [status|doctor|plan|json] [--json]
  ./scripts/routes.sh [status|doctor|plan|json] [--json]

This contract maps normal user intentions to SevenOS commands, actions and
surfaces. It is how SevenOS stays autonomous: users ask for a workflow, SevenOS
chooses the surface, and backend tools remain implementation details.
EOF
}

ACTION="status"
JSON_OUTPUT=0
REFRESH_CACHE="${SEVENOS_ROUTES_REFRESH:-0}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
ROUTES_CACHE="$CACHE_DIR/routes.json"
ROUTES_CACHE_TTL="${SEVENOS_ROUTES_CACHE_TTL:-300}"
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    --refresh|--no-cache) REFRESH_CACHE=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown routes option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "--json" || "$ACTION" == "--refresh" || "$ACTION" == "--no-cache" ]] && ACTION="status"
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1
ROUTES_CACHE="$CACHE_DIR/routes.json"

routes_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def executable(rel):
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


def run_json(parts, fallback, timeout=6):
    try:
        result = subprocess.run(
            [str(root / parts[0]), *parts[1:]],
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
            env={**os.environ, "SEVENOS_ROOT": str(root), "SEVENOS_DRY_RUN": "0"},
        )
    except Exception:
        return fallback
    if result.returncode != 0 or not result.stdout.strip():
        return fallback
    try:
        return json.loads(result.stdout)
    except Exception:
        return fallback


def command_entrypoint(command):
    try:
        head = shlex.split(command)[0]
    except Exception:
        return ""
    if head == "seven":
        return "bin/seven"
    if head.startswith("seven-"):
        return f"bin/{head}"
    if head.startswith("./"):
        return head[2:]
    return ""


actions = run_json(["scripts/actions.sh", "--json"], {"actions": []})
mask = run_json(["scripts/mask.sh", "json"], {})
dynamic = run_json(["scripts/adaptive-ui.sh", "json"], {})

action_ids = {item.get("id") for item in actions.get("actions", []) if isinstance(item, dict)}
surface_natives = {
    "hub": "bin/seven-hub-native",
    "settings": "bin/seven-settings-native",
    "spotlight": "bin/seven-spotlight-native",
    "launchpad": "bin/seven-launchpad-native",
    "files": "bin/seven-files-native",
    "store": "bin/seven-store-native",
    "reader": "bin/seven-reader-native",
    "terminal": "bin/seven-terminal-native",
    "profile-center": "bin/seven-profile-center-native",
    "mini-os-center": "bin/seven-mini-os-center",
    "mini-os-boundaries": "bin/seven-mini-boundaries-native",
    "quick-settings": "bin/seven-quick-settings-native",
    "shield-center": "bin/seven-shield-center-native",
    "atlas-center": "bin/seven-mini-os-center",
    "windows-bridge": "bin/seven-windows-assistant",
    "doctor": "bin/seven-doctor-native",
    "window-controls": "bin/seven-window-controls-native",
    "welcome": "bin/seven-welcome",
}

mask_ready_global = mask.get("state") == "masked" or executable("scripts/mask.sh")
dynamic_ready_global = dynamic.get("state") in {"ready", "guided-preview"} or executable("scripts/adaptive-ui.sh")

routes = [
    {
        "intent": "open-control-center",
        "label": "Open system control center",
        "surface": "hub",
        "action_id": "hub.open",
        "command": "seven hub",
        "backend": "native Hub, fallback command palette",
    },
    {
        "intent": "change-settings",
        "label": "Change system settings",
        "surface": "settings",
        "action_id": "settings.open",
        "command": "seven settings",
        "backend": "GTK settings, Hyprland/system config writers",
    },
    {
        "intent": "search-anything",
        "label": "Search apps, actions and files",
        "surface": "spotlight",
        "action_id": "spotlight.open",
        "command": "seven-spotlight",
        "backend": "actions registry, desktop index, local state",
    },
    {
        "intent": "open-app-grid",
        "label": "Open app grid",
        "surface": "launchpad",
        "action_id": "launchpad.open",
        "command": "seven-launchpad-native",
        "backend": "desktop files, profile app catalog",
    },
    {
        "intent": "manage-files",
        "label": "Browse and manage files",
        "surface": "files",
        "action_id": "files.open",
        "command": "seven files",
        "backend": "filesystem, profile workspaces",
    },
    {
        "intent": "install-app",
        "label": "Find and install software",
        "surface": "store",
        "action_id": "store.open",
        "command": "seven store",
        "backend": "pacman, Flatpak, AUR helpers",
    },
    {
        "intent": "read-document",
        "label": "Read documents",
        "surface": "reader",
        "action_id": "reader.open",
        "command": "seven reader",
        "backend": "PDF/EPUB/text renderers",
    },
    {
        "intent": "open-terminal",
        "label": "Open profile-aware terminal",
        "surface": "terminal",
        "action_id": "terminal.open",
        "command": "seven-terminal",
        "backend": "shell, profile runtime shims",
    },
    {
        "intent": "switch-mini-os",
        "label": "Switch mini OS",
        "surface": "profile-center",
        "action_id": "profile.current",
        "command": "seven-profile-center-native",
        "backend": "profiles catalog, runtime orchestrator",
    },
    {
        "intent": "compose-mini-os",
        "label": "Compose profile capabilities",
        "surface": "mini-os-center",
        "action_id": "runtime.status",
        "command": "seven-mini-os-center",
        "backend": "LAPA runtime, cgroups, profile manifests",
    },
    {
        "intent": "understand-baobab-atlas",
        "label": "Understand Baobab versus Atlas",
        "surface": "mini-os-boundaries",
        "action_id": "mini.boundaries",
        "command": "seven mini-boundaries --open",
        "backend": "Baobab/Atlas package and role boundary report",
    },
    {
        "intent": "control-network-audio",
        "label": "Control Wi-Fi, Bluetooth and sound",
        "surface": "quick-settings",
        "action_id": "quick.open",
        "command": "seven-quick-settings",
        "backend": "NetworkManager, BlueZ, PipeWire",
    },
    {
        "intent": "cyber-workspace",
        "label": "Open cybersecurity workspace",
        "surface": "shield-center",
        "action_id": "security.dashboard",
        "command": "seven shield dashboard",
        "backend": "Shield contracts, firejail, tools, labs",
    },
    {
        "intent": "atlas-workflow",
        "label": "Explore documents, maps and OCR",
        "surface": "atlas-center",
        "action_id": "atlas.open",
        "command": "seven atlas open",
        "backend": "Atlas requirements, documents, maps, OCR",
    },
    {
        "intent": "repair-system",
        "label": "Diagnose and repair SevenOS",
        "surface": "doctor",
        "action_id": "doctor.open",
        "command": "seven doctor open",
        "backend": "system checks, repair scripts, journalctl",
    },
    {
        "intent": "control-window",
        "label": "Tile, float or maximize windows",
        "surface": "window-controls",
        "action_id": "window.toggle-float",
        "command": "seven window",
        "backend": "Hyprland dispatch and window rules",
    },
    {
        "intent": "first-run",
        "label": "Finish first-run setup",
        "surface": "welcome",
        "action_id": "welcome.open",
        "command": "seven welcome",
        "backend": "welcome plan, profile/theme/setup contracts",
    },
]

for route in routes:
    action_ready = route["action_id"] in action_ids
    entrypoint = command_entrypoint(route["command"])
    entrypoint_ready = executable(entrypoint) if entrypoint else True
    surface_ready = executable(surface_natives.get(route["surface"], ""))
    mask_ready = mask_ready_global
    dynamic_ready = dynamic_ready_global
    if surface_ready and action_ready and entrypoint_ready and mask_ready and dynamic_ready:
        state = "OK"
    elif surface_ready and (action_ready or entrypoint_ready):
        state = "PART"
    else:
        state = "MISS"
    route["state"] = state
    route["surface_ready"] = surface_ready
    route["action_ready"] = action_ready
    route["entrypoint_ready"] = entrypoint_ready
    route["mask_ready"] = mask_ready
    route["dynamic_ready"] = dynamic_ready

ok = sum(1 for item in routes if item["state"] == "OK")
part = sum(1 for item in routes if item["state"] == "PART")
score = round((ok + part * 0.5) / max(len(routes), 1) * 100)
state = "routed" if score >= 90 else "partial-routes" if score >= 75 else "backend-leaking"

print(json.dumps({
    "schema": "sevenos.routes.v1",
    "root": str(root.resolve()),
    "state": state,
    "score": score,
    "rule": "User intent -> SevenOS route -> backend implementation.",
    "summary": {
        "routes": len(routes),
        "ok": ok,
        "partial": part,
        "missing": sum(1 for item in routes if item["state"] == "MISS"),
    },
    "routes": routes,
    "issues": [item for item in routes if item["state"] != "OK"],
    "next": [item for item in routes if item["state"] != "OK"][:6],
}, indent=2))
PY
}

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
  local path="$1" ttl="$2" now mtime
  [[ "$REFRESH_CACHE" == 1 ]] && return 1
  json_cache_valid "$path" || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || printf 0)"
  (( now - mtime < ttl ))
}

write_json_cache() {
  local path="$1" tmp
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

cached_routes_json() {
  local data
  if cache_is_fresh "$ROUTES_CACHE" "$ROUTES_CACHE_TTL"; then
    cat "$ROUTES_CACHE"
    return 0
  fi
  data="$(routes_json)"
  printf '%s\n' "$data" | write_json_cache "$ROUTES_CACHE" || true
  printf '%s\n' "$data"
}

print_human() {
  ROUTES_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["ROUTES_JSON"])
summary = data.get("summary", {})
print("SevenOS User Routes")
print("===================")
print(f"State:  {data.get('state')}")
print(f"Score:  {data.get('score')}%")
print(f"Routes: {summary.get('ok')}/{summary.get('routes')} OK, {summary.get('partial')} partial")
print()
for item in data.get("routes", []):
    print(f"{item.get('state','MISS'):<4} {item.get('label')}")
    print(f"     route: {item.get('command')}")
    print(f"     backend: {item.get('backend')}")
PY
}

print_plan() {
  ROUTES_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["ROUTES_JSON"])
print("SevenOS Routes Plan")
print("===================")
if not data.get("next"):
    print("No user route gaps.")
for item in data.get("next", []):
    print(f"- {item.get('label')}")
    print(f"  state: {item.get('state')}")
    print(f"  route: {item.get('command')}")
    print(f"  surface_ready={item.get('surface_ready')} action_ready={item.get('action_ready')} entrypoint_ready={item.get('entrypoint_ready')}")
PY
}

payload="$(cached_routes_json)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
  exit 0
fi

case "$ACTION" in
  status) print_human "$payload" ;;
  plan) print_plan "$payload" ;;
  doctor)
    print_human "$payload"
    score="$(ROUTES_JSON="$payload" python - <<'PY'
import json, os
print(json.loads(os.environ["ROUTES_JSON"]).get("score", 0))
PY
)"
    if [[ "$score" -ge 90 ]]; then
      log_success "SevenOS user routes are coherent."
      exit 0
    fi
    log_error "SevenOS user routes still expose too many backend paths."
    exit 1
    ;;
esac
