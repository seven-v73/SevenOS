#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

SUPPORT_ROOT="${SEVENOS_SUPPORT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sevenos/support}"

usage() {
  cat <<'EOF'
SevenOS support

Usage:
  seven support [status|plan|doctor|bundle|json] [--json]
  ./scripts/support.sh [status|plan|doctor|bundle|json] [--json]

This creates a SevenOS-first support route. It summarizes health, product state,
recovery, recent events and useful log paths without asking users to know
systemctl, journalctl or individual backend commands first.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|plan|doctor|bundle|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown support option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

support_json() {
  local tmp
  local fast_mode=0
  [[ "${SEVENOS_SUPPORT_FAST:-0}" == "1" ]] && fast_mode=1
  tmp="$(mktemp -d)"
  local pid_health pid_product pid_recovery pid_events
  if [[ "$fast_mode" == "1" ]]; then
    printf '{"schema":"sevenos.health.v1","state":"healthy","score":100}\n' >"$tmp/health.json" &
    pid_health=$!
    printf '{"schema":"sevenos.product.v1","state":"ready","score":100}\n' >"$tmp/product.json" &
    pid_product=$!
    printf '{"schema":"sevenos.recovery.v1","state":"ready","score":100}\n' >"$tmp/recovery.json" &
    pid_recovery=$!
    printf '{"schema":"sevenos.events.summary.v1","total":0}\n' >"$tmp/events.json" &
    pid_events=$!
  else
    env SEVENOS_HEALTH_FAST=1 SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/health.sh" json >"$tmp/health.json" 2>/dev/null || printf '{}\n' >"$tmp/health.json" &
    pid_health=$!
    env SEVENOS_PRODUCT_FAST=1 SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/product.sh" json >"$tmp/product.json" 2>/dev/null || printf '{}\n' >"$tmp/product.json" &
    pid_product=$!
    env SEVENOS_RECOVERY_FAST=1 SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/recovery.sh" json >"$tmp/recovery.json" 2>/dev/null || printf '{}\n' >"$tmp/recovery.json" &
    pid_recovery=$!
    SEVENOS_DRY_RUN=0 timeout 6 "$ROOT_DIR/scripts/events.sh" summary-json >"$tmp/events.json" 2>/dev/null || printf '{}\n' >"$tmp/events.json" &
    pid_events=$!
  fi
  wait "$pid_health" "$pid_product" "$pid_recovery" "$pid_events" || true

  SEVENOS_ROOT="$ROOT_DIR" \
  SUPPORT_ROOT="$SUPPORT_ROOT" \
  HEALTH_JSON="$tmp/health.json" \
  PRODUCT_JSON="$tmp/product.json" \
  RECOVERY_JSON="$tmp/recovery.json" \
  EVENTS_JSON="$tmp/events.json" \
  SEVENOS_SUPPORT_FAST_MODE="$fast_mode" \
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


root = Path(os.environ["SEVENOS_ROOT"])
support_root = Path(os.environ["SUPPORT_ROOT"])
health = load_json("HEALTH_JSON")
product = load_json("PRODUCT_JSON")
recovery = load_json("RECOVERY_JSON")
events = load_json("EVENTS_JSON")

checks = [
    {
        "key": "health",
        "state": "OK" if health.get("schema") == "sevenos.health.v1" and health.get("score", 0) >= 80 else "PART",
        "title": "Health summary",
        "detail": f"{health.get('state', 'unknown')} at {health.get('score', 'unknown')}%.",
        "command": "seven health",
    },
    {
        "key": "product",
        "state": "OK" if product.get("schema") == "sevenos.product.v1" else "PART",
        "title": "Product snapshot",
        "detail": f"{product.get('state', 'unknown')} at {product.get('score', 'unknown')}%.",
        "command": "seven product",
    },
    {
        "key": "recovery",
        "state": "OK" if recovery.get("schema") == "sevenos.recovery.v1" else "PART",
        "title": "Recovery snapshot",
        "detail": f"{recovery.get('state', 'unknown')} at {recovery.get('score', 'unknown')}%.",
        "command": "seven recovery",
    },
    {
        "key": "events",
        "state": "OK" if events.get("schema") in ("sevenos.events.summary.v1", "sevenos.daemon.events.summary.v1") else "PART",
        "title": "Event journal",
        "detail": f"{events.get('total', events.get('count', 0))} recorded event(s).",
        "command": "seven events",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
score = round((ok + part * 0.5) / max(len(checks), 1) * 100)
state = "ready" if score >= 90 else "partial" if score >= 70 else "foundation"

log_paths = [
    str(Path.home() / ".local/state/sevenos/events.jsonl"),
    str(Path.home() / ".local/state/sevenos/actions"),
    str(Path.home() / ".local/share/sevenos/support"),
    "journalctl --user -u sevenos-session.target",
    "journalctl -p warning -b",
]

print(json.dumps({
    "schema": "sevenos.support.v1",
    "state": state,
    "score": score,
    "fast_mode": os.environ.get("SEVENOS_SUPPORT_FAST_MODE") == "1",
    "support_root": str(support_root),
    "privacy": "local-first; support bundles are written to the user account and are not uploaded automatically",
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "log_paths": log_paths,
    "bundle": {
        "command": "seven support bundle",
        "contains": ["health.json", "product.json", "recovery.json", "events.json", "README.txt"],
    },
    "commands": {
        "status": "seven support",
        "bundle": "seven support bundle",
        "health": "seven health",
        "doctor": "seven support doctor",
    },
}, indent=2))
PY
  rm -rf "$tmp"
}

print_human() {
  SUPPORT_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["SUPPORT_JSON"])
print("SevenOS Support")
print("===============")
print(f"State:   {data.get('state')}")
print(f"Score:   {data.get('score')}%")
print(f"Privacy: {data.get('privacy')}")
print(f"Root:    {data.get('support_root')}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state','MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

print_plan() {
  SUPPORT_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["SUPPORT_JSON"])
print("SevenOS Support Plan")
print("====================")
print(f"- Review health: {data.get('commands', {}).get('health')}")
print(f"- Create support bundle: {data.get('commands', {}).get('bundle')}")
print("- Attach the generated local folder only if you choose to share it.")
PY
}

create_bundle() {
  local stamp dir
  stamp="$(date +%Y%m%d-%H%M%S)"
  dir="$SUPPORT_ROOT/$stamp"
  log_info "Creating SevenOS support bundle: $dir"
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$dir"
    printf 'seven health --json > %q\n' "$dir/health.json"
    printf 'seven product --json > %q\n' "$dir/product.json"
    printf 'seven recovery --json > %q\n' "$dir/recovery.json"
    printf 'seven events --json > %q\n' "$dir/events.json"
    return 0
  fi
  mkdir -p "$dir"
  env SEVENOS_HEALTH_FAST=1 "$ROOT_DIR/scripts/health.sh" json >"$dir/health.json" 2>/dev/null || printf '{}\n' >"$dir/health.json"
  env SEVENOS_PRODUCT_FAST=1 "$ROOT_DIR/scripts/product.sh" json >"$dir/product.json" 2>/dev/null || printf '{}\n' >"$dir/product.json"
  env SEVENOS_RECOVERY_FAST=1 "$ROOT_DIR/scripts/recovery.sh" json >"$dir/recovery.json" 2>/dev/null || printf '{}\n' >"$dir/recovery.json"
  "$ROOT_DIR/scripts/events.sh" --json --limit 30 >"$dir/events.json" 2>/dev/null || printf '{}\n' >"$dir/events.json"
  cat >"$dir/README.txt" <<EOF
SevenOS support bundle
Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)

This bundle is local-first. It was not uploaded automatically.
Review files before sharing.
EOF
  log_success "Support bundle ready: $dir"
}

payload="$(support_json)"
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
    SUPPORT_JSON="$payload" python - <<'PY'
import json, os, sys
data = json.loads(os.environ["SUPPORT_JSON"])
sys.exit(0 if data.get("score", 0) >= 90 else 1)
PY
    ;;
  bundle) create_bundle ;;
esac
