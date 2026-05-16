#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos"
EVENT_FILE="$STATE_DIR/events.jsonl"
ACTION="${1:-list}"
JSON_OUTPUT=0
LIMIT=12
SOURCE="system"
TYPE="event"
MESSAGE=""
COMMAND_TEXT=""
STATE="OK"
PAYLOAD_JSON=""

usage() {
  cat <<'EOF'
SevenOS Events

Usage:
  seven events
  seven events --json
  seven events summary-json
  seven events log --source <name> --type <event> --message <text> [--command <cmd>] [--state OK|WARN|MISS] [--payload-json <json>]

The event journal is a local user-state audit trail for SevenOS decisions,
previews and executed actions.
EOF
}

shift || true
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json|json) JSON_OUTPUT=1 ;;
    --limit)
      shift
      LIMIT="${1:-}"
      [[ "$LIMIT" =~ ^[0-9]+$ ]] || { log_error "--limit expects a number."; exit 1; }
      ;;
    --source) shift; SOURCE="${1:-system}" ;;
    --type) shift; TYPE="${1:-event}" ;;
    --message) shift; MESSAGE="${1:-}" ;;
    --command) shift; COMMAND_TEXT="${1:-}" ;;
    --state) shift; STATE="${1:-OK}" ;;
    --payload-json) shift; PAYLOAD_JSON="${1:-}" ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown events option: $1"; usage; exit 1 ;;
  esac
  shift
done

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

ensure_state_dir() {
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$STATE_DIR"
  else
    mkdir -p "$STATE_DIR"
  fi
}

log_event() {
  if [[ -z "$MESSAGE" ]]; then
    log_error "events log requires --message"
    exit 1
  fi

  local timestamp payload
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if ! is_dry_run && [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    if "$ROOT_DIR/bin/seven-daemon" emit --source "$SOURCE" --type "$TYPE" --state "$STATE" --message "$MESSAGE" --command "$COMMAND_TEXT" --payload-json "$PAYLOAD_JSON" >/dev/null 2>&1; then
      return 0
    fi
    log_warn "seven-daemon emit failed; falling back to Bash event writer."
  fi

  payload="$(
    EVENT_SOURCE="$SOURCE" EVENT_TYPE="$TYPE" EVENT_MESSAGE="$MESSAGE" EVENT_COMMAND="$COMMAND_TEXT" EVENT_STATE="$STATE" EVENT_TIME="$timestamp" EVENT_PAYLOAD="$PAYLOAD_JSON" python - <<'PY'
import json
import os

payload_raw = os.environ.get("EVENT_PAYLOAD", "")
payload = None
if payload_raw:
    try:
        payload = json.loads(payload_raw)
    except json.JSONDecodeError as error:
        raise SystemExit(f"invalid EVENT_PAYLOAD: {error}")

print(json.dumps({
    "schema": "sevenos.event.v1",
    "timestamp": os.environ["EVENT_TIME"],
    "source": os.environ["EVENT_SOURCE"],
    "type": os.environ["EVENT_TYPE"],
    "state": os.environ["EVENT_STATE"],
    "message": os.environ["EVENT_MESSAGE"],
    "command": os.environ["EVENT_COMMAND"] or None,
    "payload": payload,
}, separators=(",", ":")))
PY
  )"

  ensure_state_dir >/dev/null
  if is_dry_run; then
    if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
      printf 'DRY-RUN > SevenBus > Emit via seven-daemon: %s/%s\n' "$SOURCE" "$TYPE"
    else
      printf 'append %q to %q\n' "$payload" "$EVENT_FILE"
    fi
  else
    printf '%s\n' "$payload" >> "$EVENT_FILE"
  fi
}

json_events() {
  if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    "$ROOT_DIR/bin/seven-daemon" events --limit "$LIMIT" --json
    return 0
  fi

  EVENT_FILE="$EVENT_FILE" LIMIT="$LIMIT" python - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["EVENT_FILE"])
limit = int(os.environ.get("LIMIT", "12"))
events = []

if path.exists():
    for raw in path.read_text(encoding="utf-8").splitlines()[-limit:]:
        try:
            events.append(json.loads(raw))
        except json.JSONDecodeError:
            continue

print(json.dumps({
    "schema": "sevenos.events.v1",
    "path": str(path),
    "count": len(events),
    "events": events,
}, indent=2))
PY
}

summary_json() {
  if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    "$ROOT_DIR/bin/seven-daemon" summary --json
    return 0
  fi

  EVENT_FILE="$EVENT_FILE" python - <<'PY'
import json
from collections import Counter
from pathlib import Path
import os

path = Path(os.environ["EVENT_FILE"])
events = []
if path.exists():
    for raw in path.read_text(encoding="utf-8").splitlines():
        try:
            events.append(json.loads(raw))
        except json.JSONDecodeError:
            continue

by_source = Counter(item.get("source", "unknown") for item in events)
last = events[-1] if events else None

print(json.dumps({
    "schema": "sevenos.events.summary.v1",
    "path": str(path),
    "total": len(events),
    "sources": dict(by_source),
    "last": last,
}, indent=2))
PY
}

human_events() {
  EVENTS_PAYLOAD="$(json_events)" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["EVENTS_PAYLOAD"])
print("SevenOS Events")
print("==============")
print(f"Path: {data.get('path')}")
if not data.get("events"):
    print("No events recorded yet.")
    return_code = 0
else:
    for item in data.get("events", []):
        print(f"{item.get('timestamp')}  {item.get('state'):<5} {item.get('source')}/{item.get('type')}")
        print(f"  {item.get('message')}")
        if item.get("command"):
            print(f"  command: {item.get('command')}")
PY
}

case "$ACTION" in
  list)
    [[ "$JSON_OUTPUT" -eq 1 ]] && json_events || human_events
    ;;
  --json|json)
    json_events
    ;;
  summary-json)
    summary_json
    ;;
  log)
    log_event
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "Unknown events action: $ACTION"
    usage
    exit 1
    ;;
esac
