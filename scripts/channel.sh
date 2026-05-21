#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/release"
CHANNEL_FILE="$STATE_DIR/channel.json"
ACTION="${1:-status}"
JSON_OUTPUT=0
CHANNEL=""

usage() {
  cat <<'EOF'
SevenOS release channel

Usage:
  seven channel [status|doctor|plan|json] [--json]
  seven channel set <dev|testing|stable> [--json]

This is the user-facing release identity contract. It lets SevenOS speak in
distribution channels instead of exposing raw git state as the primary product
language.
EOF
}

shift || true
if [[ "$ACTION" == "set" ]]; then
  CHANNEL="${1:-}"
  [[ $# -gt 0 ]] && shift || true
fi

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown channel option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

git_value() {
  local fallback="$1"
  shift
  git -C "$ROOT_DIR" "$@" 2>/dev/null || printf '%s\n' "$fallback"
}

dirty_count() {
  git -C "$ROOT_DIR" status --short 2>/dev/null | wc -l | tr -d ' '
}

current_channel() {
  if [[ -s "$CHANNEL_FILE" ]]; then
    python - "$CHANNEL_FILE" <<'PY' 2>/dev/null || printf 'dev\n'
import json
import sys
from pathlib import Path
try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    print(data.get("channel") or "dev")
except Exception:
    print("dev")
PY
  else
    printf 'dev\n'
  fi
}

write_channel() {
  local channel="$1"
  case "$channel" in
    dev|testing|stable) ;;
    *) log_error "Unknown channel: $channel"; usage; exit 1 ;;
  esac
  mkdir -p "$STATE_DIR"
  CHANNEL="$channel" ROOT_DIR="$ROOT_DIR" BRANCH="$(git_value unknown rev-parse --abbrev-ref HEAD)" \
    COMMIT="$(git_value unknown rev-parse --short HEAD)" DIRTY_COUNT="$(dirty_count)" \
    UPDATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" python - <<'PY' >"$CHANNEL_FILE"
import json
import os

print(json.dumps({
    "schema": "sevenos.release-channel.v1",
    "channel": os.environ["CHANNEL"],
    "root": os.environ["ROOT_DIR"],
    "branch": os.environ["BRANCH"],
    "commit": os.environ["COMMIT"],
    "dirty_count": int(os.environ["DIRTY_COUNT"]),
    "updated_at": os.environ["UPDATED_AT"],
    "source": "seven channel set",
}, indent=2))
PY
}

channel_json() {
  local channel branch commit dirty installer_json state risk public_ready
  channel="$(current_channel)"
  branch="$(git_value unknown rev-parse --abbrev-ref HEAD)"
  commit="$(git_value unknown rev-parse --short HEAD)"
  dirty="$(dirty_count)"
  installer_json="$("$ROOT_DIR/scripts/installer-stack.sh" release --json 2>/dev/null || printf '{}')"
  CHANNEL="$channel" BRANCH="$branch" COMMIT="$commit" DIRTY_COUNT="$dirty" \
  INSTALLER_JSON="$installer_json" CHANNEL_FILE="$CHANNEL_FILE" \
  python - <<'PY'
import json
import os

def load(name):
    try:
        return json.loads(os.environ.get(name, "{}"))
    except json.JSONDecodeError:
        return {}

channel = os.environ["CHANNEL"]
dirty = int(os.environ.get("DIRTY_COUNT", "0") or 0)
installer = load("INSTALLER_JSON")
installer_state = installer.get("state", "unknown")
daily_ready = installer_state in {"tui-release-ready", "graphical-ready", "iso-foundation"}
public_ready = daily_ready and dirty == 0 and installer_state == "graphical-ready"

if channel == "stable" and not public_ready:
    state = "stable-blocked"
elif channel == "stable":
    state = "stable"
elif channel == "testing" and daily_ready:
    state = "testing"
elif daily_ready:
    state = "dev-ready"
else:
    state = "dev"

risk = {
    "dev": "active-development",
    "testing": "candidate",
    "stable": "release",
}.get(channel, "active-development")

checks = [
    {
        "key": "daily-driver",
        "state": "OK" if daily_ready else "PART",
        "title": "Daily-driver health",
        "detail": "SevenOS can be used as a stable personal environment.",
        "command": "seven doctor check --json",
    },
    {
        "key": "worktree-freeze",
        "state": "OK" if dirty == 0 else "PART",
        "title": "Repository freeze",
        "detail": f"{dirty} uncommitted path(s).",
        "command": "seven release freeze",
    },
    {
        "key": "graphical-installer",
        "state": "OK" if installer_state == "graphical-ready" else "PART",
        "title": "Graphical ISO installer",
        "detail": f"Installer state: {installer_state}.",
        "command": "seven installer graphical",
    },
]

print(json.dumps({
    "schema": "sevenos.release-channel.v1",
    "channel": channel,
    "state": state,
    "risk": risk,
    "branch": os.environ.get("BRANCH"),
    "commit": os.environ.get("COMMIT"),
    "dirty_count": dirty,
    "channel_file": os.environ.get("CHANNEL_FILE"),
    "daily_driver_ready": daily_ready,
    "public_release_ready": public_ready,
    "installer_state": installer_state,
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
}, indent=2))
PY
}

print_human() {
  CHANNEL_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["CHANNEL_JSON"])
print("SevenOS Release Channel")
print("=======================")
print(f"Channel:        {data.get('channel')}")
print(f"State:          {data.get('state')}")
print(f"Risk:           {data.get('risk')}")
print(f"Branch/commit:  {data.get('branch')} / {data.get('commit')}")
print(f"Dirty paths:    {data.get('dirty_count')}")
print(f"Public release: {str(data.get('public_release_ready')).lower()}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

case "$ACTION" in
  status|json)
    payload="$(channel_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  doctor)
    payload="$(channel_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
      exit 0
    fi
    print_human "$payload"
    ;;
  plan)
    payload="$(channel_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      CHANNEL_JSON="$payload" python - <<'PY'
import json
import os
data = json.loads(os.environ["CHANNEL_JSON"])
print(json.dumps({
    "schema": "sevenos.release-channel-plan.v1",
    "channel": data.get("channel"),
    "state": data.get("state"),
    "next": data.get("issues", []),
}, indent=2))
PY
    else
      print_human "$payload"
    fi
    ;;
  set)
    write_channel "$CHANNEL"
    payload="$(channel_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "Unknown channel action: $ACTION"
    usage
    exit 1
    ;;
esac
