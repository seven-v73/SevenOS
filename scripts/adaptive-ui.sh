#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Adaptive UI

Usage:
  seven adaptive [status|plan|doctor|json]
  ./scripts/adaptive-ui.sh [status|plan|doctor|json]

Adaptive UI is the product contract that connects active profile, shell,
Waybar, Hub actions and semantic context into one user-facing mode.
EOF
}

json_payload() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])

def command_json(command, fallback):
    result = subprocess.run(command, cwd=root, text=True, capture_output=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback

def file_ok(relative):
    return (root / relative).is_file() and (root / relative).stat().st_size > 0

def executable_ok(relative):
    path = root / relative
    return path.is_file() and os.access(path, os.X_OK)

profile = command_json([str(root / "bin/seven"), "profile", "current", "--json"], {})
shell = command_json([str(root / "scripts/shell.sh"), "status", "--json"], {})
context = command_json([str(root / "scripts/context.sh"), "status", "--json"], {})
actions = command_json([str(root / "scripts/actions.sh"), "--json"], {"actions": []})

action_ids = {item.get("id") for item in actions.get("actions", [])}
active_profile_key = profile.get("key") or profile.get("profile") or "unknown"
context_payload = context.get("primary_context") if isinstance(context.get("primary_context"), dict) else {}
context_profile = context_payload.get("profile") or context_payload.get("key") or "unknown"
aligned = (
    active_profile_key == "unknown"
    or context_profile == "unknown"
    or active_profile_key == context_profile
)
context_actions = context.get("actions", []) if isinstance(context.get("actions"), list) else []
has_switch_suggestion = any(item.get("key") == "profile.switch-suggested" for item in context_actions)
checks = [
    {
        "key": "active-profile",
        "state": "OK" if profile.get("key") or profile.get("profile") or profile.get("title") else "MISS",
        "detail": "Active profile exposes machine-readable mode state.",
        "command": "seven profile current --json",
    },
    {
        "key": "shell-contract",
        "state": "OK" if shell.get("state") in ("READY", "NATIVE_READY", "FOUNDATION") else "MISS",
        "detail": "Shell exposes production fallback and migration state.",
        "command": "seven shell status --json",
    },
    {
        "key": "waybar-profile",
        "state": "OK" if executable_ok("bin/seven-waybar-profile") and file_ok("hyprland/waybar/config.jsonc") else "MISS",
        "detail": "Waybar can show active profile state and launch profile controls.",
        "command": "seven-waybar-profile",
    },
    {
        "key": "hub-actions",
        "state": "OK" if {"profile.current", "profile.guide", "profile.activate.forge", "profile.activate.shield"}.issubset(action_ids) else "MISS",
        "detail": "Hub action registry exposes profile-aware workflows.",
        "command": "seven actions --json",
    },
    {
        "key": "semantic-context",
        "state": "OK" if context.get("schema") == "sevenos.context.v1" and context.get("primary_context") else "PART" if context.get("schema") else "MISS",
        "detail": "Context engine provides semantic mode signals for future adaptive defaults.",
        "command": "seven context status --json",
    },
    {
        "key": "profile-context-alignment",
        "state": "OK" if aligned or has_switch_suggestion else "PART",
        "detail": "Detected semantic context matches the active profile or exposes a clear profile switch suggestion.",
        "command": next((item.get("command") for item in context_actions if item.get("key") == "profile.switch-suggested"), "seven context emit --json"),
    },
    {
        "key": "native-surfaces",
        "state": "OK" if executable_ok("bin/seven-profile-center-native") and executable_ok("bin/seven-hub-native") else "MISS",
        "detail": "Native Hub/Profile Center surfaces can present adaptive controls.",
        "command": "seven hub-native status",
    },
]

score = sum(2 if item["state"] == "OK" else 1 if item["state"] == "PART" else 0 for item in checks)
max_score = len(checks) * 2
percent = round((score / max(max_score, 1)) * 100)
state = "ready" if percent >= 90 else "guided-preview" if percent >= 70 else "scaffold" if percent >= 45 else "concept"

next_actions = [
    {
        "key": item["key"],
        "title": f"Complete {item['key'].replace('-', ' ')}",
        "command": item["command"],
        "reason": item["detail"],
        "impact": "safe",
        "severity": "medium",
    }
    for item in checks
    if item["state"] != "OK"
]

print(json.dumps({
    "schema": "sevenos.adaptive-ui.v1",
    "state": state,
    "score": score,
    "max": max_score,
    "percent": percent,
    "active_profile": {
        "key": profile.get("key") or profile.get("profile") or "unknown",
        "title": profile.get("title") or profile.get("name") or profile.get("key") or "unknown",
    },
    "shell": shell.get("state", "unknown"),
    "context": context.get("primary_context", "unknown"),
    "alignment": {
        "active_profile": active_profile_key,
        "context_profile": context_profile,
        "state": "OK" if aligned or has_switch_suggestion else "PART",
        "switch_suggestion": next((item for item in context_actions if item.get("key") == "profile.switch-suggested"), None),
    },
    "checks": checks,
    "next": next_actions,
    "commands": {
        "status": "seven adaptive",
        "plan": "seven adaptive plan",
        "profile": "seven profile current",
        "hub": "seven hub",
    },
}, indent=2))
PY
}

status() {
  if [[ "${1:-}" == "--json" ]]; then
    json_payload
    return 0
  fi

  ADAPTIVE_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["ADAPTIVE_PAYLOAD"])
profile = data.get("active_profile", {})
print("SevenOS Adaptive UI")
print("===================")
print(f"State:   {data.get('state')}")
print(f"Score:   {data.get('percent')}%")
print(f"Profile: {profile.get('title')} ({profile.get('key')})")
print(f"Shell:   {data.get('shell')}")
print(f"Context: {data.get('context')}")
print()
print(f"{'Check':<18} {'State':<5} Detail")
print(f"{'-----':<18} {'-----':<5} ------")
for item in data.get("checks", []):
    print(f"{item.get('key',''):<18} {item.get('state',''):<5} {item.get('detail','')}")
PY
}

plan() {
  ADAPTIVE_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["ADAPTIVE_PAYLOAD"])
print("SevenOS Adaptive UI Plan")
print("========================")
items = data.get("next", [])
if not items:
    print("No open adaptive UI actions.")
else:
    for item in items:
        print(f"- {item.get('title')}")
        print(f"  {item.get('reason')}")
        print(f"  command: {item.get('command')}")
PY
}

doctor() {
  local failures=0

  printf 'SevenOS Adaptive UI Doctor\n'
  printf '==========================\n'
  for path in \
    "scripts/adaptive-ui.sh" \
    "scripts/context.sh" \
    "scripts/shell.sh" \
    "scripts/actions.sh" \
    "bin/seven-waybar-profile" \
    "bin/seven-profile-center-native" \
    "bin/seven-hub-native"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  json_payload >/dev/null
  if [[ "$failures" -gt 0 ]]; then
    log_error "Adaptive UI has $failures missing file(s)."
    return 1
  fi
  log_success "Adaptive UI contract is readable."
}

action="${1:-status}"
case "$action" in
  status) status ;;
  plan) plan ;;
  doctor) doctor ;;
  json|--json) json_payload ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown Adaptive UI action: $action"; usage; exit 1 ;;
esac
