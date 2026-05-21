#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Hub product surface

Usage:
  seven hub [open|status|plan|doctor|json]
  ./scripts/hub.sh [status|plan|doctor|json]

Actions:
  status  Show Hub readiness as a product surface
  plan    Show missing Hub productization work
  doctor  Validate the Hub readiness contract
  json    Print machine-readable Hub readiness
EOF
}

hub_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def run_json(parts, timeout=8):
    try:
        result = subprocess.run(
            [str(root / parts[0]), *parts[1:]],
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def exists(rel):
    return (root / rel).exists()


def executable(rel):
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


actions_payload = run_json(["scripts/actions.sh", "--json"], timeout=4) or {"actions": []}
action_ids = {
    item.get("id")
    for item in actions_payload.get("actions", [])
    if isinstance(item, dict)
}
required_actions = {
    "autonomy.status",
    "platform.status",
    "hub.open",
    "hub.status",
    "hub.plan",
    "settings.open",
    "control.plan",
    "ecosystem.maturity",
    "ai.focus",
    "installer.release",
    "adaptive.status",
}
missing_actions = sorted(required_actions - action_ids)

state_contract = run_json(["scripts/state.sh", "--json"], timeout=12) or {}
adaptive_contract = run_json(["scripts/adaptive-ui.sh", "json"], timeout=4) or {}
contracts = {
    "state": bool(state_contract),
    "actions": bool(actions_payload.get("actions")),
    "ecosystem": isinstance(state_contract.get("ecosystem"), dict),
    "installer": isinstance(state_contract.get("installer"), dict),
    "adaptive": isinstance(state_contract.get("adaptive"), dict) or bool(adaptive_contract),
    "autonomy": isinstance(state_contract.get("autonomy"), dict),
    "platform": isinstance(state_contract.get("platform"), dict),
    "channel": isinstance(state_contract.get("channel"), dict),
}
contracts["state_runtime_manifest"] = isinstance(state_contract.get("profile_runtime_manifest"), dict)
contracts["state_runtime_manifests"] = isinstance(state_contract.get("profile_runtime_manifests"), dict)
missing_contracts = sorted(name for name, ok in contracts.items() if not ok)

checks = [
    {
        "key": "native-hub",
        "state": "OK" if executable("bin/seven-hub-native") else "MISS",
        "detail": "GTK/libadwaita native Hub entrypoint",
        "command": "seven hub-native status",
    },
    {
        "key": "fallback-hub",
        "state": "OK" if executable("seven-hub/bin/seven-hub") else "MISS",
        "detail": "Rofi/native fallback launcher",
        "command": "seven hub",
    },
    {
        "key": "control-center",
        "state": "OK" if executable("seven-hub/bin/seven-control-center") else "MISS",
        "detail": "local Control Center fallback surface",
        "command": "seven control",
    },
    {
        "key": "desktop-entry",
        "state": "OK" if exists("seven-hub/seven-hub.desktop") and exists("seven-hub/seven-hub-native.desktop") else "MISS",
        "detail": "desktop integration for graphical launchers",
        "command": "./install.sh theme",
    },
    {
        "key": "settings-route",
        "state": "OK" if executable("bin/seven-settings-native") and exists("seven-hub/seven-settings.desktop") else "MISS",
        "detail": "normal settings paths land on native SevenOS surfaces",
        "command": "seven settings",
    },
    {
        "key": "action-registry",
        "state": "OK" if not missing_actions else "PART",
        "detail": "shared Hub actions include product focus and system guidance",
        "missing": missing_actions,
        "command": "seven actions --json",
    },
    {
        "key": "machine-contracts",
        "state": "OK" if not missing_contracts else "PART",
        "detail": "Hub dashboard data is available without scraping terminal text",
        "missing": missing_contracts,
        "command": "seven hub status --json",
    },
    {
        "key": "control-plane-route",
        "state": "OK" if executable("scripts/control-plane.sh") else "MISS",
        "detail": "Hub can hand off prioritized repairs to the Control Plane",
        "command": "seven control",
    },
    {
        "key": "native-action-runner",
        "state": "OK" if executable("bin/seven-action-runner") else "MISS",
        "detail": "Hub actions can run with native logs and notifications instead of terminal windows",
        "command": "seven-action-runner --dry-run -- seven status",
    },
]

ok_count = sum(1 for item in checks if item["state"] == "OK")
part_count = sum(1 for item in checks if item["state"] == "PART")
score = round((ok_count + part_count * 0.5) / max(len(checks), 1) * 100)
if score >= 95:
    level = "active"
elif score >= 85:
    level = "product-preview"
elif score >= 70:
    level = "guided-preview"
else:
    level = "scaffold"

next_actions = []
for item in checks:
    if item["state"] != "OK":
        next_actions.append({
            "title": item["detail"],
            "check": item["key"],
            "command": item.get("command", "seven hub plan"),
            "impact": "safe" if item["key"] != "desktop-entry" else "changes",
            "missing": item.get("missing", []),
        })

print(json.dumps({
    "schema": "sevenos.hub.v1",
    "level": level,
    "score": score,
    "summary": {
        "checks": len(checks),
        "ok": ok_count,
        "partial": part_count,
        "missing": sum(1 for item in checks if item["state"] == "MISS"),
        "native": executable("bin/seven-hub-native"),
        "fallback": executable("seven-hub/bin/seven-hub"),
        "control_center": executable("seven-hub/bin/seven-control-center"),
    },
    "checks": checks,
    "contracts": contracts,
    "required_actions": sorted(required_actions),
    "next_actions": next_actions,
}, indent=2))
PY
}

status() {
  local payload
  payload="$(hub_json)"
  HUB_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["HUB_JSON"])
summary = data.get("summary", {})

print("SevenOS Hub Product Surface")
print("===========================")
print(f"Level: {data.get('level', 'unknown')}")
print(f"Score: {data.get('score', 0)}%")
print(f"Checks: {summary.get('ok', 0)}/{summary.get('checks', 0)} OK, {summary.get('partial', 0)} partial")
print(f"Native Hub: {'OK' if summary.get('native') else 'MISS'}")
print(f"Control Center: {'OK' if summary.get('control_center') else 'MISS'}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state', 'MISS'):<4} {item.get('key', ''):<18} {item.get('detail', '')}")
PY
}

plan() {
  local payload
  payload="$(hub_json)"
  HUB_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["HUB_JSON"])
actions = data.get("next_actions", [])

print("SevenOS Hub Product Plan")
print("========================")
print(f"Level: {data.get('level', 'unknown')} ({data.get('score', 0)}%)")
print()
if not actions:
    print("No hard Hub product blockers.")
else:
    print("Next actions:")
    for item in actions:
        print(f"- {item.get('title', item.get('check', 'Hub check'))}")
        print(f"  command: {item.get('command', 'seven hub plan')}")
        missing = item.get("missing") or []
        if missing:
            print(f"  missing: {', '.join(missing)}")
PY
}

doctor() {
  local payload level score
  payload="$(hub_json)"
  level="$(python -c 'import json,sys; print(json.load(sys.stdin).get("level","unknown"))' <<<"$payload")"
  score="$(python -c 'import json,sys; print(json.load(sys.stdin).get("score",0))' <<<"$payload")"

  HUB_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["HUB_JSON"])
summary = data.get("summary", {})
print("SevenOS Hub Product Surface")
print("===========================")
print(f"Level: {data.get('level', 'unknown')}")
print(f"Score: {data.get('score', 0)}%")
print(f"Checks: {summary.get('ok', 0)}/{summary.get('checks', 0)} OK, {summary.get('partial', 0)} partial")
PY
  if [[ "$level" == "scaffold" ]]; then
    log_error "Seven Hub product contract is below guided-preview (${score}%)."
    return 1
  fi
  log_success "Seven Hub product contract is coherent (${level}, ${score}%)."
}

main() {
  local action="${1:-status}"
  case "$action" in
    status) status ;;
    plan) plan ;;
    doctor) doctor ;;
    json|--json) hub_json ;;
    -h|--help|help) usage ;;
    *)
      log_error "Unknown Hub action: $action"
      usage
      exit 1
      ;;
  esac
}

main "$@"
