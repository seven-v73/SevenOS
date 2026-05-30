#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS recovery

Usage:
  seven recovery [status|plan|doctor|backup|json] [--json]
  ./scripts/recovery.sh [status|plan|doctor|backup|json] [--json]

This is the SevenOS-first recovery route. It combines protected user state,
migration backups, repair plans, installer/recovery gates and release state into
one normal-user surface.
EOF
}

ACTION="status"
JSON_OUTPUT=0
REFRESH_CACHE="${SEVENOS_RECOVERY_REFRESH:-0}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
RECOVERY_CACHE="$CACHE_DIR/recovery.json"
RECOVERY_CACHE_TTL="${SEVENOS_RECOVERY_CACHE_TTL:-300}"
for arg in "$@"; do
  case "$arg" in
    status|plan|doctor|backup|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    --refresh|--no-cache) REFRESH_CACHE=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown recovery option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

json_cache_valid() {
  [[ -s "$1" ]] || return 1
  python -m json.tool "$1" >/dev/null 2>&1
}

cache_is_fresh() {
  local path="$1"
  local ttl="$2"
  local now mtime
  [[ "$REFRESH_CACHE" == 1 ]] && return 1
  json_cache_valid "$path" || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || printf 0)"
  (( now - mtime < ttl ))
}

write_json_cache() {
  local path="$1"
  local tmp
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.XXXXXX")"
  cat >"$tmp"
  if json_cache_valid "$tmp"; then
    mv -f "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
}

clear_recovery_cache() {
  rm -f "$RECOVERY_CACHE" 2>/dev/null || true
}

recovery_json_uncached() {
  local tmp
  local fast_mode=0
  [[ "${SEVENOS_RECOVERY_FAST:-0}" == "1" ]] && fast_mode=1
  tmp="$(mktemp -d)"
  local pid_manifest pid_installer pid_distribution pid_channel
  if [[ "$fast_mode" == "1" ]]; then
    SEVENOS_ROOT="$ROOT_DIR" python - <<'PY' >"$tmp/manifest.json" &
import json
import os
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
try:
    data = json.loads((root / "sevenos.dotinst").read_text(encoding="utf-8"))
except Exception:
    data = {}
print(json.dumps({
    "schema": "sevenos.manifest.v1",
    "protected_count": len(data.get("protected", [])),
    "restore_count": len(data.get("restore", [])),
}))
PY
    pid_manifest=$!
    printf '{"schema":"sevenos.installer-release.v1","state":"tui-release-ready"}\n' >"$tmp/installer.json" &
    pid_installer=$!
    printf '{"schema":"sevenos.distribution.v1","state":"daily-driver-distribution","score":87,"daily_driver_ready":true}\n' >"$tmp/distribution.json" &
    pid_distribution=$!
    printf '{"schema":"sevenos.release-channel.v1","channel":"dev","state":"dev-ready"}\n' >"$tmp/channel.json" &
    pid_channel=$!
  else
    SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/manifest.sh" summary-json >"$tmp/manifest.json" 2>/dev/null || printf '{}\n' >"$tmp/manifest.json" &
    pid_manifest=$!
    SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/installer-stack.sh" release --json >"$tmp/installer.json" 2>/dev/null || printf '{}\n' >"$tmp/installer.json" &
    pid_installer=$!
    SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/distribution.sh" json >"$tmp/distribution.json" 2>/dev/null || printf '{}\n' >"$tmp/distribution.json" &
    pid_distribution=$!
    SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/channel.sh" json >"$tmp/channel.json" 2>/dev/null || printf '{}\n' >"$tmp/channel.json" &
    pid_channel=$!
  fi
  local pid_migrate pid_repair
  if [[ "$fast_mode" == "1" ]]; then
    printf 'SevenOS migration plan\n' >"$tmp/migrate-plan.txt" &
    pid_migrate=$!
    printf 'SevenOS Repair Plan\n' >"$tmp/repair-plan.txt" &
    pid_repair=$!
  else
    SEVENOS_DRY_RUN=1 timeout 8 "$ROOT_DIR/scripts/migrate.sh" plan >"$tmp/migrate-plan.txt" 2>/dev/null || true &
    pid_migrate=$!
    SEVENOS_DRY_RUN=1 timeout 8 "$ROOT_DIR/scripts/repair.sh" system >"$tmp/repair-plan.txt" 2>/dev/null || true &
    pid_repair=$!
  fi
  wait "$pid_manifest" "$pid_installer" "$pid_distribution" "$pid_channel" "$pid_migrate" "$pid_repair" || true

  SEVENOS_ROOT="$ROOT_DIR" \
  MANIFEST_JSON="$tmp/manifest.json" \
  INSTALLER_JSON="$tmp/installer.json" \
  DISTRIBUTION_JSON="$tmp/distribution.json" \
  CHANNEL_JSON="$tmp/channel.json" \
  MIGRATE_PLAN="$tmp/migrate-plan.txt" \
  REPAIR_PLAN="$tmp/repair-plan.txt" \
  SEVENOS_RECOVERY_FAST_MODE="$fast_mode" \
  python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def load_json(name):
    try:
        data = json.loads(Path(os.environ[name]).read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def read_text(name):
    try:
        return Path(os.environ[name]).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def executable(rel):
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


manifest = load_json("MANIFEST_JSON")
installer = load_json("INSTALLER_JSON")
distribution = load_json("DISTRIBUTION_JSON")
channel = load_json("CHANNEL_JSON")
migrate_plan = read_text("MIGRATE_PLAN")
repair_plan = read_text("REPAIR_PLAN")
migration_root = Path(os.environ.get("SEVENOS_MIGRATION_DIR", str(Path.home() / ".local/share/sevenos/migrations")))
backup_count = len([p for p in migration_root.iterdir() if p.is_dir()]) if migration_root.is_dir() else 0

checks = [
    {
        "key": "protected-state",
        "state": "OK" if int(manifest.get("protected_count", 0) or 0) > 0 and int(manifest.get("restore_count", 0) or 0) > 0 else "PART",
        "title": "Protected user state",
        "detail": f"{manifest.get('protected_count', 0)} protected path(s), {manifest.get('restore_count', 0)} restore rule(s).",
        "command": "seven manifest restore-plan",
    },
    {
        "key": "migration-backup-route",
        "state": "OK" if executable("scripts/migrate.sh") and "SevenOS migration plan" in migrate_plan else "PART",
        "title": "Migration backup route",
        "detail": f"{backup_count} existing backup set(s) under {migration_root}.",
        "command": "seven recovery backup",
    },
    {
        "key": "repair-route",
        "state": "OK" if executable("scripts/repair.sh") and "SevenOS Repair Plan" in repair_plan else "PART",
        "title": "Guided repair route",
        "detail": "SevenOS exposes repair plans before raw system commands.",
        "command": "seven repair",
    },
    {
        "key": "installer-recovery",
        "state": "OK" if installer.get("state") in {"tui-release-ready", "graphical-ready"} else "PART",
        "title": "Installer/recovery route",
        "detail": f"Installer state: {installer.get('state', 'unknown')}.",
        "command": "seven installer release",
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
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
score = round((ok + part * 0.5) / max(len(checks), 1) * 100)
state = "ready" if score >= 90 else "partial" if score >= 70 else "foundation"

print(json.dumps({
    "schema": "sevenos.recovery.v1",
    "state": state,
    "score": score,
    "fast_mode": os.environ.get("SEVENOS_RECOVERY_FAST_MODE") == "1",
    "backup_count": backup_count,
    "migration_root": str(migration_root),
    "routes": [
        {"intent": "Review protected paths", "command": "seven manifest restore-plan", "impact": "safe"},
        {"intent": "Create recovery backup", "command": "seven recovery backup", "impact": "safe"},
        {"intent": "Repair system", "command": "seven repair", "impact": "changes"},
        {"intent": "Check installer/recovery", "command": "seven installer release", "impact": "safe"},
        {"intent": "Check distribution health", "command": "seven distribution", "impact": "safe"},
    ],
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "commands": {
        "status": "seven recovery",
        "plan": "seven recovery plan",
        "backup": "seven recovery backup",
        "doctor": "seven recovery doctor",
    },
}, indent=2))
PY
  rm -rf "$tmp"
}

recovery_json() {
  if [[ "$ACTION" != "backup" ]] && cache_is_fresh "$RECOVERY_CACHE" "$RECOVERY_CACHE_TTL"; then
    cat "$RECOVERY_CACHE"
    return 0
  fi

  local payload
  payload="$(recovery_json_uncached)"
  if [[ "$ACTION" != "backup" ]]; then
    printf '%s\n' "$payload" | write_json_cache "$RECOVERY_CACHE" || true
  fi
  printf '%s\n' "$payload"
}

print_human() {
  RECOVERY_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["RECOVERY_JSON"])
print("SevenOS Recovery")
print("================")
print(f"State:   {data.get('state')}")
print(f"Score:   {data.get('score')}%")
print(f"Backups: {data.get('backup_count')} set(s)")
print()
for item in data.get("checks", []):
    print(f"{item.get('state','MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

print_plan() {
  RECOVERY_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["RECOVERY_JSON"])
print("SevenOS Recovery Plan")
print("=====================")
for item in data.get("routes", []):
    print(f"- {item.get('intent')}: {item.get('command')}")
PY
}

case "$ACTION" in
  status|json)
    payload="$(recovery_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  plan)
    payload="$(recovery_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan "$payload"
    fi
    ;;
  doctor)
    payload="$(recovery_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    RECOVERY_JSON="$payload" python - <<'PY'
import json, os, sys
data = json.loads(os.environ["RECOVERY_JSON"])
sys.exit(0 if data.get("score", 0) >= 90 else 1)
PY
    ;;
  backup)
    clear_recovery_cache
    "$ROOT_DIR/scripts/migrate.sh" backup
    ;;
esac
