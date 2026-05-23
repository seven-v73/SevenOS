#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help)
      cat <<'EOF'
SevenOS Release

Usage:
  seven release status [--json]
  seven release plan [--json]
  seven release freeze [--json]
  seven release doctor [--json]

This command separates the stable daily-driver state from the public release
gates: clean git freeze, graphical installer availability, and a user-supplied
legal Windows ISO for Windows Bridge.
EOF
      exit 0
      ;;
    *) log_error "Unknown release option: $arg"; exit 1 ;;
  esac
done

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/release"
FREEZE_JSON="$STATE_DIR/release-freeze.json"
GIT_STATUS_TXT="$STATE_DIR/git-status.txt"
DIFF_STAT_TXT="$STATE_DIR/diff-stat.txt"

json_escape() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

git_value() {
  local fallback="$1"
  shift
  git -C "$ROOT_DIR" "$@" 2>/dev/null || printf '%s\n' "$fallback"
}

git_dirty_count() {
  git -C "$ROOT_DIR" status --short 2>/dev/null | wc -l | tr -d ' '
}

doctor_release_json() {
  "$ROOT_DIR/scripts/doctor.sh" release --json 2>/dev/null || printf '{}'
}

doctor_check_json() {
  "$ROOT_DIR/scripts/doctor.sh" all --json 2>/dev/null || printf '{}'
}

installer_release_json() {
  "$ROOT_DIR/scripts/installer-stack.sh" release --json 2>/dev/null || printf '{}'
}

windows_status_json() {
  "$ROOT_DIR/bin/seven-windows-assistant" status --json 2>/dev/null || printf '{}'
}

channel_status_json() {
  "$ROOT_DIR/scripts/channel.sh" json 2>/dev/null || printf '{}'
}

release_status_json() {
  local doctor installer windows channel dirty_count branch commit freeze_state freeze_path
  doctor="$(doctor_check_json)"
  installer="$(installer_release_json)"
  windows="$(windows_status_json)"
  channel="$(channel_status_json)"
  dirty_count="$(git_dirty_count)"
  branch="$(git_value unknown rev-parse --abbrev-ref HEAD)"
  commit="$(git_value unknown rev-parse --short HEAD)"
  freeze_state="MISS"
  freeze_path=""
  if [[ -s "$FREEZE_JSON" ]]; then
    freeze_state="OK"
    freeze_path="$FREEZE_JSON"
  fi
  DOCTOR_JSON="$doctor" INSTALLER_JSON="$installer" WINDOWS_JSON="$windows" CHANNEL_JSON="$channel" \
  DIRTY_COUNT="$dirty_count" BRANCH="$branch" COMMIT="$commit" \
  FREEZE_STATE="$freeze_state" FREEZE_PATH="$freeze_path" ROOT_DIR="$ROOT_DIR" \
  python - <<'PY'
import json
import os

def load(name):
    try:
        return json.loads(os.environ.get(name, "{}"))
    except json.JSONDecodeError:
        return {}

doctor = load("DOCTOR_JSON")
installer = load("INSTALLER_JSON")
windows = load("WINDOWS_JSON")
channel = load("CHANNEL_JSON")
dirty_count = int(os.environ.get("DIRTY_COUNT", "0") or 0)
summary = doctor.get("summary", {})
doctor_blocked = summary.get("critical", 1) > 0 or summary.get("high", 1) > 0
daily_ready = not doctor_blocked
calamares_runtime = installer.get("calamares_runtime") or next(
    (item.get("state") for item in installer.get("checks", []) if item.get("key") == "calamares-runtime"),
    "unknown",
)
calamares_runtime_detail = (
    "Calamares runtime installed in the ISO environment."
    if calamares_runtime == "OK"
    else f"Calamares runtime policy: {calamares_runtime}; graphical public release still requires the runtime package in the ISO."
)

release_actions = [
    {
        "key": "daily-driver-health",
        "state": "OK" if daily_ready else "PENDING",
        "title": "Conserver le socle daily-driver stable",
        "detail": f"{summary.get('critical', 0)} critical, {summary.get('high', 0)} high issue(s).",
        "command": "seven doctor check --json",
    },
    {
        "key": "freeze-worktree",
        "state": "OK" if dirty_count == 0 else "PENDING",
        "title": "Figer le dépôt avec un commit propre",
        "detail": f"{dirty_count} fichier(s) modifié(s) ou non suivis.",
        "command": "git status --short && git add <files> && git commit",
    },
    {
        "key": "calamares-iso",
        "state": "OK" if installer.get("state") == "graphical-ready" else "PENDING",
        "title": "Fournir Calamares dans l'environnement ISO",
        "detail": f"Installer state: {installer.get('state', 'unknown')}. {calamares_runtime_detail}",
        "command": "seven installer release",
    },
    {
        "key": "windows-vm-provisioning",
        "state": "OK" if windows.get("windows_vm") in {"OK", "RUN"} else "USER_REQUIRED",
        "title": "Créer la VM Windows depuis un média officiel",
        "detail": "SevenOS ne redistribue pas Windows; la VM doit être provisionnée depuis un média officiel ou autorisé par l'utilisateur.",
        "command": "seven windows provision --yes",
    },
]
release_issues = [item for item in release_actions if item["state"] not in {"OK", "READY", "RUN"}]
public_ready = not release_issues

print(json.dumps({
    "schema": "sevenos.release.v1",
    "root": os.environ.get("ROOT_DIR"),
    "branch": os.environ.get("BRANCH"),
    "commit": os.environ.get("COMMIT"),
    "channel": channel.get("channel", "dev"),
    "channel_state": channel.get("state", "unknown"),
    "state": "public-release-ready" if public_ready else "daily-driver-ready" if daily_ready else "release-blocked",
    "daily_driver_ready": daily_ready,
    "public_release_ready": public_ready,
    "worktree": {
        "dirty_count": dirty_count,
        "freeze_state": os.environ.get("FREEZE_STATE", "MISS"),
        "freeze_path": os.environ.get("FREEZE_PATH", ""),
    },
    "installer": {
        "state": installer.get("state", "unknown"),
        "calamares_runtime": calamares_runtime,
    },
    "windows": {
        "vm_state": windows.get("windows_vm", "unknown"),
        "vm_plan": windows.get("windows_vm_plan", "unknown"),
    },
    "issues": doctor.get("issues", []) + release_issues,
    "release_actions": release_actions,
}, indent=2))
PY
}

release_plan_json() {
  local status
  status="$(release_status_json)"
  STATUS_JSON="$status" python - <<'PY'
import json
import os

data = json.loads(os.environ["STATUS_JSON"])
actions = data.get("release_actions", [])
installer = data.get("installer", {})
calamares_runtime = installer.get("calamares_runtime", "unknown")
installer_command = (
    "seven installer runtime"
    if calamares_runtime in {"aur-candidate", "source-declared"}
    else "seven installer release"
)
installer_goal = (
    f"Transformer la source Calamares {calamares_runtime} en runtime embarqué dans l'ISO."
    if calamares_runtime in {"aur-candidate", "source-declared"}
    else "Installer ou embarquer Calamares dans l'environnement ISO."
)
plan = [
    {
        "phase": "daily-driver",
        "state": "OK" if data.get("daily_driver_ready") else "PART",
        "goal": "Conserver SevenOS stable en usage quotidien.",
        "command": "seven doctor check --json",
    },
    {
        "phase": "repository-freeze",
        "state": next((item["state"] for item in actions if item["key"] == "freeze-worktree"), "PENDING"),
        "goal": "Créer un point de version vérifiable avant ISO publique.",
        "command": "seven release freeze && git status --short",
    },
    {
        "phase": "installer-iso",
        "state": next((item["state"] for item in actions if item["key"] == "calamares-iso"), "PENDING"),
        "goal": installer_goal,
        "command": installer_command,
    },
    {
        "phase": "windows-bridge",
        "state": next((item["state"] for item in actions if item["key"] == "windows-vm-provisioning"), "USER_REQUIRED"),
        "goal": "Créer une VM Windows uniquement avec une ISO fournie légalement par l'utilisateur.",
        "command": "seven windows guide",
    },
]
print(json.dumps({
    "schema": "sevenos.release-plan.v1",
    "public_release_ready": data.get("public_release_ready", False),
    "plan": plan,
}, indent=2))
PY
}

release_freeze_json() {
  mkdir -p "$STATE_DIR"
  git -C "$ROOT_DIR" status --short >"$GIT_STATUS_TXT" 2>/dev/null || true
  git -C "$ROOT_DIR" diff --stat >"$DIFF_STAT_TXT" 2>/dev/null || true

  local status dirty_count branch commit timestamp
  status="$(release_status_json)"
  dirty_count="$(git_dirty_count)"
  branch="$(git_value unknown rev-parse --abbrev-ref HEAD)"
  commit="$(git_value unknown rev-parse --short HEAD)"
  timestamp="$(date -Is)"
  STATUS_JSON="$status" DIRTY_COUNT="$dirty_count" BRANCH="$branch" COMMIT="$commit" \
  TIMESTAMP="$timestamp" ROOT_DIR="$ROOT_DIR" GIT_STATUS_TXT="$GIT_STATUS_TXT" DIFF_STAT_TXT="$DIFF_STAT_TXT" \
  python - <<'PY' >"$FREEZE_JSON"
import json
import os

status = json.loads(os.environ["STATUS_JSON"])
print(json.dumps({
    "schema": "sevenos.release-freeze.v1",
    "timestamp": os.environ["TIMESTAMP"],
    "root": os.environ["ROOT_DIR"],
    "branch": os.environ["BRANCH"],
    "commit": os.environ["COMMIT"],
    "dirty_count": int(os.environ["DIRTY_COUNT"]),
    "git_status_path": os.environ["GIT_STATUS_TXT"],
    "diff_stat_path": os.environ["DIFF_STAT_TXT"],
    "daily_driver_ready": status.get("daily_driver_ready", False),
    "public_release_ready": status.get("public_release_ready", False),
    "state": status.get("state", "unknown"),
    "remaining_release_actions": [
        item for item in status.get("release_actions", [])
        if item.get("state") not in {"OK", "READY", "RUN"}
    ],
}, indent=2))
PY
  cat "$FREEZE_JSON"
}

print_status_human() {
  STATUS_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["STATUS_JSON"])
print("SevenOS Release Status")
print("======================")
print(f"Daily driver:   {data.get('daily_driver_ready')}")
print(f"Public release: {data.get('public_release_ready')}")
print(f"State:          {data.get('state')}")
print(f"Branch/commit:  {data.get('branch')} / {data.get('commit')}")
print(f"Dirty files:    {data.get('worktree', {}).get('dirty_count')}")
print()
print("Release gates:")
for item in data.get("release_actions", []):
    print(f"  - {item['state']:<13} {item['title']}")
    print(f"    {item['detail']}")
PY
}

print_plan_human() {
  PLAN_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PLAN_JSON"])
print("SevenOS Public Release Plan")
print("===========================")
for item in data.get("plan", []):
    print(f"  - {item['state']:<13} {item['phase']}: {item['goal']}")
    print(f"    {item['command']}")
PY
}

case "$ACTION" in
  status|json)
    payload="$(release_status_json)"
    if [[ "$JSON_OUTPUT" -eq 1 || "$ACTION" == "json" ]]; then
      printf '%s\n' "$payload"
    else
      print_status_human "$payload"
    fi
    ;;
  plan)
    payload="$(release_plan_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan_human "$payload"
    fi
    ;;
  freeze)
    payload="$(release_freeze_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      FREEZE_PAYLOAD="$payload" python - <<'PY'
import json
import os
data = json.loads(os.environ["FREEZE_PAYLOAD"])
print("SevenOS release freeze written")
print("==============================")
print(f"Manifest: {os.environ.get('XDG_STATE_HOME', os.path.expanduser('~/.local/state'))}/sevenos/release/release-freeze.json")
print(f"State:    {data.get('state')}")
print(f"Dirty:    {data.get('dirty_count')}")
print("Note: no git commit was created automatically.")
PY
    fi
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      doctor_release_json
    else
      "$ROOT_DIR/scripts/doctor.sh" release
    fi
    ;;
  *)
    log_error "Unknown release action: $ACTION"
    exit 1
    ;;
esac
