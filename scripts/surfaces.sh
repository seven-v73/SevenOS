#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS public surfaces

Usage:
  seven surfaces [status|doctor|plan|json] [--json]
  ./scripts/surfaces.sh [status|doctor|plan|json] [--json]

This is the product contract for SevenOS user-facing surfaces. It checks
whether normal workflows have SevenOS-native entrypoints before falling back to
backend tools, terminal commands or raw Linux configuration.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown surfaces option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

surfaces_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def executable(rel):
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


def exists(rel):
    return (root / rel).exists()


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


actions = run_json(["scripts/actions.sh", "--json"], {"actions": []})
action_ids = {item.get("id") for item in actions.get("actions", []) if isinstance(item, dict)}
mask = run_json(["scripts/mask.sh", "json"], {})
adaptive = run_json(["scripts/adaptive-ui.sh", "json"], {})

surfaces = [
    {
        "key": "hub",
        "title": "Seven Hub",
        "role": "main control center",
        "command": "seven hub",
        "native": "bin/seven-hub-native",
        "desktop": "seven-hub/seven-hub-native.desktop",
        "actions": ["hub.open", "hub.status", "hub.plan"],
        "dynamic": True,
    },
    {
        "key": "settings",
        "title": "SevenOS Settings",
        "role": "normal-user system preferences",
        "command": "seven settings",
        "native": "bin/seven-settings-native",
        "desktop": "seven-hub/seven-settings.desktop",
        "actions": ["settings.open"],
        "dynamic": True,
    },
    {
        "key": "launchpad",
        "title": "SevenOS Launchpad",
        "role": "profile-aware app grid",
        "command": "seven-launchpad-native",
        "native": "bin/seven-launchpad-native",
        "desktop": None,
        "actions": ["launchpad.open", "apps.open"],
        "dynamic": True,
    },
    {
        "key": "spotlight",
        "title": "SevenOS Spotlight",
        "role": "global search and action surface",
        "command": "seven-spotlight",
        "native": "bin/seven-spotlight-native",
        "desktop": None,
        "actions": ["spotlight.open"],
        "dynamic": True,
    },
    {
        "key": "quick-settings",
        "title": "SevenOS Quick Settings",
        "role": "Wi-Fi, Bluetooth, sound and system toggles",
        "command": "seven-quick-settings",
        "native": "bin/seven-quick-settings-native",
        "desktop": None,
        "actions": ["notifications.open", "quick.open"],
        "dynamic": True,
    },
    {
        "key": "files",
        "title": "Seven Files",
        "role": "file manager and profile workspace browser",
        "command": "seven files",
        "native": "bin/seven-files-native",
        "desktop": "seven-hub/seven-files.desktop",
        "actions": ["files.open", "files.profile"],
        "dynamic": True,
    },
    {
        "key": "store",
        "title": "SevenStore",
        "role": "software discovery and package facade",
        "command": "seven store",
        "native": "bin/seven-store-native",
        "desktop": "seven-hub/seven-store.desktop",
        "actions": ["store.open", "store.doctor"],
        "dynamic": True,
    },
    {
        "key": "reader",
        "title": "Seven Reader",
        "role": "document reading and study surface",
        "command": "seven reader",
        "native": "bin/seven-reader-native",
        "desktop": "seven-hub/seven-reader.desktop",
        "actions": ["reader.open", "reader.status"],
        "dynamic": True,
    },
    {
        "key": "terminal",
        "title": "Seven Terminal",
        "role": "mini OS aware terminal",
        "command": "seven-terminal",
        "native": "bin/seven-terminal-native",
        "desktop": "seven-hub/seven-terminal.desktop",
        "actions": ["terminal.open", "terminal.palette"],
        "dynamic": True,
    },
    {
        "key": "profile-center",
        "title": "Profile Center",
        "role": "mini OS selection and runtime composition",
        "command": "seven-profile-center-native",
        "native": "bin/seven-profile-center-native",
        "desktop": None,
        "actions": ["profile.current", "profile.activate.equinox"],
        "dynamic": True,
    },
    {
        "key": "mini-os-center",
        "title": "Mini OS Center",
        "role": "specialized profile cockpit",
        "command": "seven-mini-os-center",
        "native": "bin/seven-mini-os-center",
        "desktop": None,
        "actions": ["profile.status", "runtime.status"],
        "dynamic": True,
    },
    {
        "key": "shield-center",
        "title": "Shield Center",
        "role": "cybersecurity cockpit",
        "command": "seven shield dashboard",
        "native": "bin/seven-shield-center-native",
        "desktop": None,
        "actions": ["security.dashboard", "security.scope"],
        "dynamic": True,
    },
    {
        "key": "windows-bridge",
        "title": "Windows Bridge",
        "role": "VM/Wine/Bottles compatibility surface",
        "command": "seven windows status",
        "native": "bin/seven-windows-assistant",
        "desktop": None,
        "actions": ["windows.status", "windows.enter"],
        "dynamic": True,
    },
    {
        "key": "doctor",
        "title": "Seven Doctor",
        "role": "guided health and repair",
        "command": "seven doctor open",
        "native": "bin/seven-doctor-native",
        "desktop": None,
        "actions": ["doctor.run", "doctor.open"],
        "dynamic": False,
    },
    {
        "key": "notifications",
        "title": "Notification Center",
        "role": "notifications and quiet mode",
        "command": "seven-shell-panel notifications",
        "native": "bin/seven-notification-center-native",
        "desktop": None,
        "actions": ["quick.open"],
        "dynamic": False,
    },
    {
        "key": "window-controls",
        "title": "Seven Window Controls",
        "role": "floating, tiling and smart window controls",
        "command": "seven window",
        "native": "bin/seven-window-controls-native",
        "desktop": None,
        "actions": ["window.toggle-float", "window.smart-maximize"],
        "dynamic": True,
    },
    {
        "key": "welcome",
        "title": "SevenOS Welcome",
        "role": "first-run onboarding",
        "command": "seven welcome",
        "native": "bin/seven-welcome",
        "desktop": None,
        "actions": ["welcome.open", "welcome.status"],
        "dynamic": False,
    },
]

for item in surfaces:
    action_match = any(action in action_ids for action in item["actions"])
    native_ok = executable(item["native"])
    desktop = item.get("desktop")
    desktop_ok = True if desktop is None else exists(desktop)
    dynamic_ok = True
    if item.get("dynamic"):
        dynamic_ok = adaptive.get("state") in {"ready", "guided-preview"} and mask.get("state") == "masked"
    if native_ok and desktop_ok and action_match and dynamic_ok:
        state = "OK"
    elif native_ok and (action_match or desktop_ok):
        state = "PART"
    else:
        state = "MISS"
    item["state"] = state
    item["native_ready"] = native_ok
    item["desktop_ready"] = desktop_ok
    item["action_ready"] = action_match
    item["dynamic_ready"] = dynamic_ok

ok = sum(1 for item in surfaces if item["state"] == "OK")
part = sum(1 for item in surfaces if item["state"] == "PART")
score = round((ok + part * 0.5) / max(len(surfaces), 1) * 100)
state = "productized" if score >= 90 else "usable" if score >= 75 else "fragmented"

print(json.dumps({
    "schema": "sevenos.surfaces.v1",
    "state": state,
    "score": score,
    "summary": {
        "surfaces": len(surfaces),
        "ok": ok,
        "partial": part,
        "missing": sum(1 for item in surfaces if item["state"] == "MISS"),
        "native": sum(1 for item in surfaces if item.get("native_ready")),
        "dynamic": sum(1 for item in surfaces if item.get("dynamic_ready")),
    },
    "surfaces": surfaces,
    "issues": [item for item in surfaces if item["state"] != "OK"],
    "next": [item for item in surfaces if item["state"] != "OK"][:6],
}, indent=2))
PY
}

print_human() {
  SURFACES_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["SURFACES_JSON"])
summary = data.get("summary", {})
print("SevenOS Public Surfaces")
print("=======================")
print(f"State:    {data.get('state')}")
print(f"Score:    {data.get('score')}%")
print(f"Surfaces: {summary.get('ok')}/{summary.get('surfaces')} OK, {summary.get('partial')} partial")
print()
for item in data.get("surfaces", []):
    print(f"{item.get('state','MISS'):<4} {item.get('title')}")
    print(f"     {item.get('role')}")
    print(f"     command: {item.get('command')}")
PY
}

print_plan() {
  SURFACES_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["SURFACES_JSON"])
print("SevenOS Surfaces Plan")
print("=====================")
if not data.get("next"):
    print("No public surface gaps.")
for item in data.get("next", []):
    print(f"- {item.get('title')}")
    print(f"  state: {item.get('state')}")
    print(f"  native: {item.get('native')} ready={item.get('native_ready')}")
    print(f"  command: {item.get('command')}")
PY
}

payload="$(surfaces_json)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
  exit 0
fi

case "$ACTION" in
  status) print_human "$payload" ;;
  plan) print_plan "$payload" ;;
  doctor)
    print_human "$payload"
    score="$(SURFACES_JSON="$payload" python - <<'PY'
import json, os
print(json.loads(os.environ["SURFACES_JSON"]).get("score", 0))
PY
)"
    if [[ "$score" -ge 90 ]]; then
      log_success "SevenOS public surfaces are productized."
      exit 0
    fi
    log_error "SevenOS public surfaces are not fully productized yet."
    exit 1
    ;;
esac
