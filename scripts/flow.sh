#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenFlow Preview

Usage:
  seven flow [status|recipes|doctor|json]

SevenFlow turns SevenOS actions into explicit, inspectable automation recipes.
It only previews recipes today; no automatic action runs without confirmation.
EOF
}

payload_json() {
  ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])

def run_json(command, fallback):
    result = subprocess.run(command, cwd=root, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback

actions = run_json([str(root / "scripts" / "actions.sh"), "--json"], {"actions": []}).get("actions", [])
action_by_id = {item.get("id"): item for item in actions if isinstance(item, dict) and item.get("id")}
safe_actions = {key: item for key, item in action_by_id.items() if item.get("impact") == "safe"}

recipes = [
    {
        "key": "morning-readiness",
        "title": "Morning Readiness",
        "trigger": "manual or session start",
        "state": "ready",
        "steps": ["daily.status", "insights.open", "events.open"],
    },
    {
        "key": "creative-session",
        "title": "Creative Session",
        "trigger": "profile switch",
        "state": "ready" if "profile.activate.studio" in action_by_id else "partial",
        "steps": ["profile.activate.studio", "profile.apps", "files.open"],
    },
    {
        "key": "deploy-check",
        "title": "Deploy Check",
        "trigger": "project folder",
        "state": "ready",
        "steps": ["server.status", "deploy.plan", "store.modules"],
    },
    {
        "key": "trust-check",
        "title": "Trust Check",
        "trigger": "weekly",
        "state": "ready",
        "steps": ["security.status", "security.scope", "security.plan"],
    },
]

for recipe in recipes:
    recipe["resolved_steps"] = [
        {
            "id": step,
            "title": action_by_id.get(step, {}).get("title", step),
            "command": action_by_id.get(step, {}).get("command", ""),
            "impact": action_by_id.get(step, {}).get("impact", "safe"),
        }
        for step in recipe["steps"]
    ]

payload = {
    "schema": "sevenos.flow.v1",
    "state": "preview",
    "writer": "scripts/flow.sh",
    "summary": {
        "recipes": len(recipes),
        "ready": sum(1 for item in recipes if item["state"] == "ready"),
        "safe_actions": len(safe_actions),
    },
    "recipes": recipes,
    "policy": {
        "auto_run": False,
        "requires_confirmation": True,
        "allowed_impacts": ["safe", "changes"],
    },
}
print(json.dumps(payload, indent=2))
PY
}

status() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
s = d["summary"]
print("SevenFlow Preview")
print("=================")
print(f"Recipes:     {s['ready']}/{s['recipes']} ready")
print(f"Safe actions:{s['safe_actions']}")
print("Policy:      confirmation required")
print()
for item in d["recipes"]:
    print(f"  - {item['key']:<18} {item['state']:<7} {item['title']}")
PY
}

recipes() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
print("SevenFlow Recipes")
print("=================")
for recipe in d["recipes"]:
    print(f"{recipe['title']} ({recipe['state']})")
    print(f"trigger: {recipe['trigger']}")
    for step in recipe["resolved_steps"]:
        print(f"  - {step['title']}: {step['command'] or step['id']}")
    print()
PY
}

doctor() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
print("SevenFlow Doctor")
print("================")
print(f"[OK] recipes: {d['summary']['recipes']}")
print(f"[OK] safe actions: {d['summary']['safe_actions']}")
if d["summary"]["ready"] == 0:
    raise SystemExit(1)
PY
}

action="${1:-status}"
case "$action" in
  status) status ;;
  recipes|plan) recipes ;;
  doctor) doctor ;;
  json|--json) payload_json ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown flow action: $action"; usage; exit 1 ;;
esac
