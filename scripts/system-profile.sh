#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
YES=0

usage() {
  cat <<'EOF'
SevenOS System Profile
======================

Usage:
  seven system-profile [status|apply|doctor] [--json] [--yes]
  ./scripts/system-profile.sh [status|apply|doctor] [--json] [--yes]
  ./install.sh system-profile --yes

Ensures Equinox is the host-system/admin side of SevenOS and all other mini OS
profiles keep their container boundaries.
EOF
}

host_home() {
  local home="${SEVENOS_HOST_HOME:-$HOME}"
  if [[ -n "${SEVENOS_HOST_HOME:-}" ]]; then
    printf '%s\n' "$home"
    return 0
  fi
  case "$home" in
    */.local/share/sevenos/profile-containers/*/home)
      printf '%s\n' "${home%%/.local/share/sevenos/profile-containers/*}"
      return 0
      ;;
  esac
  if [[ -n "${USER:-}" && -d "/home/$USER" ]]; then
    printf '/home/%s\n' "$USER"
  else
    printf '%s\n' "$home"
  fi
}

for arg in "$@"; do
  case "$arg" in
    status|apply|doctor) ACTION="$arg" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done

HOST_HOME="$(host_home)"
STATE_DIR="${SEVENOS_HOST_CONFIG_HOME:-$HOST_HOME/.config}/sevenos"

isolation_json() {
  if [[ -s "$STATE_DIR/profile-isolation.json" ]]; then
    cat "$STATE_DIR/profile-isolation.json"
  else
    SEVENOS_DRY_RUN=1 SEVENOS_HOST_HOME="$HOST_HOME" "$ROOT_DIR/scripts/profile-isolation.sh" apply equinox --yes --json
  fi
}

contract_json() {
  SYSTEM_PROFILE_ACTION="$ACTION" \
  SYSTEM_PROFILE_STATE_DIR="$STATE_DIR" \
  SYSTEM_PROFILE_HOST_HOME="$HOST_HOME" \
  SYSTEM_PROFILE_ROOT="$ROOT_DIR" \
  python - <<'PY'
import json
import os
import shutil
from pathlib import Path

action = os.environ.get("SYSTEM_PROFILE_ACTION", "status")
state_dir = Path(os.environ["SYSTEM_PROFILE_STATE_DIR"])
host_home = Path(os.environ["SYSTEM_PROFILE_HOST_HOME"])
root = Path(os.environ["SYSTEM_PROFILE_ROOT"])

try:
    data = json.loads((state_dir / "profile-isolation.json").read_text(encoding="utf-8"))
except Exception:
    data = {}

containers = data.get("profile_containers") or {}
strict = data.get("strict_runtime") or {}
equinox = containers.get("equinox") or {}
equinox_runtime = strict.get("equinox") or {}
other_containers = {
    key: item for key, item in containers.items()
    if key != "equinox" and isinstance(item, dict)
}

checks = {
    "schema": data.get("schema") == "sevenos.profile-isolation.v1",
    "equinox_state": equinox.get("state") == "system",
    "equinox_launch_mode": equinox.get("launch_mode") == "host-system",
    "equinox_home": equinox.get("home") in ("", None, str(host_home)) or Path(str(equinox.get("home"))).resolve() == host_home.resolve(),
    "equinox_engine": equinox_runtime.get("engine") == "host",
    "equinox_mode": equinox_runtime.get("isolation_mode") == "system",
    "equinox_app_data": equinox_runtime.get("app_data") == "host-home-cache-data",
    "other_profiles_containerized": bool(other_containers) and all(
        item.get("launch_mode") == "available-via-seven-profile-run-container"
        for item in other_containers.values()
    ),
    "package_manager_direct": data.get("strict_boundaries", {}).get("package_manager_guard", "").find("direct in Equinox") >= 0,
}
ready = all(checks.values())

payload = {
    "schema": "sevenos.system-profile.v1",
    "action": action,
    "ready": ready,
    "host_home": str(host_home),
    "state_dir": str(state_dir),
    "system_profile": {
        "key": "equinox",
        "contract": "host-system",
        "state": equinox.get("state", "missing"),
        "launch_mode": equinox.get("launch_mode", "missing"),
        "engine": equinox_runtime.get("engine", equinox.get("engine", "missing")),
        "isolation_mode": equinox_runtime.get("isolation_mode", "missing"),
        "home": equinox.get("home", ""),
    },
    "mini_os_profiles": {
        key: {
            "launch_mode": item.get("launch_mode", ""),
            "home": item.get("home", ""),
            "engine": item.get("engine", ""),
        }
        for key, item in sorted(other_containers.items())
    },
    "checks": checks,
    "commands": {
        "apply": "seven system-profile apply --yes",
        "isolation": "seven profile isolation apply equinox --yes",
        "health": "seven profile health",
        "manifest": "seven-profile-run --profile equinox --manifest",
    },
    "paths": {
        "isolation": str(state_dir / "profile-isolation.json"),
        "env": str(state_dir / "profile-isolation.env"),
        "runner": str(root / "bin/seven-profile-run"),
    },
    "tools": {
        "bubblewrap": bool(shutil.which("bwrap")),
        "pacman": bool(shutil.which("pacman")),
    },
}
print(json.dumps(payload, indent=2))
PY
}

apply_contract() {
  if is_dry_run; then
    printf 'would activate Equinox and apply host-system profile isolation\n'
    return 0
  fi
  "$ROOT_DIR/profiles/profile-manager.sh" activate equinox >/dev/null
  "$ROOT_DIR/scripts/profile-isolation.sh" apply equinox --yes >/dev/null
}

print_human() {
  SYSTEM_PROFILE_PAYLOAD="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["SYSTEM_PROFILE_PAYLOAD"])
system = data.get("system_profile", {})
print("SevenOS System Profile")
print("======================")
print(f"ready:    {'yes' if data.get('ready') else 'no'}")
print(f"host:     {data.get('host_home')}")
print(f"equinox:  {system.get('state')} · {system.get('launch_mode')} · {system.get('engine')}")
print()
print("Mini OS profiles:")
for key, item in data.get("mini_os_profiles", {}).items():
    print(f"- {key:<8} {item.get('launch_mode')}")
if not data.get("ready"):
    print()
    print(f"repair:   {data.get('commands', {}).get('apply')}")
PY
}

case "$ACTION" in
  apply)
    apply_contract
    payload="$(contract_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  status|doctor)
    payload="$(contract_json)"
    if [[ "$ACTION" == "doctor" ]]; then
      if [[ "$JSON_OUTPUT" -eq 1 ]]; then
        printf '%s\n' "$payload"
      else
        print_human "$payload"
      fi
      SYSTEM_PROFILE_PAYLOAD="$payload" python - <<'PY'
import json
import os
raise SystemExit(0 if json.loads(os.environ["SYSTEM_PROFILE_PAYLOAD"]).get("ready") else 1)
PY
    else
      if [[ "$JSON_OUTPUT" -eq 1 ]]; then
        printf '%s\n' "$payload"
      else
        print_human "$payload"
      fi
    fi
    ;;
  *)
    log_error "Unknown system-profile action: $ACTION"
    usage
    exit 1
    ;;
esac
