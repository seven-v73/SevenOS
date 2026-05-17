#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenAI Local

Usage:
  seven ai [brief|plan|doctor|json]
  ./scripts/ai.sh [brief|plan|doctor|json]

SevenAI Local is a provider-neutral system assistant preview. It does not call
an online model; it reads SevenOS state, insights and actions, then turns them
into a short operational plan for the user.
EOF
}

command_json() {
  local fallback="$1"
  shift
  python - "$fallback" "$@" <<'PY'
import json
import subprocess
import sys

fallback = json.loads(sys.argv[1])
result = subprocess.run(sys.argv[2:], text=True, capture_output=True, check=False)
if result.returncode != 0 or not result.stdout.strip():
    print(json.dumps(fallback))
    raise SystemExit(0)
try:
    print(json.dumps(json.loads(result.stdout)))
except json.JSONDecodeError:
    print(json.dumps(fallback))
PY
}

payload_json() {
  local state insights actions shell installer profiles packages
  state="$(command_json '{}' "$ROOT_DIR/scripts/state.sh" --json)"
  insights="$(command_json '{"insights":[],"summary":{}}' "$ROOT_DIR/scripts/insights.sh" --json)"
  actions="$(command_json '{"actions":[]}' "$ROOT_DIR/scripts/actions.sh" --json)"
  shell="$(command_json '{}' "$ROOT_DIR/scripts/shell.sh" status --json)"
  installer="$(command_json '{}' "$ROOT_DIR/scripts/installer-stack.sh" status --json)"
  profiles="$(command_json '{"summary":{},"next":[]}' "$ROOT_DIR/profiles/profile-manager.sh" plan --json)"
  packages="$(command_json '{"summary":{},"next":[]}' "$ROOT_DIR/bin/sevenpkg" plan --json)"

  STATE_JSON="$state" \
  INSIGHTS_JSON="$insights" \
  ACTIONS_JSON="$actions" \
  SHELL_JSON="$shell" \
  INSTALLER_JSON="$installer" \
  PROFILES_JSON="$profiles" \
  PACKAGES_JSON="$packages" \
  python - <<'PY'
import json
import os

def load(name, fallback):
    try:
        return json.loads(os.environ.get(name, "") or json.dumps(fallback))
    except json.JSONDecodeError:
        return fallback

state = load("STATE_JSON", {})
insights = load("INSIGHTS_JSON", {"insights": [], "summary": {}})
actions = load("ACTIONS_JSON", {"actions": []})
shell = load("SHELL_JSON", {})
installer = load("INSTALLER_JSON", {})
profiles = load("PROFILES_JSON", {"summary": {}, "next": []})
packages = load("PACKAGES_JSON", {"summary": {}, "next": []})

daily = state.get("daily") or {}
daily_summary = daily.get("summary") or {}
decision = daily.get("decision") or "unknown"
readiness = daily_summary.get("readiness", state.get("readiness", {}).get("percent", 0))

recommendations = []

def add(key, title, command, reason, impact="safe", priority="medium"):
    if any(item["key"] == key for item in recommendations):
        return
    recommendations.append({
        "key": key,
        "title": title,
        "command": command,
        "reason": reason,
        "impact": impact,
        "priority": priority,
    })

if decision != "ready":
    add("daily", "Finish daily readiness", "seven daily apply --yes", "The daily gate is the closest thing to a whole-system readiness contract.", "packages", "high")

for item in (profiles.get("next") or [])[:2]:
    add(
        f"profile.{item.get('key', 'unknown')}",
        f"Complete {item.get('title', 'profile')}",
        item.get("command") or "seven profile plan",
        item.get("reason") or "A profile still has missing packages or bootstrap files.",
        "packages",
        item.get("priority", "medium"),
    )

for item in (packages.get("next") or [])[:2]:
    add(
        f"package.{item.get('key', 'unknown')}",
        item.get("title") or "Complete software layer",
        item.get("command") or "sevenpkg plan",
        item.get("reason") or "A software layer still needs installation work.",
        item.get("impact", "packages"),
        item.get("severity", "medium"),
    )

shell_state = shell.get("state", "unknown")
if shell_state not in ("READY", "NATIVE_READY", "FOUNDATION"):
    add("shell", "Stabilize Seven Shell", "seven shell doctor", "The shell should expose a coherent native fallback before the AGS migration.", "safe", "high")
elif shell_state == "NATIVE_READY":
    add("shell.next", "Plan AGS migration carefully", "seven shell plan", "The native fallback is usable; AGS can stay an explicit B3 migration instead of disrupting the desktop.", "safe", "medium")

if not installer.get("ready"):
    add("installer", "Prepare installer path", "seven installer plan", "SevenOS should stay installable for normal users, not only repaired after install.", "safe", "medium")

for insight in (insights.get("insights") or [])[:3]:
    key = f"insight.{insight.get('key', insight.get('area', 'item'))}"
    add(
        key,
        insight.get("title") or "Review insight",
        insight.get("command") or "seven insights",
        insight.get("reason") or insight.get("detail") or "SevenOS insight requires attention.",
        insight.get("impact", "safe"),
        insight.get("severity", "medium"),
    )

priority_rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
recommendations.sort(key=lambda item: (priority_rank.get(item.get("priority"), 9), item["key"]))

available_actions = []
for item in actions.get("actions", actions.get("items", []))[:8]:
    available_actions.append({
        "key": item.get("key") or item.get("id"),
        "title": item.get("title"),
        "command": item.get("command"),
        "impact": item.get("impact"),
    })

print(json.dumps({
    "schema": "sevenos.ai-local.v1",
    "mode": "local",
    "provider": "none",
    "summary": {
        "decision": decision,
        "readiness": readiness,
        "shell": shell_state,
        "installer": installer.get("mode", "unknown"),
        "profile_actions": (profiles.get("summary") or {}).get("total", 0),
        "package_actions": (packages.get("summary") or {}).get("total", 0),
    },
    "recommendations": recommendations[:6],
    "actions": available_actions,
}, indent=2))
PY
}

brief() {
  SEVENAI_PAYLOAD="$(payload_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SEVENAI_PAYLOAD"])
summary = data.get("summary", {})
print("SevenAI Local")
print("=============")
print(f"Decision: {summary.get('decision', 'unknown')} · readiness: {summary.get('readiness', 0)}%")
print(f"Shell: {summary.get('shell', 'unknown')} · installer: {summary.get('installer', 'unknown')}")
items = data.get("recommendations", [])
if not items:
    print("Next: no urgent action.")
else:
    print("Next:")
    for item in items[:3]:
        print(f"- {item.get('title')}: {item.get('command')}")
PY
}

plan() {
  SEVENAI_PAYLOAD="$(payload_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SEVENAI_PAYLOAD"])
print("SevenAI Local Plan")
print("==================")
for item in data.get("recommendations", []):
    print(f"{item.get('priority', 'medium').upper():<8} {item.get('title')}")
    print(f"         {item.get('reason')}")
    print(f"         command: {item.get('command')}")
PY
}

doctor() {
  local failures=0
  printf 'SevenAI Local Doctor\n'
  printf '====================\n'
  for path in \
    "scripts/state.sh" \
    "scripts/insights.sh" \
    "scripts/actions.sh" \
    "scripts/ai.sh"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done
  payload_json >/dev/null
  if [[ "$failures" -gt 0 ]]; then
    log_error "SevenAI Local has $failures missing file(s)."
    return 1
  fi
  log_success "SevenAI Local can read SevenOS state."
}

action="${1:-brief}"
case "$action" in
  brief|status) brief ;;
  plan) plan ;;
  doctor) doctor ;;
  json|--json) payload_json ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown SevenAI action: $action"; usage; exit 1 ;;
esac
