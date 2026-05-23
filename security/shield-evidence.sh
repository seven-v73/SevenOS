#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0
EVIDENCE_PATH=""
CASE_ID="default"
NOTE=""

WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
STATE_DIR="$WORKSPACE/.sevenos"
EVIDENCE_DIR="$WORKSPACE/Evidence"
INDEX_FILE="$STATE_DIR/evidence-index.json"

usage() {
  cat <<'EOF'
SevenOS Shield Evidence Manager

Usage:
  seven shield evidence [--json]
  seven shield evidence init
  seven shield evidence add PATH [--case NAME] [--note TEXT]
  seven shield evidence list [--json]

Evidence Manager records hashes and metadata for files you analyze. It does not
modify the original file and keeps a local chain-of-custody index.
EOF
}

shift_if_action() {
  case "${1:-}" in
    status|evidence) ACTION="status"; shift ;;
    init|add|list) ACTION="$1"; shift ;;
  esac
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --json|json) JSON_OUTPUT=1 ;;
      status|evidence|init|add|list) [[ "$1" == "evidence" ]] && ACTION="status" || ACTION="$1" ;;
      --case) shift; CASE_ID="${1:-default}" ;;
      --note) shift; NOTE="${1:-}" ;;
      -h|--help|help) usage; exit 0 ;;
      *)
        if [[ -z "$EVIDENCE_PATH" && "$ACTION" == "add" ]]; then
          EVIDENCE_PATH="$1"
        else
          log_error "Unknown Shield evidence option: $1"
          usage
          exit 1
        fi
        ;;
    esac
    shift
  done
}

init_index() {
  mkdir -p "$STATE_DIR" "$EVIDENCE_DIR" "$WORKSPACE/Cases/$CASE_ID"
  if [[ ! -s "$INDEX_FILE" ]]; then
    python - "$INDEX_FILE" "$WORKSPACE" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, workspace = sys.argv[1:3]
payload = {
    "schema": "sevenos.shield-evidence-index.v1",
    "workspace": workspace,
    "created_at": datetime.now(timezone.utc).isoformat(),
    "updated_at": datetime.now(timezone.utc).isoformat(),
    "items": [],
}
open(path, "w", encoding="utf-8").write(json.dumps(payload, indent=2) + "\n")
PY
  fi
}

status_json() {
  init_index
  python - "$INDEX_FILE" "$EVIDENCE_DIR" <<'PY'
import json
import sys
from pathlib import Path

index = Path(sys.argv[1])
evidence_dir = Path(sys.argv[2])
data = json.loads(index.read_text())
payload = {
    "schema": "sevenos.shield-evidence-status.v1",
    "state": "OK",
    "index": str(index),
    "evidence_dir": str(evidence_dir),
    "items": len(data.get("items") or []),
    "cases": sorted({item.get("case", "default") for item in data.get("items", [])}),
}
print(json.dumps(payload, indent=2))
PY
}

add_evidence() {
  [[ -n "$EVIDENCE_PATH" ]] || { log_error "evidence add needs a path."; exit 1; }
  [[ -e "$EVIDENCE_PATH" ]] || { log_error "evidence path not found: $EVIDENCE_PATH"; exit 1; }
  init_index
  python - "$INDEX_FILE" "$EVIDENCE_PATH" "$CASE_ID" "$NOTE" <<'PY'
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

index_path, item_path_raw, case_id, note = sys.argv[1:5]
item_path = Path(item_path_raw).expanduser().resolve()
index = Path(index_path)
data = json.loads(index.read_text())

hasher = hashlib.sha256()
with item_path.open("rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        hasher.update(chunk)

stat = item_path.stat()
record = {
    "id": hasher.hexdigest()[:16],
    "case": case_id or "default",
    "path": str(item_path),
    "name": item_path.name,
    "sha256": hasher.hexdigest(),
    "size": stat.st_size,
    "mtime": datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
    "registered_at": datetime.now(timezone.utc).isoformat(),
    "note": note,
    "handling": {
        "original_preserved": True,
        "read_only_recommended": True,
        "copy_made": False,
    },
}
items = data.setdefault("items", [])
items = [item for item in items if item.get("sha256") != record["sha256"] or item.get("path") != record["path"]]
items.append(record)
data["items"] = items
data["updated_at"] = datetime.now(timezone.utc).isoformat()
index.write_text(json.dumps(data, indent=2) + "\n")
print(json.dumps({"schema": "sevenos.shield-evidence-add.v1", "state": "OK", "item": record}, indent=2))
PY
}

list_evidence() {
  init_index
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    cat "$INDEX_FILE"
    return 0
  fi
  python - "$INDEX_FILE" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
print("SevenOS Shield Evidence")
print("=======================")
items = data.get("items") or []
if not items:
    print("No evidence registered yet.")
for item in items:
    print(f"{item.get('id')}  {item.get('case'):<12} {item.get('name')}")
    print(f"  sha256: {item.get('sha256')}")
    print(f"  path:   {item.get('path')}")
PY
}

shift_if_action "$@"

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_json; else list_evidence; fi
    ;;
  init)
    init_index
    "$ROOT_DIR/scripts/events.sh" log --source shield --type evidence --state OK --message "Shield evidence index initialized" --command "seven shield evidence init" >/dev/null || true
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_json; else log_success "Shield evidence index ready: $INDEX_FILE"; fi
    ;;
  add)
    payload="$(add_evidence)"
    "$ROOT_DIR/scripts/events.sh" log --source shield --type evidence --state OK --message "Shield evidence registered" --command "seven shield evidence add" >/dev/null || true
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then printf '%s\n' "$payload"; else log_success "Shield evidence registered"; fi
    ;;
  list)
    list_evidence
    ;;
esac
