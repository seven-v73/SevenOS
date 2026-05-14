#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="plan"
JSON_OUTPUT=0
APPLY=0
YES=0
SAFE_ONLY=0
LIMIT=6

usage() {
  cat <<'EOF'
SevenOS Control Plane

Usage:
  seven control
  seven control --json
  seven control apply [--limit N] [--safe-only] [--apply] [--yes]
  ./scripts/control-plane.sh [plan|apply] [--json]

Builds a single prioritized OS action plan from readiness, experience,
Shield, Server, profiles and registered actions. This is the decision contract
for Seven Hub and future Seven Server orchestration.
EOF
}

while [[ "$#" -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    plan|apply) ACTION="$arg" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    --safe-only) SAFE_ONLY=1 ;;
    --limit)
      shift
      LIMIT="${1:-}"
      [[ "$LIMIT" =~ ^[0-9]+$ ]] || { log_error "--limit expects a number."; exit 1; }
      ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown control option: $arg"; usage; exit 1 ;;
  esac
  shift
done

if [[ "$YES" -eq 1 ]]; then
  export SEVENOS_YES=1
fi

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

execute_plan() {
  local control_payload command_count=0
  control_payload="$(payload)"

  printf 'SevenOS Control Apply\n'
  printf '=====================\n'
  if [[ "$APPLY" -eq 1 ]]; then
    log_warn "Apply mode enabled. SevenOS will run prioritized actions."
    [[ "$YES" -eq 1 ]] && log_warn "Non-interactive package install mode enabled where supported."
  else
    printf 'Preview only. Add --apply to execute.\n'
  fi
  [[ "$SAFE_ONLY" -eq 1 ]] && printf 'Safe-only mode: skipping package and system-changing actions.\n'
  printf '\n'

  if [[ "$APPLY" -eq 1 && "$SAFE_ONLY" -ne 1 && ! is_dry_run ]] && ! sudo -n true 2>/dev/null; then
    log_error "Control apply needs an active sudo session for prioritized system changes."
    log_info "Run 'sudo -v' first, or preview with: seven control apply --limit $LIMIT"
    exit 1
  fi

  "$ROOT_DIR/scripts/events.sh" log \
    --source control \
    --type "$([[ "$APPLY" -eq 1 ]] && printf apply || printf preview)" \
    --state "$([[ "$APPLY" -eq 1 ]] && printf WARN || printf OK)" \
    --message "Control plane $([[ "$APPLY" -eq 1 ]] && printf apply || printf preview) requested with limit $LIMIT" \
    --command "seven control apply --limit $LIMIT$([[ "$SAFE_ONLY" -eq 1 ]] && printf ' --safe-only')$([[ "$APPLY" -eq 1 ]] && printf ' --apply')" >/dev/null

  while IFS=$'\t' read -r severity impact command reason; do
    [[ -n "${command:-}" ]] || continue
    command_count=$((command_count + 1))
    printf '%-9s %-9s %s\n' "$severity" "$impact" "$command"
    printf '%-9s %-9s %s\n' "" "" "$reason"

    if [[ "$APPLY" -eq 1 && ! is_dry_run ]]; then
      bash -lc "cd '$ROOT_DIR' && $command"
    else
      printf '          DRY-RUN > %s\n' "$command"
    fi
    printf '\n'
  done < <(
    CONTROL_PAYLOAD="$control_payload" SAFE_ONLY="$SAFE_ONLY" LIMIT="$LIMIT" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTROL_PAYLOAD"])
safe_only = os.environ.get("SAFE_ONLY") == "1"
limit = int(os.environ.get("LIMIT", "6"))
count = 0

for item in data.get("actions", []):
    if safe_only and item.get("impact") != "safe":
        continue
    print("\t".join([
        item.get("severity", ""),
        item.get("impact", ""),
        item.get("command", ""),
        item.get("reason", ""),
    ]))
    count += 1
    if count >= limit:
        break
PY
  )

  if [[ "$command_count" -eq 0 ]]; then
    log_success "No matching control actions to run."
  fi
}

if [[ "$ACTION" == "apply" ]]; then
  execute_plan
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
