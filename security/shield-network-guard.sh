#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0
WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
STATE_DIR="$WORKSPACE/.sevenos"
GUARD_FILE="$STATE_DIR/network-guard.json"
PERSONA_FILE="$STATE_DIR/persona.json"
SCOPE_FILE="$STATE_DIR/scope.json"

usage() {
  cat <<'EOF'
SevenOS Shield Network Guard

Usage:
  seven shield network [--json]
  seven shield network apply [--json]

Network Guard maps Shield personas to a visible network posture. It is safe by
default: it records and audits the expected posture, and only reports what would
need elevated firewall/VPN/Tor changes.
EOF
}

shift_if_action() {
  case "${1:-}" in
    status|network) ACTION="status"; shift ;;
    apply) ACTION="apply"; shift ;;
  esac
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --json|json) JSON_OUTPUT=1 ;;
      status|network|apply) [[ "$1" == "network" ]] && ACTION="status" || ACTION="$1" ;;
      -h|--help|help) usage; exit 0 ;;
      *) log_error "Unknown Shield network option: $1"; usage; exit 1 ;;
    esac
    shift
  done
}

state_json() {
  mkdir -p "$STATE_DIR"
  ROOT_DIR="$ROOT_DIR" WORKSPACE="$WORKSPACE" GUARD_FILE="$GUARD_FILE" PERSONA_FILE="$PERSONA_FILE" SCOPE_FILE="$SCOPE_FILE" python - <<'PY'
import json
import os
import shutil
import subprocess
from pathlib import Path

workspace = Path(os.environ["WORKSPACE"])
persona_file = Path(os.environ["PERSONA_FILE"])
scope_file = Path(os.environ["SCOPE_FILE"])
guard_file = Path(os.environ["GUARD_FILE"])

def load_json(path, fallback):
    if not path.is_file():
        return fallback
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        fallback["state"] = "INVALID"
        return fallback

persona = load_json(persona_file, {
    "active": {"key": "safe", "title": "Safe Audit", "network": "normal-guarded", "isolation": "standard-sandbox"},
    "session": "persistent",
})
scope = load_json(scope_file, {"state": "MISS", "active": False, "targets": []})
if scope.get("state") in (None, "", "MISS") and scope_file.is_file():
    scope["state"] = "ACTIVE" if scope.get("active") else "DRAFT"
active = persona.get("active") or {}
key = active.get("key", "safe")
policy = active.get("network", "normal-guarded")

def cmd_exists(name):
    return shutil.which(name) is not None

def systemctl_active(unit):
    return subprocess.run(["systemctl", "is-active", "--quiet", unit], check=False).returncode == 0

def nmcli_vpn():
    if not cmd_exists("nmcli"):
        return {"state": "MISS", "active": False}
    result = subprocess.run(["nmcli", "-t", "-f", "TYPE,STATE", "connection", "show", "--active"], text=True, capture_output=True, check=False)
    active = any(line.startswith("vpn:") for line in result.stdout.splitlines())
    return {"state": "OK", "active": active}

required = []
if policy in ("vpn-recommended", "vpn-or-tor-recommended"):
    required.append("vpn-or-tor")
if policy in ("offline-preferred", "offline-enforced"):
    required.append("offline-lab")
if policy in ("scope-required", "scoped-lab"):
    required.append("active-scope")

scope_active = bool(scope.get("active")) and bool(scope.get("targets"))
checks = {
    "ufw": "OK" if systemctl_active("ufw.service") else "MISS",
    "nft": "OK" if cmd_exists("nft") else "MISS",
    "tor": "OK" if cmd_exists("tor") or systemctl_active("tor.service") else "MISS",
    "proxychains": "OK" if cmd_exists("proxychains") or cmd_exists("proxychains4") else "MISS",
    "vpn": nmcli_vpn(),
    "scope": "OK" if scope_active else "BLOCKED",
}

blocked = []
if "active-scope" in required and not scope_active:
    blocked.append("active scope with targets is required")
if "vpn-or-tor" in required and not (checks["vpn"].get("active") or checks["tor"] == "OK"):
    blocked.append("VPN or Tor is recommended for this persona")
if "offline-lab" in required and key == "malware":
    blocked.append("malware persona must stay offline; use VM/container offline lab before sample work")

payload = {
    "schema": "sevenos.shield-network-guard.v1",
    "state": "OK" if not blocked else "ATTENTION",
    "workspace": str(workspace),
    "persona": {"key": key, "title": active.get("title"), "policy": policy, "isolation": active.get("isolation")},
    "scope": {"state": scope.get("state", "MISS"), "active": bool(scope.get("active")), "target_count": len(scope.get("targets") or [])},
    "required": required,
    "checks": checks,
    "blocked": blocked,
    "enforcement": {
        "mode": "advisory-safe",
        "reason": "Firewall/VPN/Tor changes can affect the whole host and require explicit admin authorization.",
        "future": "nftables persona profiles, VPN kill switch, Tor/proxy routing and lab-only networks.",
    },
    "path": str(guard_file),
}
print(json.dumps(payload, indent=2))
PY
}

apply_guard() {
  local payload
  payload="$(state_json)"
  if is_dry_run; then
    printf 'write %q\n' "$GUARD_FILE"
    return 0
  fi
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$payload" >"$GUARD_FILE"
  "$ROOT_DIR/scripts/events.sh" log \
    --source shield \
    --type network \
    --state OK \
    --message "Shield network guard evaluated" \
    --command "seven shield network apply" >/dev/null || true
  printf '%s\n' "$payload"
}

human_status() {
  local payload
  payload="$(state_json)"
  SHIELD_NETWORK_JSON="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["SHIELD_NETWORK_JSON"])
persona = data.get("persona", {})
print("SevenOS Shield Network Guard")
print("============================")
print(f"State:    {data.get('state')}")
print(f"Persona:  {persona.get('title')} ({persona.get('key')})")
print(f"Policy:   {persona.get('policy')}")
print(f"Scope:    {data.get('scope', {}).get('state')} · targets={data.get('scope', {}).get('target_count')}")
print()
for item in data.get("blocked", []):
    print(f"  attention: {item}")
if not data.get("blocked"):
    print("  network posture is coherent for the active persona")
print()
print("Apply records this posture; elevated firewall/VPN changes remain explicit.")
PY
}

shift_if_action "$@"

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then state_json; else human_status; fi
    ;;
  apply)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then apply_guard; else apply_guard >/dev/null; log_success "Shield network guard recorded"; human_status; fi
    ;;
esac
