#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/shield"
STATE_FILE="$STATE_DIR/performance.json"

usage() {
  cat <<'EOF'
SevenOS Shield Performance Mode

Usage:
  seven shield performance [--json]
  seven shield performance apply
  seven shield performance reset

Applies a calmer Hyprland runtime profile for cyber GUI tools: lower blur,
fewer expensive visual effects and tighter gaps while preserving readability.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|performance) ACTION="status" ;;
    apply|reset) ACTION="$1" ;;
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown performance option: $1"; usage; exit 1 ;;
  esac
  shift
done

hypr() {
  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl "$@" >/dev/null 2>&1 || true
  fi
}

write_state() {
  local mode="$1"
  mkdir -p "$STATE_DIR"
  MODE="$mode" python - <<'PY' >"$STATE_FILE"
import json
import os
from datetime import datetime, timezone
print(json.dumps({
    "schema": "sevenos.shield-performance.v1",
    "mode": os.environ["MODE"],
    "updated_at": datetime.now(timezone.utc).isoformat(),
    "effects": {
        "shield": ["reduced blur", "tighter gaps", "faster workspace transitions"],
        "normal": ["SevenOS default visual profile"],
    }.get(os.environ["MODE"], []),
}, indent=2))
PY
}

status_json() {
  if [[ -s "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    printf '{"schema":"sevenos.shield-performance.v1","mode":"normal","effects":[]}\n'
  fi
}

apply_mode() {
  hypr keyword general:gaps_in 4
  hypr keyword general:gaps_out 8
  hypr keyword decoration:rounding 18
  hypr keyword decoration:dim_inactive true
  hypr keyword decoration:dim_strength 0.08
  hypr keyword decoration:blur:enabled false
  hypr keyword animations:enabled true
  hypr keyword animation "workspaces, 1, 4, sevenWorkspace, slidefade 10%"
  write_state shield
  "$ROOT_DIR/scripts/events.sh" log --source shield --type performance --state OK --message "Shield performance mode applied" --command "seven shield performance apply" >/dev/null || true
}

reset_mode() {
  hypr reload
  write_state normal
  "$ROOT_DIR/scripts/events.sh" log --source shield --type performance --state OK --message "Shield performance mode reset" --command "seven shield performance reset" >/dev/null || true
}

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      status_json
    else
      status_json | python -c 'import json,sys; data=json.load(sys.stdin); print("SevenOS Shield Performance"); print("=========================="); print("Mode: {}".format(data.get("mode"))); [print("  - {}".format(x)) for x in data.get("effects", [])]'
    fi
    ;;
  apply)
    apply_mode
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_json; else log_success "Shield performance mode applied"; fi
    ;;
  reset)
    reset_mode
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_json; else log_success "Shield performance mode reset"; fi
    ;;
esac
