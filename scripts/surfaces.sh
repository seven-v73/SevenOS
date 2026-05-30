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
REFRESH_CACHE=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    --refresh|refresh) REFRESH_CACHE=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown surfaces option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

SURFACES_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
SURFACES_CACHE="$SURFACES_CACHE_DIR/surfaces.json"
SURFACES_CACHE_TTL="${SEVENOS_SURFACES_CACHE_TTL:-300}"

cache_json_valid() {
  [[ -s "$SURFACES_CACHE" ]] || return 1
  python - "$SURFACES_CACHE" >/dev/null 2>&1 <<'PY'
import json
import sys
from pathlib import Path

try:
    with Path(sys.argv[1]).open(encoding="utf-8") as handle:
        json.load(handle)
except Exception:
    raise SystemExit(1)
PY
}

cache_fresh() {
  [[ "$REFRESH_CACHE" -eq 0 ]] || return 1
  cache_json_valid || return 1
  command -v stat >/dev/null 2>&1 || return 1
  local age
  age="$(( $(date +%s) - $(stat -c %Y "$SURFACES_CACHE" 2>/dev/null || printf 0) ))"
  [[ "$age" -le "$SURFACES_CACHE_TTL" ]]
}

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


def text(rel):
    try:
        return (root / rel).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def add_legacy(issues, key, path, detail, command, severity="medium"):
    issues.append({
        "key": key,
        "path": path,
        "severity": severity,
        "detail": detail,
        "command": command,
    })


legacy_issues = []
overview_text = text("bin/seven-overview")
if "rofi -show window" in overview_text and "seven-spotlight\" windows" not in overview_text and "seven-spotlight windows" not in overview_text:
    add_legacy(
        legacy_issues,
        "overview.windows.rofi",
        "bin/seven-overview",
        "Window overview still opens the raw Rofi window switcher instead of the native Spotlight window surface.",
        "route seven-overview windows through seven-spotlight windows",
        "high",
    )

waybar_text = text("hyprland/waybar/config.jsonc")
if '"on-click-right": "seven-help"' in waybar_text:
    add_legacy(
        legacy_issues,
        "waybar.help.legacy",
        "hyprland/waybar/config.jsonc",
        "Waybar still opens the old helper on right-click help.",
        "replace seven-help with seven-help-native",
        "high",
    )

waybar_action_text = text("bin/seven-waybar-action")
if "run_detached seven-help ;;" in waybar_action_text:
    add_legacy(
        legacy_issues,
        "waybar.action.help.legacy",
        "bin/seven-waybar-action",
        "Waybar contextual actions still route SevenOS help through the legacy helper.",
        "replace run_detached seven-help with seven-help-native",
        "high",
    )

settings_text = text("bin/seven-settings-native")
if '"seven-help")' in settings_text or '"seven-help",' in settings_text:
    add_legacy(
        legacy_issues,
        "settings.help.legacy",
        "bin/seven-settings-native",
        "Settings still exposes a button to the legacy helper instead of the premium manual.",
        "replace seven-help with seven-help-native for visible help actions",
        "medium",
    )

hypr_generated = text("hyprland/conf/sevenos-lua-generated.conf")
if "bind = $mod, H, exec, seven-help\n" in hypr_generated:
    add_legacy(
        legacy_issues,
        "hypr.help.legacy",
        "hyprland/conf/sevenos-lua-generated.conf",
        "Super+H still targets the legacy helper in generated Hyprland config.",
        "route Super+H to seven-help-native",
        "high",
    )

active_hypr = Path.home() / ".config/hypr/conf/sevenos-lua-generated.conf"
try:
    active_hypr_text = active_hypr.read_text(encoding="utf-8", errors="replace")
except OSError:
    active_hypr_text = ""
if "bind = $mod, H, exec, seven-help\n" in active_hypr_text:
    add_legacy(
        legacy_issues,
        "hypr.active.help.legacy",
        str(active_hypr),
        "The active Hyprland generated config still targets the legacy helper.",
        "sync generated config and reload Hyprland",
        "high",
    )

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
        "key": "identity",
        "title": "SevenOS Identity",
        "role": "Prism-first OS identity report",
        "command": "seven identity open",
        "native": "bin/seven-identity-native",
        "desktop": None,
        "actions": ["identity.open", "identity.experience"],
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
        "key": "mini-os-boundaries",
        "title": "Mini OS Boundaries",
        "role": "Baobab and Atlas role clarity surface",
        "command": "seven mini-boundaries --open",
        "native": "bin/seven-mini-boundaries-native",
        "desktop": "seven-hub/seven-mini-boundaries.desktop",
        "actions": ["mini.boundaries"],
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
        "key": "atlas-center",
        "title": "Atlas Explorer",
        "role": "documents, maps, OCR and research mini OS surface",
        "command": "seven atlas open",
        "native": "bin/seven-mini-os-center",
        "desktop": None,
        "actions": ["atlas.open", "atlas.status", "atlas.install"],
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
        "command": "seven-waybar-notifications menu",
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
        adaptive_ready = adaptive.get("state") in {"ready", "guided-preview"}
        alignment = adaptive.get("alignment") if isinstance(adaptive.get("alignment"), dict) else {}
        if not adaptive_ready and alignment.get("state") == "PART":
            adaptive_ready = True
        dynamic_ok = adaptive_ready and mask.get("state") == "masked"
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
legacy_blockers = [item for item in legacy_issues if item.get("severity") == "high"]
state = "legacy-screens-detected" if legacy_blockers else "productized" if score >= 90 else "usable" if score >= 75 else "fragmented"

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
        "legacy_screens": len(legacy_issues),
        "legacy_blockers": len(legacy_blockers),
    },
    "surfaces": surfaces,
    "legacy_screens": legacy_issues,
    "issues": [item for item in surfaces if item["state"] != "OK"],
    "next": legacy_issues[:6] if legacy_issues else [item for item in surfaces if item["state"] != "OK"][:6],
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
print(f"Legacy screens: {summary.get('legacy_screens', 0)} ({summary.get('legacy_blockers', 0)} blocker)")
print()
for item in data.get("surfaces", []):
    print(f"{item.get('state','MISS'):<4} {item.get('title')}")
    print(f"     {item.get('role')}")
    print(f"     command: {item.get('command')}")
if data.get("legacy_screens"):
    print()
    print("Legacy screen routes:")
    for item in data.get("legacy_screens", []):
        print(f"- {item.get('severity','medium').upper()} {item.get('key')}: {item.get('path')}")
        print(f"  {item.get('detail')}")
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
    if "detail" in item and "path" in item:
        print(f"- {item.get('key')}")
        print(f"  severity: {item.get('severity')}")
        print(f"  path: {item.get('path')}")
        print(f"  fix: {item.get('command')}")
        continue
    print(f"- {item.get('title')}")
    print(f"  state: {item.get('state')}")
    print(f"  native: {item.get('native')} ready={item.get('native_ready')}")
    print(f"  command: {item.get('command')}")
PY
}

if cache_fresh; then
  payload="$(cat "$SURFACES_CACHE")"
else
  payload="$(surfaces_json)"
  mkdir -p "$SURFACES_CACHE_DIR"
  tmp_cache="$(mktemp "$SURFACES_CACHE_DIR/surfaces.XXXXXX")"
  printf '%s\n' "$payload" >"$tmp_cache"
  if python -m json.tool "$tmp_cache" >/dev/null 2>&1; then
    mv "$tmp_cache" "$SURFACES_CACHE"
  else
    rm -f "$tmp_cache"
  fi
fi
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
    legacy_blockers="$(SURFACES_JSON="$payload" python - <<'PY'
import json, os
print((json.loads(os.environ["SURFACES_JSON"]).get("summary") or {}).get("legacy_blockers", 0))
PY
)"
    if [[ "$score" -ge 90 && "$legacy_blockers" -eq 0 ]]; then
      log_success "SevenOS public surfaces are productized."
      exit 0
    fi
    log_error "SevenOS public surfaces are not fully productized yet."
    exit 1
    ;;
esac
