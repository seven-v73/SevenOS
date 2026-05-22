#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS Smoke Gate

Usage:
  seven smoke [status|doctor|plan|json] [--json]
  ./scripts/smoke.sh [status|doctor|plan|json] [--json]

Smoke is the fast public-product gate. It checks the SevenOS-first contracts
that keep the OS usable without running the full developer UX audit.
EOF
}

for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown smoke option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

run_json_file() {
  local timeout_value="$1"
  local output_file="$2"
  shift 2
  SEVENOS_DRY_RUN=0 timeout "$timeout_value" "$@" >"$output_file" 2>/dev/null || printf '{}\n' >"$output_file"
}

smoke_json() {
  local tmp
  tmp="$(mktemp -d)"

  run_json_file 14 "$tmp/state.json" "$ROOT_DIR/bin/seven" state --json &
  local pid_state=$!
  run_json_file 8 "$tmp/about.json" "$ROOT_DIR/scripts/about.sh" json &
  local pid_about=$!
  run_json_file 6 "$tmp/identity.json" "$ROOT_DIR/scripts/identity.sh" doctor --json &
  local pid_identity=$!
  run_json_file 12 "$tmp/distribution.json" env SEVENOS_DISTRIBUTION_FAST=1 "$ROOT_DIR/scripts/distribution.sh" json &
  local pid_distribution=$!
  run_json_file 8 "$tmp/health.json" env SEVENOS_HEALTH_FAST=1 "$ROOT_DIR/scripts/health.sh" json &
  local pid_health=$!
  run_json_file 8 "$tmp/product.json" env SEVENOS_PRODUCT_FAST=1 "$ROOT_DIR/scripts/product.sh" json &
  local pid_product=$!
  run_json_file 6 "$tmp/actions.json" "$ROOT_DIR/scripts/actions.sh" --json &
  local pid_actions=$!

  wait "$pid_state" "$pid_about" "$pid_identity" "$pid_distribution" "$pid_health" "$pid_product" "$pid_actions" || true

  SEVENOS_ROOT="$ROOT_DIR" \
  STATE_JSON="$tmp/state.json" \
  ABOUT_JSON="$tmp/about.json" \
  IDENTITY_JSON="$tmp/identity.json" \
  DISTRIBUTION_JSON="$tmp/distribution.json" \
  HEALTH_JSON="$tmp/health.json" \
  PRODUCT_JSON="$tmp/product.json" \
  ACTIONS_JSON="$tmp/actions.json" \
  python - <<'PY'
import json
import os
from pathlib import Path


def load(name):
    path = Path(os.environ[name])
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    return value if isinstance(value, dict) else {}


root = Path(os.environ["SEVENOS_ROOT"])
state = load("STATE_JSON")
about = load("ABOUT_JSON")
identity = load("IDENTITY_JSON")
distribution = load("DISTRIBUTION_JSON")
health = load("HEALTH_JSON")
product = load("PRODUCT_JSON")
actions = load("ACTIONS_JSON")

for name, value in (
    ("about", about),
    ("distribution", distribution),
    ("health", health),
    ("product", product),
):
    fallback = state.get(name)
    if isinstance(fallback, dict):
        if name == "about":
            about = fallback
        elif name == "distribution":
            distribution = fallback
        elif name == "health":
            health = fallback
        elif name == "product":
            product = fallback

action_items = actions.get("actions", [])
if not isinstance(action_items, list):
    action_items = []
action_ids = {item.get("id") for item in action_items if isinstance(item, dict)}

required_state_keys = {
    "about",
    "product",
    "distribution",
    "health",
    "support",
    "identity",
    "platform",
    "mask",
    "surfaces",
    "routes",
}

checks = [
    {
        "key": "seven-state",
        "state": "OK" if state.get("schema") == "sevenos.state.v1" and required_state_keys.issubset(state) else "PART",
        "title": "Unified SevenOS state",
        "detail": "Native surfaces can read one product snapshot without calling backend tools individually.",
        "command": "seven state --json",
    },
    {
        "key": "about-contract",
        "state": "OK" if about.get("schema") == "sevenos.about.v1" and about.get("about_ready") else "PART",
        "title": "Public SevenOS identity",
        "detail": f"About state: {about.get('state', 'unknown')}.",
        "command": "seven about doctor",
    },
    {
        "key": "identity-contract",
        "state": "OK" if identity.get("schema") == "sevenos.identity-doctor.v1" and identity.get("state") == "ready" else "PART",
        "title": "Visual identity gate",
        "detail": f"Identity state: {identity.get('state', 'unknown')}; score: {identity.get('score', 'unknown')}%.",
        "command": "seven identity doctor",
    },
    {
        "key": "distribution-contract",
        "state": "OK" if distribution.get("daily_driver_ready") else "PART",
        "title": "Distribution autonomy",
        "detail": f"Distribution: {distribution.get('state', 'unknown')} at {distribution.get('score', 'unknown')}%.",
        "command": "seven distribution",
    },
    {
        "key": "health-contract",
        "state": "OK" if health.get("daily_ready") or health.get("state") in {"healthy", "ready", "ready-with-actions"} else "PART",
        "title": "Daily health",
        "detail": f"Health state: {health.get('state', 'unknown')}; score: {health.get('score', 'unknown')}%.",
        "command": "seven health doctor",
    },
    {
        "key": "product-facade",
        "state": "OK" if product.get("schema") == "sevenos.product.v1" and product.get("daily_driver_ready") else "PART",
        "title": "Product facade",
        "detail": f"Product state: {product.get('state', 'unknown')}; score: {product.get('score', 'unknown')}%.",
        "command": "seven product",
    },
    {
        "key": "action-registry",
        "state": "OK" if {"smoke.status", "smoke.doctor", "smoke.json"}.issubset(action_ids) else "PART",
        "title": "Native action registry",
        "detail": f"{len(action_items)} action(s) exposed to Hub, Spotlight and Settings.",
        "command": "seven actions --json",
    },
    {
        "key": "public-copy",
        "state": "OK" if (root / "README.md").read_text(encoding="utf-8").lstrip().startswith("# SevenOS") else "PART",
        "title": "SevenOS-first public copy",
        "detail": "README and public surfaces present SevenOS before implementation layers.",
        "command": "seven mask doctor",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
missing = sum(1 for item in checks if item["state"] == "MISS")
score = round((ok + part * 0.35) / max(len(checks), 1) * 100)
state_name = "ready" if score >= 90 and missing == 0 else "partial" if score >= 70 else "blocked"
issues = [
    {
        "key": item["key"],
        "state": item["state"],
        "title": item["title"],
        "reason": item["detail"],
        "command": item["command"],
    }
    for item in checks
    if item["state"] != "OK"
]

print(json.dumps({
    "schema": "sevenos.smoke.v1",
    "state": state_name,
    "score": score,
    "fast_gate": True,
    "purpose": "fast public SevenOS distribution smoke gate",
    "checks": checks,
    "summary": {
        "ok": ok,
        "partial": part,
        "missing": missing,
        "total": len(checks),
    },
    "issues": issues,
    "commands": {
        "status": "seven smoke",
        "doctor": "seven smoke doctor",
        "deep_audit": "./scripts/ux-check.sh",
    },
}, indent=2))
PY
}

print_status() {
  SMOKE_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["SMOKE_JSON"])
print("SevenOS Smoke Gate")
print("==================")
print(f"State: {data.get('state', 'unknown')}")
print(f"Score: {data.get('score', 0)}%")
print()
for item in data.get("checks", []):
    print(f"  {item.get('state', '??'):4} {item.get('title', item.get('key'))}")
    print(f"       {item.get('detail', '')}")
PY
}

print_plan() {
  SMOKE_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["SMOKE_JSON"])
print("SevenOS Smoke Plan")
print("==================")
issues = data.get("issues", [])
if not issues:
    print("No smoke blockers.")
else:
    for item in issues:
        print(f"- {item.get('title')} [{item.get('state')}]")
        print(f"  {item.get('reason')}")
        print(f"  Run: {item.get('command')}")
PY
}

payload="$(smoke_json)"

if [[ "$JSON_OUTPUT" == "1" ]]; then
  printf '%s\n' "$payload"
  exit 0
fi

case "$ACTION" in
  status) print_status "$payload" ;;
  plan) print_plan "$payload" ;;
  doctor)
    print_status "$payload"
    score="$(SMOKE_JSON="$payload" python - <<'PY'
import json, os
print(json.loads(os.environ["SMOKE_JSON"]).get("score", 0))
PY
)"
    if (( score >= 90 )); then
      log_success "SevenOS smoke gate is ready."
      exit 0
    fi
    log_error "SevenOS smoke gate still has blockers."
    exit 1
    ;;
  json) printf '%s\n' "$payload" ;;
esac
