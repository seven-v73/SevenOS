#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0
LIMIT=8

usage() {
  cat <<'EOF'
SevenOS Shield Status

Usage:
  seven shield status [--json]
  seven shield plan [--json] [--limit N]
  ./security/shield-status.sh [status|plan] [--json]

Shows the local trust posture: firewall, sandbox helpers, audit tools and
recommended actions. It is read-only and safe for Seven Hub.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|plan) ACTION="$1" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --limit)
      shift
      LIMIT="${1:-}"
      [[ "$LIMIT" =~ ^[0-9]+$ ]] || { log_error "--limit expects a number."; exit 1; }
      ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown Shield option: $1"; usage; exit 1 ;;
  esac
  shift
done

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

package_state() {
  local package="$1"
  if pacman -Q "$package" >/dev/null 2>&1; then
    printf OK
  else
    printf MISS
  fi
}

command_state() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    printf OK
  else
    printf MISS
  fi
}

service_state() {
  local service="$1"
  if systemctl is-active --quiet "$service" 2>/dev/null; then
    printf OK
  elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
    printf PART
  else
    printf MISS
  fi
}

rows() {
  printf 'firewall\t%s\tUFW firewall service\tseven shield enable\n' "$(service_state ufw.service)"
  printf 'firejail\t%s\tFirejail app sandbox helper\tseven improve security --apply\n' "$(package_state firejail)"
  printf 'bubblewrap\t%s\tBubblewrap namespace sandbox helper\tseven improve security --apply\n' "$(package_state bubblewrap)"
  printf 'nmap\t%s\tNetwork audit tool\tseven profile install shield\n' "$(command_state nmap)"
  printf 'wireshark\t%s\tPacket analysis tool\tseven profile install shield\n' "$(command_state wireshark)"
}

plan_json() {
  SHIELD_ROWS="$(rows)" LIMIT="$LIMIT" python - <<'PY'
import json
import os

limit = int(os.environ.get("LIMIT", "8"))

metadata = {
    "firewall": {
        "title": "Enable default firewall",
        "severity": "critical",
        "impact": "changes",
        "phase": "trust",
        "reason": "SevenOS must protect incoming traffic by default.",
    },
    "firejail": {
        "title": "Install Firejail sandbox",
        "severity": "high",
        "impact": "packages",
        "phase": "sandbox",
        "reason": "Apps and cyber tools need an accessible isolation layer.",
    },
    "bubblewrap": {
        "title": "Install Bubblewrap namespaces",
        "severity": "high",
        "impact": "packages",
        "phase": "sandbox",
        "reason": "Flatpak-style isolation depends on namespace sandboxing.",
    },
    "nmap": {
        "title": "Install network audit tools",
        "severity": "medium",
        "impact": "packages",
        "phase": "audit",
        "reason": "Shield mode needs first-class network discovery tools.",
    },
    "wireshark": {
        "title": "Install packet analysis tools",
        "severity": "medium",
        "impact": "packages",
        "phase": "audit",
        "reason": "Shield mode needs visual packet analysis for real workflows.",
    },
}

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions = []

for raw in os.environ["SHIELD_ROWS"].splitlines():
    key, state, detail, command = raw.split("\t", 3)
    if state == "OK":
        continue
    item = metadata.get(key, {})
    actions.append({
        "key": key,
        "state": state,
        "title": item.get("title", f"Fix {key}"),
        "severity": item.get("severity", "medium"),
        "impact": item.get("impact", "changes"),
        "phase": item.get("phase", "trust"),
        "detail": detail,
        "reason": item.get("reason", f"Resolve {key}."),
        "command": command,
    })

actions.sort(key=lambda item: (rank.get(item["severity"], 9), item["key"]))
actions = actions[:limit]

print(json.dumps({
    "schema": "sevenos.shield-plan.v1",
    "summary": {
        "total": len(actions),
        "critical": sum(1 for item in actions if item["severity"] == "critical"),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
    },
    "next": actions,
}, indent=2))
PY
}

plan_human() {
  PLAN_PAYLOAD="$(plan_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["PLAN_PAYLOAD"])
summary = data.get("summary", {})

print("SevenOS Shield Plan")
print("===================")
print(
    f"Open actions: {summary.get('total', 0)} "
    f"({summary.get('critical', 0)} critical, {summary.get('high', 0)} high, {summary.get('medium', 0)} medium)"
)
print()
print(f"{'Severity':<9} {'Phase':<9} {'Command'}")
print(f"{'--------':<9} {'-----':<9} {'-------'}")
for item in data.get("next", []):
    print(f"{item.get('severity',''):<9} {item.get('phase',''):<9} {item.get('command','')}")
    print(f"{'':<9} {'':<9} {item.get('reason','')}")
PY
}

score_value() {
  case "$1" in
    OK) printf 2 ;;
    PART) printf 1 ;;
    *) printf 0 ;;
  esac
}

if [[ "$ACTION" == "plan" ]]; then
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    plan_json
  else
    plan_human
  fi
  exit 0
fi

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  SHIELD_ROWS="$(rows)" python - <<'PY'
import json
import os

checks = []
score = 0
max_score = 0
recommendations = []

for raw in os.environ["SHIELD_ROWS"].splitlines():
    key, state, detail, command = raw.split("\t", 3)
    value = {"OK": 2, "PART": 1}.get(state, 0)
    score += value
    max_score += 2
    checks.append({"key": key, "state": state, "detail": detail, "command": command})
    if state != "OK":
        recommendations.append({"command": command, "reason": f"Resolve {key}"})

if score == max_score:
    posture = "trusted"
elif score >= max_score * 0.6:
    posture = "partial"
else:
    posture = "exposed"

print(json.dumps({
    "schema": "sevenos.shield.v1",
    "posture": posture,
    "score": score,
    "max": max_score,
    "percent": round(score * 100 / max_score) if max_score else 0,
    "checks": checks,
    "recommendations": recommendations,
}, indent=2))
PY
  exit 0
fi

score=0
max_score=0

printf 'SevenOS Shield Status\n'
printf '=====================\n'
printf '%-12s %-5s %s\n' "Check" "State" "Detail"
printf '%-12s %-5s %s\n' "-----" "-----" "------"

while IFS=$'\t' read -r key state detail command; do
  score=$((score + $(score_value "$state")))
  max_score=$((max_score + 2))
  printf '%-12s %-5s %s\n' "$key" "$state" "$detail"
  [[ "$state" == OK ]] || printf '%-12s %-5s next: %s\n' "" "" "$command"
done < <(rows)

printf '\nScore: %s/%s (%s%%)\n' "$score" "$max_score" "$((score * 100 / max_score))"
