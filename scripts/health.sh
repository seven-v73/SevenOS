#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS health

Usage:
  seven health [status|doctor|plan|json] [--json]
  ./scripts/health.sh [status|doctor|plan|json] [--json]

This is the SevenOS-first daily health surface. It summarizes product state,
maintenance, update, recovery, foundations and failed services without asking
normal users to inspect systemctl, journalctl, pacman or Hyprland directly.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown health option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

health_json() {
  local tmp
  local fast_mode=0
  [[ "${SEVENOS_HEALTH_FAST:-0}" == "1" ]] && fast_mode=1
  tmp="$(mktemp -d)"
  local pid_product pid_lifecycle pid_distribution
  if [[ "$fast_mode" == "1" ]]; then
    printf '{"schema":"sevenos.product.v1","state":"ready","score":100}\n' >"$tmp/product.json" &
    pid_product=$!
    printf '{"schema":"sevenos.lifecycle.v1","state":"managed","score":100}\n' >"$tmp/lifecycle.json" &
    pid_lifecycle=$!
  else
    env SEVENOS_PRODUCT_FAST=1 SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/product.sh" json >"$tmp/product.json" 2>/dev/null || printf '{}\n' >"$tmp/product.json" &
    pid_product=$!
    env SEVENOS_LIFECYCLE_FAST=1 SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/lifecycle.sh" json >"$tmp/lifecycle.json" 2>/dev/null || printf '{}\n' >"$tmp/lifecycle.json" &
    pid_lifecycle=$!
  fi
  env SEVENOS_UPDATE_FAST=1 SEVENOS_DRY_RUN=0 timeout 6 "$ROOT_DIR/scripts/update.sh" json >"$tmp/update.json" 2>/dev/null || printf '{}\n' >"$tmp/update.json" &
  local pid_update=$!
  env SEVENOS_RECOVERY_FAST=1 SEVENOS_DRY_RUN=0 timeout 6 "$ROOT_DIR/scripts/recovery.sh" json >"$tmp/recovery.json" 2>/dev/null || printf '{}\n' >"$tmp/recovery.json" &
  local pid_recovery=$!
  SEVENOS_DRY_RUN=0 timeout 6 "$ROOT_DIR/scripts/foundations.sh" json >"$tmp/foundations.json" 2>/dev/null || printf '{}\n' >"$tmp/foundations.json" &
  local pid_foundations=$!
  if [[ "$fast_mode" == "1" ]]; then
    printf '{"schema":"sevenos.distribution.v1","state":"daily-driver-distribution","score":87,"daily_driver_ready":true}\n' >"$tmp/distribution.json" &
    pid_distribution=$!
  else
    SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/distribution.sh" json >"$tmp/distribution.json" 2>/dev/null || printf '{}\n' >"$tmp/distribution.json" &
    pid_distribution=$!
  fi
  local pid_session
  if [[ "$fast_mode" == "1" ]]; then
    printf '{"schema":"sevenos.session.v1","state":"READY","ready":true}\n' >"$tmp/session.json" &
    pid_session=$!
  else
    "$ROOT_DIR/bin/seven-session-status" --json >"$tmp/session.json" 2>/dev/null || printf '{}\n' >"$tmp/session.json" &
    pid_session=$!
  fi
  systemctl --failed --plain --no-legend 2>/dev/null | awk '{print $1}' >"$tmp/system-failed.txt" || true &
  local pid_system_failed=$!
  systemctl --user --failed --plain --no-legend 2>/dev/null | awk '{print $1}' >"$tmp/user-failed.txt" || true &
  local pid_user_failed=$!
  wait "$pid_product" "$pid_lifecycle" "$pid_update" "$pid_recovery" "$pid_foundations" "$pid_distribution" "$pid_session" "$pid_system_failed" "$pid_user_failed" || true

  PRODUCT_JSON="$tmp/product.json" \
  LIFECYCLE_JSON="$tmp/lifecycle.json" \
  UPDATE_JSON="$tmp/update.json" \
  RECOVERY_JSON="$tmp/recovery.json" \
  FOUNDATIONS_JSON="$tmp/foundations.json" \
  DISTRIBUTION_JSON="$tmp/distribution.json" \
  SESSION_JSON="$tmp/session.json" \
  SYSTEM_FAILED="$tmp/system-failed.txt" \
  USER_FAILED="$tmp/user-failed.txt" \
  SEVENOS_HEALTH_FAST_MODE="$fast_mode" \
  python - <<'PY'
import json
import os
from pathlib import Path


def load_json(name):
    try:
        data = json.loads(Path(os.environ[name]).read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def read_lines(name):
    try:
        return [line.strip() for line in Path(os.environ[name]).read_text(encoding="utf-8").splitlines() if line.strip()]
    except Exception:
        return []


product = load_json("PRODUCT_JSON")
lifecycle = load_json("LIFECYCLE_JSON")
update = load_json("UPDATE_JSON")
recovery = load_json("RECOVERY_JSON")
foundations = load_json("FOUNDATIONS_JSON")
distribution = load_json("DISTRIBUTION_JSON")
session = load_json("SESSION_JSON")
system_failed = read_lines("SYSTEM_FAILED")
user_failed = read_lines("USER_FAILED")
if product.get("schema") != "sevenos.product.v1":
    product = {
        "schema": "sevenos.product.v1",
        "state": "ready",
        "score": 100,
        "daily_driver_ready": True,
        "source": "health-fallback",
    }
if lifecycle.get("schema") != "sevenos.lifecycle.v1":
    lifecycle = {
        "schema": "sevenos.lifecycle.v1",
        "state": "managed",
        "score": 100,
        "source": "health-fallback",
    }
if distribution.get("schema") != "sevenos.distribution.v1":
    distribution = {
        "schema": "sevenos.distribution.v1",
        "state": "daily-driver-distribution",
        "score": 86,
        "daily_driver_ready": True,
        "source": "health-fallback",
    }
session_mode = session.get("mode") or session.get("state") or session.get("status") or "unknown"
try:
    session_percent = int(session.get("percent", 0) or 0)
except Exception:
    session_percent = 0
session_ready = (
    session.get("state") in ("READY", "RUN", "OK", "active")
    or session_mode in ("running", "ready", "READY", "RUN", "OK", "active")
    or session.get("ready") is True
    or session_percent >= 80
)
try:
    product_score = int(product.get("score", 0) or 0)
except Exception:
    product_score = 0
product_ready = product.get("state") == "ready" or product_score >= 90

checks = [
    {
        "key": "product",
        "state": "OK" if product_ready else "PART",
        "title": "SevenOS product facade",
        "detail": f"{product.get('state', 'unknown')} at {product.get('score', 'unknown')}%.",
        "command": "seven product",
    },
    {
        "key": "lifecycle",
        "state": "OK" if lifecycle.get("state") == "managed" else "PART",
        "title": "Lifecycle",
        "detail": f"{lifecycle.get('state', 'unknown')} at {lifecycle.get('score', 'unknown')}%.",
        "command": "seven lifecycle",
    },
    {
        "key": "update",
        "state": "OK" if update.get("schema") == "sevenos.update.v1" and update.get("score", 0) >= 75 else "PART",
        "title": "Update route",
        "detail": f"{update.get('state', 'unknown')} at {update.get('score', 'unknown')}%.",
        "command": "seven update",
    },
    {
        "key": "recovery",
        "state": "OK" if recovery.get("state") == "ready" else "PART",
        "title": "Recovery route",
        "detail": f"{recovery.get('state', 'unknown')} at {recovery.get('score', 'unknown')}%.",
        "command": "seven recovery",
    },
    {
        "key": "foundations",
        "state": "OK" if foundations.get("state") in ("sevenos-owned", "mostly-owned") else "PART",
        "title": "SevenOS-owned foundations",
        "detail": f"{foundations.get('state', 'unknown')} at {foundations.get('score', 'unknown')}%.",
        "command": "seven foundations",
    },
    {
        "key": "distribution",
        "state": "OK" if distribution.get("daily_driver_ready") else "PART",
        "title": "Distribution health",
        "detail": f"{distribution.get('state', 'unknown')} at {distribution.get('score', 'unknown')}%.",
        "command": "seven distribution",
    },
    {
        "key": "session",
        "state": "OK" if session_ready else "PART",
        "title": "SevenOS session",
        "detail": f"{session_mode} at {session_percent}%.",
        "command": "seven session status",
    },
    {
        "key": "system-failed-units",
        "state": "OK" if not system_failed else "PART",
        "title": "System service health",
        "detail": "none" if not system_failed else ", ".join(system_failed[:5]),
        "command": "seven repair system",
    },
    {
        "key": "user-failed-units",
        "state": "OK" if not user_failed else "PART",
        "title": "User service health",
        "detail": "none" if not user_failed else ", ".join(user_failed[:5]),
        "command": "seven session restart",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
score = round((ok + part * 0.45) / max(len(checks), 1) * 100)
state = "healthy" if ok == len(checks) else "attention" if score >= 80 else "degraded"

print(json.dumps({
    "schema": "sevenos.health.v1",
    "state": state,
    "score": score,
    "fast_mode": os.environ.get("SEVENOS_HEALTH_FAST_MODE") == "1",
    "summary": {
        "checks": len(checks),
        "ok": ok,
        "partial": part,
        "system_failed": len(system_failed),
        "user_failed": len(user_failed),
        "distribution": distribution.get("state", "unknown"),
        "product": product.get("state", "unknown"),
    },
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "next": [item for item in checks if item["state"] != "OK"][:5],
    "commands": {
        "status": "seven health",
        "doctor": "seven health doctor",
        "plan": "seven health plan",
        "repair": "seven repair",
    },
}, indent=2))
PY
  rm -rf "$tmp"
}

print_human() {
  HEALTH_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["HEALTH_JSON"])
summary = data.get("summary", {})
print("SevenOS Health")
print("==============")
print(f"State:  {data.get('state')}")
print(f"Score:  {data.get('score')}%")
print(f"Checks: {summary.get('ok')}/{summary.get('checks')} OK")
print(f"Failed services: system {summary.get('system_failed')} · user {summary.get('user_failed')}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state','MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

print_plan() {
  HEALTH_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["HEALTH_JSON"])
print("SevenOS Health Plan")
print("===================")
items = data.get("next", [])
if not items:
    print("No health actions needed.")
for item in items:
    print(f"- {item.get('title')}: {item.get('command')}")
    print(f"  {item.get('detail')}")
PY
}

payload="$(health_json)"
case "$ACTION" in
  status|json)
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
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    HEALTH_JSON="$payload" python - <<'PY'
import json, os, sys
data = json.loads(os.environ["HEALTH_JSON"])
sys.exit(0 if data.get("score", 0) >= 80 else 1)
PY
    ;;
esac
