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
  seven shield bootstrap
  seven shield workspace [--json]
  ./security/shield-status.sh [status|plan] [--json]

Shows the local trust posture: firewall, sandbox helpers, audit tools and
recommended actions. It is read-only and safe for Seven Hub.
EOF
}

shield_workspace_state() {
  local workspace="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
  if [[ -s "$workspace/.sevenos/shield.json" &&
        -s "$workspace/.sevenos/persona.json" &&
        -s "$workspace/.sevenos/SHIELD_CHECKLIST.md" &&
        -s "$workspace/.sevenos/SANDBOXES.md" &&
        -x "$workspace/.sevenos/launchers/secure-browser.sh" &&
        -x "$workspace/.sevenos/launchers/network-audit.sh" ]]; then
    printf OK
  elif [[ -e "$workspace/.sevenos/shield.json" ||
          -e "$workspace/.sevenos/persona.json" ||
          -e "$workspace/.sevenos/SHIELD_CHECKLIST.md" ||
          -e "$workspace/.sevenos/SANDBOXES.md" ]]; then
    printf PART
  else
    printf MISS
  fi
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

if [[ "$JSON_OUTPUT" -eq 1 && -x "$ROOT_DIR/bin/seven-daemon" ]]; then
  if [[ "$ACTION" == "plan" ]]; then
    exec "$ROOT_DIR/bin/seven-daemon" shield-plan --json
  fi
  exec "$ROOT_DIR/bin/seven-daemon" shield --json
fi

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
  if [[ "$service" == "ufw.service" && -s "${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/security/ufw-degraded" ]]; then
    printf PART
    return 0
  fi
  if systemctl is-active --quiet "$service" 2>/dev/null; then
    printf OK
  elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
    printf PART
  else
    printf MISS
  fi
}

rows() {
  printf 'workspace\t%s\tShield workspace policy and launchers\tseven shield bootstrap\n' "$(shield_workspace_state)"
  printf 'persona\t%s\tShield persona and session state\tseven shield persona safe\n' "$("$ROOT_DIR/security/shield-persona.sh" status --json >/dev/null 2>&1 && printf OK || printf MISS)"
  printf 'scope\t%s\tShield authorization scope gate\tseven shield scope\n' "$("$ROOT_DIR/security/shield-scope.sh" validate >/dev/null 2>&1 && printf OK || printf PART)"
  printf 'network_guard\t%s\tPersona-aware network posture\tseven shield network apply\n' "$("$ROOT_DIR/security/shield-network-guard.sh" status --json >/dev/null 2>&1 && printf OK || printf MISS)"
  printf 'evidence\t%s\tEvidence hash and chain-of-custody index\tseven shield evidence init\n' "$("$ROOT_DIR/security/shield-evidence.sh" status --json >/dev/null 2>&1 && printf OK || printf MISS)"
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
    "workspace": {
        "title": "Bootstrap Shield workspace",
        "severity": "medium",
        "impact": "safe",
        "phase": "workspace",
        "reason": "Shield needs visible policy, checklist and launchers before it feels like an OS trust layer.",
    },
    "persona": {
        "title": "Initialize Shield Persona Engine",
        "severity": "medium",
        "impact": "safe",
        "phase": "persona",
        "reason": "Shield should expose a visible cybersecurity mode, session policy and isolation intent.",
    },
    "scope": {
        "title": "Complete Shield scope",
        "severity": "high",
        "impact": "safe",
        "phase": "authorization",
        "reason": "Pentest and Red Team workflows need owner, engagement, time window and targets before execution.",
    },
    "network_guard": {
        "title": "Record Network Guard posture",
        "severity": "medium",
        "impact": "safe",
        "phase": "network",
        "reason": "Shield personas should expose VPN/Tor/offline/scope requirements before tools launch.",
    },
    "evidence": {
        "title": "Initialize Evidence Manager",
        "severity": "medium",
        "impact": "safe",
        "phase": "forensics",
        "reason": "Forensics needs hashes, metadata and chain-of-custody records.",
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
