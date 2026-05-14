#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

JSON_OUTPUT=0
LIMIT=8

usage() {
  cat <<'EOF'
SevenOS Insights

Usage:
  seven insights
  seven insights --json
  ./scripts/insights.sh [--json] [--limit N]

Insights convert SevenOS state, control priorities, profiles and trust posture
into a product-facing diagnosis for Seven Hub, Seven Server and the user.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json|json) JSON_OUTPUT=1 ;;
    --limit)
      shift
      LIMIT="${1:-}"
      [[ "$LIMIT" =~ ^[0-9]+$ ]] || { log_error "--limit expects a number."; exit 1; }
      ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown insights option: $1"; usage; exit 1 ;;
  esac
  shift
done

payload() {
  local state_payload
  state_payload="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/state.sh" --json)"
  STATE_PAYLOAD="$state_payload" LIMIT="$LIMIT" python - <<'PY'
import json
import os

state = json.loads(os.environ["STATE_PAYLOAD"])
limit = int(os.environ.get("LIMIT", "8"))

readiness = state.get("readiness") or {}
experience = state.get("experience") or {}
control = state.get("control") or {}
shield = state.get("shield") or {}
shield_plan = state.get("shield_plan") or {}
server = state.get("server") or {}
server_plan = state.get("server_plan") or {}
windows = state.get("windows") or {}
profiles = state.get("profiles") or []
profile_gaps = state.get("profile_gaps") or {}
ecosystem = state.get("ecosystem") or {}
events = state.get("events") or {}

insights = []
seen = set()

def score_band(value):
    try:
        value = int(value)
    except Exception:
        value = 0
    if value >= 85:
        return "strong"
    if value >= 65:
        return "workable"
    if value >= 40:
        return "fragile"
    return "blocked"

def add(domain, severity, title, detail, command, kind="product", source="state"):
    key = (domain, title, command)
    if key in seen:
        return
    seen.add(key)
    insights.append({
        "domain": domain,
        "severity": severity,
        "kind": kind,
        "title": title,
        "detail": detail,
        "command": command,
        "source": source,
    })

readiness_percent = readiness.get("percent", 0)
experience_percent = experience.get("percent", 0)
control_percent = control.get("overall", 0)
shield_percent = shield.get("percent", 0)
server_state = (server.get("service") or {}).get("state", "MISS")
windows_ready = bool(windows.get("ready"))

if readiness_percent < 80:
    add(
        "readiness",
        "high" if readiness_percent < 60 else "medium",
        "Raise OS readiness",
        f"SevenOS readiness is {readiness_percent}%, so the product still has visible setup gaps.",
        "seven readiness",
        "foundation",
        "readiness",
    )

if experience_percent < 85:
    add(
        "experience",
        "high" if experience_percent < 65 else "medium",
        "Polish product experience",
        f"Experience coherence is {experience_percent}%; this is the score that separates an OS from a configured desktop.",
        "seven experience",
        "uiux",
        "experience",
    )

if shield_percent < 75:
    next_shield = (shield_plan.get("next") or [{}])[0]
    add(
        "security",
        "critical" if shield_percent < 45 else "high",
        "Improve trust posture",
        f"Shield posture is {shield.get('posture', 'unknown')} at {shield_percent}%. Security must be visible and default-safe.",
        next_shield.get("command", "seven shield plan"),
        "trust",
        "shield",
    )

if server_state != "RUN":
    next_server = (server_plan.get("next") or [{}])[0]
    add(
        "server",
        "medium",
        "Start local OS API",
        f"Seven Server is {server_state}. A fluid ecosystem needs a local backend for Hub and automation.",
        next_server.get("command", "seven server plan"),
        "service",
        "server",
    )

if not windows_ready:
    add(
        "windows",
        "medium",
        "Complete Windows Mode",
        "Windows compatibility is not fully ready; guide Bottles/Wine/KVM through one accessible path.",
        "seven windows guide",
        "compatibility",
        "windows",
    )

for profile in profile_gaps.get("profiles", profiles):
    profile_state = profile.get("state", "MISS")
    if profile_state == "OK":
        continue
    title = profile.get("title") or profile.get("key", "Profile").title()
    priority = profile.get("priority", "medium")
    add(
        "profiles",
        "critical" if priority == "critical" else "high" if priority == "high" else "medium" if profile_state == "PART" else "high",
        f"Complete {title}",
        f"{title} is {profile_state} with {profile.get('missing_count', max(profile.get('total', 0) - profile.get('installed', 0), 0))} missing packages. Profiles must be functional work modes, not decoration.",
        profile.get("install_command") or f"seven profile install {profile.get('key', '')}".strip(),
        "workflow",
        "profiles",
    )

for item in control.get("actions", [])[:6]:
    add(
        item.get("source", "control"),
        item.get("severity", "medium"),
        item.get("title") or item.get("command", "SevenOS action"),
        item.get("reason", "Prioritized by SevenOS Control Plane."),
        item.get("command", "seven control"),
        item.get("impact", "safe"),
        "control",
    )

severity_rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
insights.sort(key=lambda item: (severity_rank.get(item["severity"], 9), item["domain"], item["title"]))

ecosystem_modules = ecosystem.get("modules") or []
active_modules = sum(1 for item in ecosystem_modules if item.get("state") == "active")
preview_modules = sum(1 for item in ecosystem_modules if item.get("state") == "preview")
planned_modules = sum(1 for item in ecosystem_modules if item.get("state") == "planned")

signals = {
    "readiness": {"percent": readiness_percent, "band": score_band(readiness_percent)},
    "experience": {"percent": experience_percent, "band": score_band(experience_percent)},
    "control": {"percent": control_percent, "band": score_band(control_percent)},
    "shield": {"percent": shield_percent, "band": score_band(shield_percent)},
    "shield_plan": {
        "total": (shield_plan.get("summary") or {}).get("total", 0),
        "next": (shield_plan.get("next") or [{}])[0].get("command"),
    },
    "server": {"state": server_state},
    "server_plan": {
        "total": (server_plan.get("summary") or {}).get("total", 0),
        "next": (server_plan.get("next") or [{}])[0].get("command"),
    },
    "windows": {"ready": windows_ready},
    "events": {"total": events.get("total", 0), "last": events.get("last")},
    "ecosystem": {
        "active": active_modules,
        "preview": preview_modules,
        "planned": planned_modules,
        "processes": len(ecosystem.get("processes") or []),
    },
}

phase = "B2"
if readiness_percent >= 85 and experience_percent >= 85 and shield_percent >= 75 and server_state in ("RUN", "READY"):
    phase = "B3"
if readiness_percent >= 90 and experience_percent >= 90 and shield_percent >= 85 and server_state == "RUN" and windows_ready:
    phase = "4-preview"

print(json.dumps({
    "schema": "sevenos.insights.v1",
    "phase": phase,
    "summary": {
        "total": len(insights),
        "critical": sum(1 for item in insights if item["severity"] == "critical"),
        "high": sum(1 for item in insights if item["severity"] == "high"),
        "medium": sum(1 for item in insights if item["severity"] == "medium"),
        "headline": "SevenOS is becoming an ecosystem; remaining work is productization, trust and profile completeness.",
    },
    "signals": signals,
    "insights": insights[:limit],
}, indent=2))
PY
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  payload
  exit 0
fi

INSIGHTS_PAYLOAD="$(payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["INSIGHTS_PAYLOAD"])
summary = data.get("summary", {})

print("SevenOS Insights")
print("================")
print(f"Phase: {data.get('phase')}")
print(
    f"Signals: readiness {data.get('signals', {}).get('readiness', {}).get('percent', 0)}%, "
    f"experience {data.get('signals', {}).get('experience', {}).get('percent', 0)}%, "
    f"shield {data.get('signals', {}).get('shield', {}).get('percent', 0)}%"
)
print(
    f"Open items: {summary.get('total', 0)} "
    f"({summary.get('critical', 0)} critical, {summary.get('high', 0)} high, {summary.get('medium', 0)} medium)"
)
print()
for item in data.get("insights", []):
    print(f"{item.get('severity', '').upper():<8} {item.get('domain'):<11} {item.get('title')}")
    print(f"         {item.get('detail')}")
    print(f"         next: {item.get('command')}")
PY
