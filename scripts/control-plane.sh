#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS Control Plane

Usage:
  seven control
  seven control --json
  ./scripts/control-plane.sh [--json]

Builds a single prioritized OS action plan from readiness, experience,
Shield, Server, profiles and registered actions. This is the decision contract
for Seven Hub and future Seven Server orchestration.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown control option: $arg"; usage; exit 1 ;;
  esac
done

payload() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess

ROOT = os.environ["SEVENOS_ROOT"]

def command_json(command, fallback):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback

readiness = command_json([os.path.join(ROOT, "scripts/readiness.sh"), "--json"], {"percent": 0, "recommendations": []})
experience = command_json([os.path.join(ROOT, "scripts/experience.sh"), "--json"], {"percent": 0, "checks": [], "recommendations": []})
shield = command_json([os.path.join(ROOT, "security/shield-status.sh"), "--json"], {"posture": "unknown", "percent": 0, "checks": [], "recommendations": []})
server = command_json([os.path.join(ROOT, "server/seven-server.sh"), "status", "--json"], {"service": {"state": "MISS"}, "recommendations": []})
profiles = command_json([os.path.join(ROOT, "bin/seven"), "profile", "status", "--json"], [])
actions = command_json([os.path.join(ROOT, "scripts/actions.sh"), "--json"], {"actions": []})

actions_by_command = {item.get("command"): item for item in actions.get("actions", [])}

def action_id_for(command):
    item = actions_by_command.get(command)
    return item.get("id") if item else None

items = []
seen = set()

def add(source, severity, title, command, reason, impact="safe"):
    key = (source, command, reason)
    if key in seen:
        return
    seen.add(key)
    items.append({
        "source": source,
        "severity": severity,
        "title": title,
        "command": command,
        "action_id": action_id_for(command),
        "impact": impact,
        "reason": reason,
    })

for check in experience.get("checks", []):
    state = check.get("state")
    if state == "OK":
        continue
    command = check.get("command", "seven experience")
    severity = "high" if state == "MISS" else "medium"
    add("experience", severity, f"Fix {check.get('category', 'Experience')}", command, check.get("detail", "Improve SevenOS coherence"), "changes")

for check in shield.get("checks", []):
    state = check.get("state")
    if state == "OK":
        continue
    command = check.get("command", "seven shield status")
    severity = "critical" if check.get("key") == "firewall" and state == "MISS" else "high"
    add("shield", severity, f"Secure {check.get('key', 'Shield')}", command, check.get("detail", "Improve Shield posture"), "changes")

for rec in server.get("recommendations", []):
    add("server", "medium", "Prepare Seven Server", rec.get("command", "seven server status"), rec.get("reason", "Improve local API readiness"), "changes")

for rec in readiness.get("recommendations", []):
    add("readiness", "medium", "Improve Readiness", rec.get("command", "seven readiness"), rec.get("reason", "Improve SevenOS readiness"), "changes")

for profile in profiles:
    if profile.get("state") == "OK":
        continue
    key = profile.get("key", "profile")
    title = profile.get("title", key.title())
    add("profiles", "medium", f"Complete {title}", f"seven profile install {key}", f"{title} workspace is {profile.get('state', 'partial')}", "packages")

severity_rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
items.sort(key=lambda item: (severity_rank.get(item["severity"], 9), item["source"], item["command"]))

scores = {
    "readiness": readiness.get("percent", 0),
    "experience": experience.get("percent", 0),
    "shield": shield.get("percent", 0),
    "server": 100 if server.get("service", {}).get("state") == "RUN" else 50 if server.get("service", {}).get("state") == "READY" else 0,
}
overall = round((scores["readiness"] * 0.30) + (scores["experience"] * 0.30) + (scores["shield"] * 0.25) + (scores["server"] * 0.15))

print(json.dumps({
    "schema": "sevenos.control.v1",
    "overall": overall,
    "scores": scores,
    "summary": {
        "critical": sum(1 for item in items if item["severity"] == "critical"),
        "high": sum(1 for item in items if item["severity"] == "high"),
        "medium": sum(1 for item in items if item["severity"] == "medium"),
        "total": len(items),
    },
    "actions": items[:12],
}, indent=2))
PY
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  payload
  exit 0
fi

CONTROL_PAYLOAD="$(payload)" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["CONTROL_PAYLOAD"])
summary = data.get("summary", {})

print("SevenOS Control Plane")
print("=====================")
print(f"Overall: {data.get('overall', 0)}%")
print(
    "Actions: "
    f"{summary.get('critical', 0)} critical, "
    f"{summary.get('high', 0)} high, "
    f"{summary.get('medium', 0)} medium"
)
print()
print(f"{'Severity':<9} {'Source':<11} {'Command'}")
print(f"{'--------':<9} {'------':<11} {'-------'}")
for item in data.get("actions", []):
    print(f"{item.get('severity',''):<9} {item.get('source',''):<11} {item.get('command','')}")
    print(f"{'':<9} {'':<11} {item.get('reason','')}")
PY
