#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help)
      cat <<'EOF'
SevenOS Experience Audit

Usage:
  seven experience
  seven experience --json
  ./scripts/experience.sh [--json]

This audit checks whether SevenOS feels like a coherent OS:
identity, shell, native Hub, profiles, actions, Windows Mode,
security, deployment, installer and ecosystem contracts.
EOF
      exit 0
      ;;
    *) log_error "Unknown experience option: $arg"; exit 1 ;;
  esac
done

check_rows() {
  local state="MISS"

  [[ -s "$ROOT_DIR/branding/sevenos-release" && -s "$ROOT_DIR/session/sevenos.desktop" ]] && state="OK"
  printf 'Identity\t%s\tSevenOS release, session and product identity\t./install.sh branding\n' "$state"

  state="MISS"
  if [[ -x "$ROOT_DIR/bin/seven-session" && -x "$ROOT_DIR/bin/seven-shell-panel" ]] &&
     grep -q 'custom/notifications' "$ROOT_DIR/hyprland/waybar/config.jsonc" &&
     grep -q 'seven-overview apps' "$ROOT_DIR/hyprland/hyprland.conf"; then
    state="OK"
  fi
  printf 'Shell\t%s\tHyprland session, Waybar, Quick Settings and app overview\t./install.sh theme\n' "$state"

  state="MISS"
  if [[ -x "$ROOT_DIR/bin/seven-hub-native" ]] &&
     grep -q 'def render_ecosystem' "$ROOT_DIR/bin/seven-hub-native" &&
     grep -q 'def experience_payload' "$ROOT_DIR/bin/seven-hub-native"; then
    state="OK"
  fi
  printf 'Hub\t%s\tNative Control Center reads profiles, actions and ecosystem\tseven hub-native status\n' "$state"

  state="MISS"
  if SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile current --json 2>/dev/null | python -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if "app_status" in d and "next_actions" in d else 1)' >/dev/null; then
    state="OK"
  fi
  printf 'Profiles\t%s\tActive profile exposes workspace, apps and next actions\tseven profile guide\n' "$state"

  state="MISS"
  if SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/ecosystem.sh" json 2>/dev/null | python -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("modules") and d.get("processes") else 1)' >/dev/null; then
    state="OK"
  fi
  printf 'Ecosystem\t%s\tModules and all-in-one processes are machine-readable\tseven ecosystem processes\n' "$state"

  state="MISS"
  if SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/actions.sh" --json 2>/dev/null | python -c 'import json,sys; d=json.load(sys.stdin); ids={a.get("id") for a in d.get("actions", [])}; raise SystemExit(0 if {"apps.open","windows.guide","ecosystem.processes"}.issubset(ids) else 1)' >/dev/null; then
    state="OK"
  fi
  printf 'Actions\t%s\tHub, Waybar and panels share a concrete action registry\tseven actions --json\n' "$state"

  state="MISS"
  if SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-windows-assistant" status --json 2>/dev/null | python -m json.tool >/dev/null; then
    state="PART"
    if SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-windows-assistant" status --json 2>/dev/null | python -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("ready") else 1)' >/dev/null; then
      state="OK"
    fi
  fi
  printf 'Windows Mode\t%s\tGuided Bottles/Wine/KVM path with status JSON\tseven windows guide\n' "$state"

  state="MISS"
  if SEVENOS_DRY_RUN=0 "$ROOT_DIR/security/shield-status.sh" --json 2>/dev/null | python -m json.tool >/dev/null; then
    state="PART"
    if SEVENOS_DRY_RUN=0 "$ROOT_DIR/security/shield-status.sh" --json 2>/dev/null | python -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("posture") == "trusted" else 1)' >/dev/null; then
      state="OK"
    fi
  fi
  printf 'Security\t%s\tFirewall, sandbox and Shield audit are ready\tseven shield status\n' "$state"

  state="MISS"
  if SEVENOS_DRY_RUN=0 "$ROOT_DIR/server/seven-server.sh" status --json 2>/dev/null | python -m json.tool >/dev/null; then
    state="PART"
    if SEVENOS_DRY_RUN=0 "$ROOT_DIR/server/seven-server.sh" status --json 2>/dev/null | python -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("service", {}).get("state") == "RUN" else 1)' >/dev/null; then
      state="OK"
    fi
  fi
  printf 'Server\t%s\tLocal API and deployment planner are available\tseven server status\n' "$state"

  state="MISS"
  if [[ -s "$ROOT_DIR/installer/calamares/settings.conf" && -s "$ROOT_DIR/sevenos.dotinst" ]]; then
    state="PART"
    SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/installer-stack.sh" doctor >/dev/null 2>&1 && state="OK"
  fi
  printf 'Installer\t%s\tCalamares, manifest and ISO foundations are coherent\tseven installer status\n' "$state"
}

score_value() {
  case "$1" in
    OK) printf 2 ;;
    PART) printf 1 ;;
    *) printf 0 ;;
  esac
}

json_output() {
  EXPERIENCE_ROWS="$(check_rows)" python - <<'PY'
import json
import os

items = []
score = 0
max_score = 0
recommendations = []

for raw in os.environ["EXPERIENCE_ROWS"].splitlines():
    category, state, detail, command = raw.split("\t", 3)
    value = {"OK": 2, "PART": 1}.get(state, 0)
    score += value
    max_score += 2
    item = {
        "category": category,
        "state": state,
        "detail": detail,
        "command": command,
    }
    items.append(item)
    if state != "OK":
        recommendations.append({"command": command, "reason": f"Improve {category.lower()} experience"})

percent = round(score * 100 / max_score) if max_score else 0
print(json.dumps({
    "schema": "sevenos.experience.v1",
    "score": score,
    "max": max_score,
    "percent": percent,
    "checks": items,
    "recommendations": recommendations,
}, indent=2))
PY
}

human_output() {
  local score=0
  local max_score=0
  local category state detail command value

  printf 'SevenOS Experience Audit\n'
  printf '========================\n'
  printf '%-14s %-5s %s\n' "Area" "State" "Detail"
  printf '%-14s %-5s %s\n' "----" "-----" "------"

  while IFS=$'\t' read -r category state detail command; do
    value="$(score_value "$state")"
    score=$((score + value))
    max_score=$((max_score + 2))
    printf '%-14s %-5s %s\n' "$category" "$state" "$detail"
    [[ "$state" == "OK" ]] || printf '%-14s %-5s next: %s\n' "" "" "$command"
  done < <(check_rows)

  printf '\nScore: %s/%s (%s%%)\n' "$score" "$max_score" "$((score * 100 / max_score))"
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  json_output
else
  human_output
fi
