#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS lifecycle contract

Usage:
  seven lifecycle [status|doctor|plan|json] [--json]
  ./scripts/lifecycle.sh [status|doctor|plan|json] [--json]

This is the public maintenance contract for SevenOS updates, repair, protected
state, release gates and recovery routes.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown lifecycle option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

lifecycle_json() {
  local tmp
  tmp="$(mktemp -d)"
  env SEVENOS_ABOUT_FAST="${SEVENOS_LIFECYCLE_FAST:-0}" SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/about.sh" json >"$tmp/about.json" 2>/dev/null || printf '{}\n' >"$tmp/about.json" &
  local pid_about=$!
  SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/distribution.sh" json >"$tmp/distribution.json" 2>/dev/null || printf '{}\n' >"$tmp/distribution.json" &
  local pid_distribution=$!
  SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/channel.sh" json >"$tmp/channel.json" 2>/dev/null || printf '{}\n' >"$tmp/channel.json" &
  local pid_channel=$!
  SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/update.sh" json >"$tmp/update.json" 2>/dev/null || printf '{}\n' >"$tmp/update.json" &
  local pid_update=$!
  SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/recovery.sh" json >"$tmp/recovery.json" 2>/dev/null || printf '{}\n' >"$tmp/recovery.json" &
  local pid_recovery=$!
  SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/manifest.sh" summary-json >"$tmp/manifest.json" 2>/dev/null || printf '{}\n' >"$tmp/manifest.json" &
  local pid_manifest=$!
  SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/installer-stack.sh" release --json >"$tmp/installer.json" 2>/dev/null || printf '{}\n' >"$tmp/installer.json" &
  local pid_installer=$!
  wait "$pid_about" "$pid_distribution" "$pid_channel" "$pid_update" "$pid_recovery" "$pid_manifest" "$pid_installer" || true

  SEVENOS_ROOT="$ROOT_DIR" \
  ABOUT_JSON="$tmp/about.json" \
  DISTRIBUTION_JSON="$tmp/distribution.json" \
  CHANNEL_JSON="$tmp/channel.json" \
  UPDATE_JSON="$tmp/update.json" \
  RECOVERY_JSON="$tmp/recovery.json" \
  MANIFEST_JSON="$tmp/manifest.json" \
  INSTALLER_JSON="$tmp/installer.json" \
  python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def load_path(name):
    try:
        data = json.loads(Path(os.environ[name]).read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def executable(rel):
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


def contains(rel, needle):
    try:
        return needle in (root / rel).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return False


about = load_path("ABOUT_JSON")
distribution = load_path("DISTRIBUTION_JSON")
channel = load_path("CHANNEL_JSON")
update = load_path("UPDATE_JSON")
recovery = load_path("RECOVERY_JSON")
manifest = load_path("MANIFEST_JSON")
installer = load_path("INSTALLER_JSON")

checks = [
    {
        "key": "about-identity",
        "state": "OK" if about.get("schema") == "sevenos.about.v1" else "PART",
        "title": "SevenOS identity route",
        "detail": "About screens can present SevenOS edition, channel and active mini OS.",
        "command": "seven about",
    },
    {
        "key": "distribution-gate",
        "state": "OK" if distribution.get("daily_driver_ready") else "PART",
        "title": "Distribution health gate",
        "detail": f"{distribution.get('state', 'unknown')} at {distribution.get('score', 'unknown')}%.",
        "command": "seven distribution",
    },
    {
        "key": "release-channel",
        "state": "OK" if channel.get("schema") == "sevenos.release-channel.v1" else "PART",
        "title": "Release channel",
        "detail": f"{channel.get('channel', 'unknown')} / {channel.get('state', 'unknown')}.",
        "command": "seven channel",
    },
    {
        "key": "software-update",
        "state": "OK" if update.get("schema") == "sevenos.update.v1" and update.get("score", 0) >= 75 else "PART",
        "title": "SevenOS software update facade",
        "detail": f"Update state: {update.get('state', 'unknown')}; score: {update.get('score', 'unknown')}%.",
        "command": "seven update",
    },
    {
        "key": "recovery-route",
        "state": "OK" if recovery.get("schema") == "sevenos.recovery.v1" and recovery.get("score", 0) >= 90 else "PART",
        "title": "SevenOS recovery facade",
        "detail": f"Recovery state: {recovery.get('state', 'unknown')}; score: {recovery.get('score', 'unknown')}%.",
        "command": "seven recovery",
    },
    {
        "key": "repair-route",
        "state": "OK" if executable("scripts/repair.sh") and executable("scripts/system-repair.sh") else "MISS",
        "title": "Guided repair route",
        "detail": "Repair is exposed as Seven Doctor/Repair before raw systemctl or journalctl.",
        "command": "seven repair",
    },
    {
        "key": "protected-state",
        "state": "OK" if int(manifest.get("protected_count", 0) or 0) > 0 and int(manifest.get("restore_count", 0) or 0) > 0 else "PART",
        "title": "Protected user state",
        "detail": f"{manifest.get('protected_count', 0)} protected path(s), {manifest.get('restore_count', 0)} restore rule(s).",
        "command": "seven manifest restore-plan",
    },
    {
        "key": "installer-recovery",
        "state": "OK" if installer.get("state") in {"tui-release-ready", "graphical-ready"} else "PART",
        "title": "Installer/recovery route",
        "detail": f"Installer state: {installer.get('state', 'unknown')}.",
        "command": "seven installer release",
    },
    {
        "key": "action-runner",
        "state": "OK" if executable("bin/seven-action-runner") else "MISS",
        "title": "Native action execution",
        "detail": "Hub and Settings can run maintenance actions with logs instead of raw terminals.",
        "command": "seven-action-runner --dry-run -- seven status",
    },
    {
        "key": "public-docs",
        "state": "OK" if contains("docs/DISTRIBUTION_AUTONOMY.md", "Lifecycle Contract") else "PART",
        "title": "Lifecycle documentation",
        "detail": "Maintenance policy is documented as a SevenOS product surface.",
        "command": "docs/DISTRIBUTION_AUTONOMY.md",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
missing = sum(1 for item in checks if item["state"] == "MISS")
score = round((ok + part * 0.5) / max(len(checks), 1) * 100)
state = "managed" if missing == 0 and score >= 85 else "partial" if score >= 65 else "foundation"

print(json.dumps({
    "schema": "sevenos.lifecycle.v1",
    "state": state,
    "score": score,
    "summary": {
        "checks": len(checks),
        "ok": ok,
        "partial": part,
        "missing": missing,
        "channel": channel.get("channel", "unknown"),
        "distribution": distribution.get("state", "unknown"),
        "installer": installer.get("state", "unknown"),
    },
    "maintenance_routes": [
        {"intent": "Update apps and system", "surface": "SevenOS Update / SevenStore", "command": "seven update"},
        {"intent": "Repair the OS", "surface": "Seven Doctor / Repair", "command": "seven repair"},
        {"intent": "Protect or recover user state", "surface": "SevenOS Recovery", "command": "seven recovery"},
        {"intent": "Check release readiness", "surface": "SevenOS Distribution", "command": "seven distribution"},
        {"intent": "Prepare installer/recovery", "surface": "SevenOS Installer", "command": "seven installer release"},
    ],
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "next": [item for item in checks if item["state"] != "OK"][:5],
    "commands": {
        "status": "seven lifecycle",
        "doctor": "seven lifecycle doctor",
        "plan": "seven lifecycle plan",
    },
}, indent=2))
PY
  rm -rf "$tmp"
}

print_human() {
  LIFECYCLE_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["LIFECYCLE_JSON"])
summary = data.get("summary", {})
print("SevenOS Lifecycle")
print("=================")
print(f"State:        {data.get('state')}")
print(f"Score:        {data.get('score')}%")
print(f"Channel:      {summary.get('channel')}")
print(f"Distribution: {summary.get('distribution')}")
print(f"Installer:    {summary.get('installer')}")
print()
for item in data.get("maintenance_routes", []):
    print(f"- {item.get('intent')}: {item.get('surface')} -> {item.get('command')}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state', 'MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

print_plan() {
  LIFECYCLE_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["LIFECYCLE_JSON"])
print("SevenOS Lifecycle Plan")
print("======================")
items = data.get("next", [])
if not items:
    print("No pending lifecycle gates.")
else:
    for item in items:
        print(f"- {item.get('title')}: {item.get('command')}")
        print(f"  {item.get('detail')}")
PY
}

payload="$(lifecycle_json)"
case "$ACTION" in
  status|json|doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  plan)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan "$payload"
    fi
    ;;
  *) log_error "Unknown lifecycle action: $ACTION"; usage; exit 1 ;;
esac
