#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenCloud Preview

Usage:
  seven cloud [status|plan|doctor|json]

SevenCloud is the local-first backup, restore and sync contract for SevenOS.
It is intentionally non-destructive: it describes what would be protected.
EOF
}

payload_json() {
  ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import shutil
from pathlib import Path
import os

home = Path.home()
root = Path(os.environ["ROOT_DIR"])
targets = [
    {"key": "sevenos-config", "path": str(home / ".config" / "sevenos"), "reason": "SevenOS user preferences, shell hints and identity state."},
    {"key": "hyprland", "path": str(home / ".config" / "hypr"), "reason": "Desktop session, monitor and keyboard overrides."},
    {"key": "waybar", "path": str(home / ".config" / "waybar"), "reason": "Top-bar modules and user-facing shell controls."},
    {"key": "profiles", "path": str(home / "SevenOS"), "reason": "Profile workspaces, checklists and generated user state."},
    {"key": "repo-progress", "path": str(root / "progress.md"), "reason": "Local product progress notes."},
]
tools = [
    {"key": "rsync", "state": "OK" if shutil.which("rsync") else "MISS", "command": "seven improve deployment --apply --yes"},
    {"key": "age", "state": "OK" if shutil.which("age") else "MISS", "command": "seven shield enable"},
    {"key": "git", "state": "OK" if shutil.which("git") else "MISS", "command": "sevenpkg install forge"},
]
available_targets = [item for item in targets if Path(item["path"]).exists()]
payload = {
    "schema": "sevenos.cloud.v1",
    "state": "preview",
    "writer": "scripts/cloud.sh",
    "summary": {
        "targets": len(targets),
        "available_targets": len(available_targets),
        "tools_ready": sum(1 for item in tools if item["state"] == "OK"),
        "tools_total": len(tools),
    },
    "targets": [{**item, "state": "OK" if Path(item["path"]).exists() else "MISS"} for item in targets],
    "tools": tools,
    "backup_root": str(home / "SevenOS" / "Backups"),
    "commands": {
        "plan": "seven cloud plan",
        "restore": "seven cloud plan",
        "future_backup": "seven cloud backup --confirm",
    },
}
print(json.dumps(payload, indent=2))
PY
}

status() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
s = d["summary"]
print("SevenCloud Preview")
print("==================")
print(f"Targets:    {s['available_targets']}/{s['targets']} present")
print(f"Tools:      {s['tools_ready']}/{s['tools_total']} ready")
print(f"Backup dir: {d['backup_root']}")
print()
for item in d["tools"]:
    print(f"  - {item['key']:<6} {item['state']}")
PY
}

plan() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
print("SevenCloud Protection Plan")
print("==========================")
for item in d["targets"]:
    print(f"{item['key']:<16} {item['state']:<5} {item['path']}")
    print(f"{'':<16} {item['reason']}")
print()
print("No files are copied by this preview.")
PY
}

doctor() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
print("SevenCloud Doctor")
print("=================")
for item in d["tools"]:
    print(f"[{item['state']}] {item['key']}")
if d["summary"]["tools_ready"] < 2:
    raise SystemExit(1)
PY
}

action="${1:-status}"
case "$action" in
  status) status ;;
  plan) plan ;;
  doctor) doctor ;;
  json|--json) payload_json ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown cloud action: $action"; usage; exit 1 ;;
esac
