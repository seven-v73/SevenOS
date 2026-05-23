#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0
OWNER=""
ENGAGEMENT=""
TIME_WINDOW=""
TARGETS=()
EXCLUDED=()

WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
STATE_DIR="$WORKSPACE/.sevenos"
SCOPE_FILE="$STATE_DIR/scope.json"

usage() {
  cat <<'EOF'
SevenOS Shield Scope

Usage:
  seven shield scope [--json]
  seven shield scope create --owner NAME --engagement NAME --window TEXT --target HOST
  seven shield scope activate
  seven shield scope deactivate
  seven shield scope complete
  seven shield scope archive
  seven shield scope add-target HOST
  seven shield scope remove-target HOST

Scope is the authorization gate for Shield. Red Team, web pentest and network
audit flows should stay locked until a scope is active and has targets.
EOF
}

shift_if_action() {
  case "${1:-}" in
    status|scope) ACTION="status"; shift ;;
    create|activate|deactivate|complete|archive|add-target|remove-target|validate) ACTION="$1"; shift ;;
  esac

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --json|json) JSON_OUTPUT=1 ;;
      create|activate|deactivate|complete|archive|add-target|remove-target|validate) ACTION="$1" ;;
      --owner) shift; OWNER="${1:-}" ;;
      --engagement) shift; ENGAGEMENT="${1:-}" ;;
      --window|--time-window) shift; TIME_WINDOW="${1:-}" ;;
      --target) shift; TARGETS+=("${1:-}") ;;
      --exclude|--excluded) shift; EXCLUDED+=("${1:-}") ;;
      -h|--help|help) usage; exit 0 ;;
      *)
        case "$ACTION" in
          add-target|remove-target) TARGETS+=("$1") ;;
          *) log_error "Unknown Shield scope option: $1"; usage; exit 1 ;;
        esac
        ;;
    esac
    shift
  done
}

ensure_scope() {
  mkdir -p "$STATE_DIR"
  if [[ ! -s "$SCOPE_FILE" ]]; then
    python - "$SCOPE_FILE" "$WORKSPACE" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, workspace = sys.argv[1:3]
payload = {
    "schema": "sevenos.shield-scope.v1",
    "workspace": workspace,
    "state": "DRAFT",
    "active": False,
    "owner": "",
    "engagement": "",
    "time_window": "",
    "targets": [],
    "excluded": [],
    "rules": [
        "authorized targets only",
        "document owner and time window before scanning",
        "keep captures and reports inside the Shield workspace",
        "prefer offline labs for unknown samples",
    ],
    "created_at": datetime.now(timezone.utc).isoformat(),
    "updated_at": datetime.now(timezone.utc).isoformat(),
}
open(path, "w", encoding="utf-8").write(json.dumps(payload, indent=2) + "\n")
PY
  fi
}

read_scope() {
  ensure_scope
  python - "$SCOPE_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except json.JSONDecodeError as error:
    print(json.dumps({
        "schema": "sevenos.shield-scope.v1",
        "state": "INVALID",
        "active": False,
        "target_count": 0,
        "path": str(path),
        "error": str(error),
    }, indent=2))
    raise SystemExit(0)

data.setdefault("state", "ACTIVE" if data.get("active") else "DRAFT")
if data.get("state") == "ACTIVE":
    data["active"] = True
elif data.get("state") in ("COMPLETED", "ARCHIVED"):
    data["active"] = False
else:
    data["active"] = bool(data.get("active"))
    data["state"] = "ACTIVE" if data["active"] else data.get("state", "DRAFT")
data["target_count"] = len(data.get("targets") or [])
data["path"] = str(path)
print(json.dumps(data, indent=2))
PY
}

write_scope_from_env() {
  ensure_scope
  OWNER="$OWNER" ENGAGEMENT="$ENGAGEMENT" TIME_WINDOW="$TIME_WINDOW" \
  TARGETS_JOINED="$(printf '%s\n' "${TARGETS[@]}" | sed '/^$/d')" \
  EXCLUDED_JOINED="$(printf '%s\n' "${EXCLUDED[@]}" | sed '/^$/d')" \
  ACTION="$ACTION" python - "$SCOPE_FILE" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
now = datetime.now(timezone.utc).isoformat()

def lines(name):
    return [item.strip() for item in os.environ.get(name, "").splitlines() if item.strip()]

if os.environ.get("OWNER"):
    data["owner"] = os.environ["OWNER"]
if os.environ.get("ENGAGEMENT"):
    data["engagement"] = os.environ["ENGAGEMENT"]
if os.environ.get("TIME_WINDOW"):
    data["time_window"] = os.environ["TIME_WINDOW"]
if lines("TARGETS_JOINED"):
    merged = list(dict.fromkeys((data.get("targets") or []) + lines("TARGETS_JOINED")))
    data["targets"] = merged
if lines("EXCLUDED_JOINED"):
    merged = list(dict.fromkeys((data.get("excluded") or []) + lines("EXCLUDED_JOINED")))
    data["excluded"] = merged

data["updated_at"] = now
path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

validate_scope() {
  local payload
  payload="$(read_scope)"
  SHIELD_SCOPE_JSON="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["SHIELD_SCOPE_JSON"])
errors = []
if data.get("state") == "INVALID":
    errors.append(data.get("error", "invalid JSON"))
if not data.get("owner"):
    errors.append("owner is required")
if not data.get("engagement"):
    errors.append("engagement is required")
if not data.get("time_window"):
    errors.append("time_window is required")
if not data.get("targets"):
    errors.append("at least one target is required")
payload = {
    "schema": "sevenos.shield-scope-validation.v1",
    "state": "OK" if not errors else "BLOCKED",
    "errors": errors,
    "scope": data,
}
print(json.dumps(payload, indent=2))
raise SystemExit(0 if not errors else 1)
PY
}

set_state() {
  local state="$1"
  ensure_scope
  python - "$SCOPE_FILE" "$state" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

path, state = sys.argv[1:3]
data = json.loads(Path(path).read_text())
data["state"] = state
data["active"] = state == "ACTIVE"
data["updated_at"] = datetime.now(timezone.utc).isoformat()
Path(path).write_text(json.dumps(data, indent=2) + "\n")
PY
}

remove_target() {
  local target="${TARGETS[0]:-}"
  [[ -n "$target" ]] || { log_error "remove-target needs a target."; exit 1; }
  ensure_scope
  python - "$SCOPE_FILE" "$target" <<'PY'
import json
import sys
from pathlib import Path

path, target = sys.argv[1:3]
data = json.loads(Path(path).read_text())
data["targets"] = [item for item in data.get("targets", []) if item != target]
Path(path).write_text(json.dumps(data, indent=2) + "\n")
PY
}

emit_scope_event() {
  "$ROOT_DIR/scripts/events.sh" log \
    --source shield \
    --type scope \
    --state OK \
    --message "Shield scope ${1}" \
    --command "seven shield scope ${ACTION}" >/dev/null || true
}

status_human() {
  local payload
  payload="$(read_scope)"
  SHIELD_SCOPE_JSON="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["SHIELD_SCOPE_JSON"])
print("SevenOS Shield Scope")
print("====================")
print(f"State:      {data.get('state', 'MISS')}")
print(f"Active:     {data.get('active', False)}")
print(f"Owner:      {data.get('owner') or '-'}")
print(f"Engagement: {data.get('engagement') or '-'}")
print(f"Window:     {data.get('time_window') or '-'}")
print(f"Targets:    {data.get('target_count', 0)}")
print(f"Path:       {data.get('path')}")
print()
for target in data.get("targets") or []:
    print(f"  target: {target}")
if not data.get("targets"):
    print("  no target yet")
print()
print("Activate only when owner, engagement, time window and targets are explicit.")
PY
}

shift_if_action "$@"

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then read_scope; else status_human; fi
    ;;
  create)
    write_scope_from_env
    set_state DRAFT
    emit_scope_event "created"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then read_scope; else log_success "Shield scope drafted"; status_human; fi
    ;;
  add-target)
    write_scope_from_env
    emit_scope_event "target added"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then read_scope; else log_success "Shield scope target added"; fi
    ;;
  remove-target)
    remove_target
    emit_scope_event "target removed"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then read_scope; else log_success "Shield scope target removed"; fi
    ;;
  validate)
    validate_scope
    ;;
  activate)
    if ! validate_scope >/dev/null; then
      validate_scope || true
      log_error "Shield scope cannot be activated yet."
      exit 1
    fi
    set_state ACTIVE
    emit_scope_event "activated"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then read_scope; else log_success "Shield scope active"; status_human; fi
    ;;
  deactivate)
    set_state DRAFT
    emit_scope_event "deactivated"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then read_scope; else log_success "Shield scope returned to draft"; fi
    ;;
  complete)
    set_state COMPLETED
    emit_scope_event "completed"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then read_scope; else log_success "Shield scope completed"; fi
    ;;
  archive)
    set_state ARCHIVED
    emit_scope_event "archived"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then read_scope; else log_success "Shield scope archived"; fi
    ;;
esac
