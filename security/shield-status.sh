#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS Shield Status

Usage:
  seven shield status [--json]
  ./security/shield-status.sh [--json]

Shows the local trust posture: firewall, sandbox helpers, audit tools and
recommended actions. It is read-only and safe for Seven Hub.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown Shield status option: $arg"; usage; exit 1 ;;
  esac
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

score_value() {
  case "$1" in
    OK) printf 2 ;;
    PART) printf 1 ;;
    *) printf 0 ;;
  esac
}

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
