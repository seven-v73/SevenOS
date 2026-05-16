#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
APPLY=0
YES=0

usage() {
  cat <<'EOF'
SevenOS Daily Driver Gate

Usage:
  seven daily
  seven daily --json
  seven daily plan
  seven daily apply --yes

Purpose:
  Decide whether this SevenOS installation is safe and complete enough for a
  primary PC. The gate focuses on security, profiles, Windows Mode, server,
  installer foundation and rollback hygiene.
EOF
}

shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    --apply) APPLY=1 ;;
    --yes) YES=1; export SEVENOS_YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown daily driver option: $arg"; usage; exit 1 ;;
  esac
done

if [[ "$ACTION" == "--json" || "$ACTION" == "json" ]]; then
  ACTION="status"
  JSON_OUTPUT=1
fi

if [[ "$ACTION" == "apply" ]]; then
  APPLY=1
fi

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
        data = dict(fallback)
        data["error"] = result.stderr.strip() or result.stdout.strip()
        return data
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        data = dict(fallback)
        data["error"] = f"invalid json: {exc}"
        return data


readiness = command_json([str(root / "bin/seven"), "readiness", "--json"], {"percent": 0, "categories": {}})
shield = command_json([str(root / "bin/seven-daemon"), "shield", "--json"], {"percent": 0, "posture": "unknown"})
profiles = command_json([str(root / "bin/seven-daemon"), "profiles", "--json"], {"profiles": []})
windows = command_json([str(root / "bin/seven-daemon"), "windows", "--json"], {"ready": False, "mode": "unknown"})
installer = command_json([str(root / "bin/seven-daemon"), "installer", "--json"], {"ready": False, "mode": "unknown", "tooling": []})
server = command_json([str(root / "bin/seven-daemon"), "server", "--json"], {"dependencies": [], "service": {"state": "MISS"}})
core = command_json([str(root / "bin/seven-daemon"), "core", "--json"], {"state": "unknown", "daemon": {}})

categories = readiness.get("categories", {})
profile_items = profiles.get("profiles", [])
profile_by_key = {item.get("key"): item for item in profile_items}

def category_percent(name):
    item = categories.get(name) or {}
    return int(item.get("percent", 0) or 0)


def profile_percent(key):
    item = profile_by_key.get(key) or {}
    total = int(item.get("total", 0) or 0)
    installed = int(item.get("installed", 0) or 0)
    return 0 if total <= 0 else round(installed * 100 / total)


def profile_ready(key):
    item = profile_by_key.get(key) or {}
    return item.get("state") == "OK" and item.get("bootstrap_state") == "OK"


tooling = {item.get("key"): item.get("state") for item in installer.get("tooling", [])}
server_deps = {item.get("key"): item.get("state") for item in server.get("dependencies", [])}
server_service = (server.get("service") or {}).get("state", "MISS")
server_runtime_ready = bool(server.get("runtime_ready")) or (server_service == "RUN" and server_deps.get("jq") == "OK" and server_deps.get("seven-deploy") == "OK")
server_stack_ready = bool(server.get("deployment_stack_ready")) or all(server_deps.get(key) == "OK" for key in ("go", "podman", "caddy", "jq", "seven-deploy"))
core_daemon = (core.get("daemon") or {}).get("service", "MISS")
core_observer = (core.get("daemon") or {}).get("context_observer_service", "MISS")

gates = [
    {
        "key": "readiness",
        "title": "Overall readiness",
        "state": "PASS" if int(readiness.get("percent", 0) or 0) >= 90 else "BLOCK",
        "actual": int(readiness.get("percent", 0) or 0),
        "target": 90,
        "command": "seven improve daily --apply --yes",
        "reason": "A primary PC should not run below 90% overall readiness.",
    },
    {
        "key": "security",
        "title": "Security baseline",
        "state": "PASS" if category_percent("Security") >= 70 and int(shield.get("percent", 0) or 0) >= 70 else "BLOCK",
        "actual": min(category_percent("Security"), int(shield.get("percent", 0) or 0)),
        "target": 70,
        "command": "seven improve security --apply --yes && seven profile install shield --yes",
        "reason": "Daily use needs firewall, sandboxing, Shield workspace and audit tools.",
    },
    {
        "key": "profiles",
        "title": "Daily role profiles",
        "state": "PASS" if all(profile_percent(key) >= 70 for key in ("baobab", "forge", "shield", "studio", "windows", "horizon")) else "BLOCK",
        "actual": min(profile_percent(key) for key in ("baobab", "forge", "shield", "studio", "windows", "horizon")),
        "target": 70,
        "command": "seven improve target --apply --yes",
        "reason": "SevenOS should expose real workspaces, not decorative profile names.",
    },
    {
        "key": "windows",
        "title": "Windows Mode",
        "state": "PASS" if windows.get("ready") else "WARN" if windows.get("vm_ready") else "BLOCK",
        "actual": windows.get("mode", "unknown"),
        "target": "complete",
        "command": "seven improve compatibility --apply --yes",
        "reason": "A main PC often needs Wine/Bottles/Lutris and a guided KVM path.",
    },
    {
        "key": "server",
        "title": "Seven Server local backend",
        "state": "PASS" if server_runtime_ready else "WARN",
        "actual": server_service,
        "target": "RUN",
        "command": "seven improve deployment --apply --yes",
        "reason": "Seven Hub and future Shell need a reliable local backend. Go/Podman/Caddy are deployment-stack improvements, not proof that the API is absent.",
    },
    {
        "key": "deployment-stack",
        "title": "Deployment stack",
        "state": "PASS" if server_stack_ready else "WARN",
        "actual": ", ".join(f"{key}={server_deps.get(key, 'MISS')}" for key in ("go", "podman", "caddy")),
        "target": "go=OK, podman=OK, caddy=OK",
        "command": "seven improve deployment --apply --yes",
        "reason": "Horizon needs Go, Podman and Caddy for the personal cloud/deployment workflow.",
    },
    {
        "key": "installer",
        "title": "Installer foundation",
        "state": "PASS" if installer.get("ready") or tooling.get("archinstall") == "OK" else "WARN",
        "actual": installer.get("mode", "unknown"),
        "target": "tui-ready",
        "command": "seven installer install",
        "reason": "A daily OS needs a recovery/reinstall path even before Calamares is complete.",
    },
    {
        "key": "core-services",
        "title": "Seven Core services",
        "state": "PASS" if core_daemon in ("RUN", "READY") and core_observer in ("RUN", "READY") else "WARN",
        "actual": f"daemon={core_daemon}, observer={core_observer}",
        "target": "READY",
        "command": "seven core install-service && seven core install-observer",
        "reason": "The OS layer should run as supervised services, not ad-hoc commands.",
    },
]

blockers = [item for item in gates if item["state"] == "BLOCK"]
warnings = [item for item in gates if item["state"] == "WARN"]
decision = "ready" if not blockers and not warnings else "usable-with-caution" if not blockers else "not-ready"

actions = [
    {
        "key": "backup",
        "title": "Back up protected SevenOS user state",
        "command": "seven migrate backup",
        "impact": "safe",
    },
    {
        "key": "security",
        "title": "Consolidate Shield/security",
        "command": "seven improve security --apply --yes && seven profile install shield --yes",
        "impact": "packages",
    },
    {
        "key": "profiles",
        "title": "Complete daily role profiles",
        "command": "seven improve target --apply --yes",
        "impact": "packages",
    },
    {
        "key": "windows",
        "title": "Complete Windows Mode bridge",
        "command": "seven improve compatibility --apply --yes",
        "impact": "packages",
    },
    {
        "key": "server",
        "title": "Install local backend and deployment layer",
        "command": "seven improve deployment --apply --yes",
        "impact": "packages",
    },
    {
        "key": "installer",
        "title": "Install installer automation foundation",
        "command": "seven installer install",
        "impact": "packages",
    },
    {
        "key": "core",
        "title": "Install Seven Core user services",
        "command": "seven core install-service && seven core install-observer",
        "impact": "changes",
    },
    {
        "key": "verify",
        "title": "Re-run the daily driver gate",
        "command": "seven daily",
        "impact": "safe",
    },
]

print(json.dumps({
    "schema": "sevenos.daily-driver.v1",
    "decision": decision,
    "summary": {
        "readiness": int(readiness.get("percent", 0) or 0),
        "security": category_percent("Security"),
        "shield": int(shield.get("percent", 0) or 0),
        "target_use": category_percent("Target Use"),
        "compatibility": category_percent("Software Compatibility"),
        "deployment": category_percent("Deployment"),
        "windows_mode": windows.get("mode", "unknown"),
        "server": server_service,
        "installer": installer.get("mode", "unknown"),
    },
    "gates": gates,
    "actions": actions,
    "blockers": blockers,
    "warnings": warnings,
}, indent=2))
PY
}

human_status() {
  local payload
  payload="$(json_payload)"
  DAILY_PAYLOAD="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["DAILY_PAYLOAD"])
summary = data["summary"]
print("SevenOS Daily Driver Gate")
print("=========================")
print(f"Decision:      {data['decision']}")
print(f"Readiness:     {summary['readiness']}%")
print(f"Security:      {summary['security']}%")
print(f"Shield:        {summary['shield']}%")
print(f"Target Use:    {summary['target_use']}%")
print(f"Compatibility: {summary['compatibility']}%")
print(f"Deployment:    {summary['deployment']}%")
print(f"Windows Mode:  {summary['windows_mode']}")
print(f"Server:        {summary['server']}")
print(f"Installer:     {summary['installer']}")
print()
print("Gates:")
for item in data["gates"]:
    print(f"  {item['state']:<5} {item['title']:<28} {item['actual']} -> {item['target']}")
print()
if data["blockers"]:
    print("Blocking actions:")
    for item in data["blockers"]:
        print(f"  - {item['command']}")
else:
    print("No hard blockers.")
if data["warnings"]:
    print()
    print("Warnings:")
    for item in data["warnings"]:
        print(f"  - {item['title']}: {item['command']}")
print()
print("Recommended command:")
print("  seven improve daily --apply --yes")
PY
}

apply_daily() {
  if ! is_dry_run && ! sudo -n true 2>/dev/null; then
    log_error "Daily driver consolidation needs an active sudo session."
    log_info "Run 'sudo -v' first, then retry: seven daily apply --yes"
    exit 1
  fi

  local args=(daily --apply)
  [[ "$YES" -eq 1 ]] && args+=(--yes)
  "$ROOT_DIR/scripts/improve.sh" "${args[@]}"
}

case "$ACTION" in
  status|plan)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      json_payload
    else
      human_status
    fi
    ;;
  apply)
    apply_daily
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "Unknown daily driver action: $ACTION"
    usage
    exit 1
    ;;
esac
