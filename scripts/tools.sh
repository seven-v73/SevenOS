#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"

usage() {
  cat <<'EOF'
SevenOS Tools

Usage:
  seven tools
  seven tools status
  seven tools doctor
  seven tools plan
  seven tools detail <settings|files|store|reader|notes|widgets|doctor|terminal> [--json]
  seven tools open
  seven tools open <settings|files|store|reader|notes|widgets|doctor|terminal>
  seven tools --json

Checks the native user-facing tools without opening their windows.
EOF
}

open_tool() {
  local key="${1:-}"
  case "$key" in
    ""|tools|dashboard|gui)
      exec "$ROOT_DIR/bin/seven-tools-native"
      ;;
    settings|preferences|reglages|réglages)
      exec "$ROOT_DIR/bin/seven" settings
      ;;
    files|file|fichiers)
      exec "$ROOT_DIR/bin/seven" files
      ;;
    store|appstore|software|apps)
      exec "$ROOT_DIR/bin/seven" store
      ;;
    reader|lecture)
      exec "$ROOT_DIR/bin/seven" reader
      ;;
    notes|note)
      exec "$ROOT_DIR/bin/seven" notes
      ;;
    widgets|widget)
      exec "$ROOT_DIR/bin/seven" widgets menu
      ;;
    doctor|task|tasks|monitor|diagnostic)
      exec "$ROOT_DIR/bin/seven" doctor open
      ;;
    terminal|term)
      exec "$ROOT_DIR/bin/seven-terminal"
      ;;
    *)
      printf 'seven tools: unknown tool "%s"\n' "$key" >&2
      printf 'available: settings, files, store, reader, notes, widgets, doctor, terminal\n' >&2
      exit 2
      ;;
  esac
}

python_status() {
  local action="${1:-status}"
  local json="${2:-0}"
  local target="${3:-}"
  python3 - "$ROOT_DIR" "$action" "$json" "$target" <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
action = sys.argv[2]
wants_json = sys.argv[3] == "1"
target = sys.argv[4].strip().lower() if len(sys.argv) > 4 else ""

tools = [
    {
        "key": "settings",
        "name": "SevenOS Settings",
        "role": "system preferences",
        "intent": "Adjust language, theme, power, privacy, Prism and system behavior.",
        "primary_label": "Open settings",
        "category": "system",
        "native": "bin/seven-settings-native",
        "desktop": "seven-hub/seven-settings.desktop",
        "probe": ["bin/seven-settings-native", "--probe"],
        "action": "settings.open",
        "open": ["seven", "settings"],
    },
    {
        "key": "files",
        "name": "Seven Files",
        "role": "file manager",
        "intent": "Browse files, devices, Mini OS spaces and Windows app files.",
        "primary_label": "Open files",
        "category": "workspace",
        "native": "bin/seven-files-native",
        "desktop": "seven-hub/seven-files.desktop",
        "probe": ["bin/seven-files-native", "--probe"],
        "action": "files.open",
        "open": ["seven", "files"],
    },
    {
        "key": "store",
        "name": "SevenStore",
        "role": "software center",
        "intent": "Install, remove and repair apps through the SevenOS package facade.",
        "primary_label": "Open store",
        "category": "system",
        "native": "bin/seven-store-native",
        "desktop": "seven-hub/seven-store.desktop",
        "probe": ["bin/seven-store-native", "--probe"],
        "action": "store.open",
        "open": ["seven", "store"],
    },
    {
        "key": "reader",
        "name": "Seven Reader",
        "role": "documents and study",
        "intent": "Read PDF, EPUB, text and study documents with progress memory.",
        "primary_label": "Open reader",
        "category": "knowledge",
        "native": "bin/seven-reader-native",
        "desktop": "seven-hub/seven-reader.desktop",
        "probe": ["bin/seven-reader", "--json"],
        "action": "reader.open",
        "open": ["seven", "reader"],
    },
    {
        "key": "notes",
        "name": "Seven Notes",
        "role": "notes and home widget capture",
        "intent": "Capture notes, pin recent thoughts and use the home widget for quick entry.",
        "primary_label": "Open notes",
        "category": "knowledge",
        "native": "bin/seven-notes-native",
        "desktop": "seven-hub/seven-notes.desktop",
        "probe": ["bin/seven-notes-native", "--probe"],
        "action": "notes.open",
        "open": ["seven", "notes"],
    },
    {
        "key": "widgets",
        "name": "Seven Widgets",
        "role": "home workspace widgets",
        "intent": "Control the optional home workspace widgets and quick glance cards.",
        "primary_label": "Open widgets",
        "category": "workspace",
        "native": "bin/seven-widgets-native",
        "desktop": "",
        "probe": ["bin/seven", "widgets", "doctor", "--json"],
        "action": "widgets.menu",
        "open": ["seven", "widgets", "menu"],
    },
    {
        "key": "doctor",
        "name": "Seven Doctor",
        "role": "task manager and diagnostics",
        "intent": "Inspect running apps, services, system health and guided fixes.",
        "primary_label": "Open doctor",
        "category": "support",
        "native": "bin/seven-doctor-native",
        "desktop": "",
        "probe": ["bin/seven-doctor-native", "--json"],
        "action": "health.doctor",
        "open": ["seven", "doctor", "open"],
    },
    {
        "key": "terminal",
        "name": "Seven Terminal",
        "role": "mini OS aware terminal",
        "intent": "Run commands in the current Mini OS context with SevenOS identity.",
        "primary_label": "Open terminal",
        "category": "workspace",
        "native": "bin/seven-terminal-native",
        "desktop": "seven-hub/seven-terminal.desktop",
        "probe": ["bin/seven-terminal", "status"],
        "action": "terminal.open",
        "open": ["seven-terminal"],
    },
]

actions_file = root / "scripts/actions.sh"
actions_text = actions_file.read_text(encoding="utf-8", errors="ignore") if actions_file.exists() else ""

def summarize_probe_output(raw):
    raw = (raw or "").strip()
    if not raw:
        return "ok"
    try:
        parsed = json.loads(raw)
    except Exception:
        first_line = raw.splitlines()[0].strip()
        return first_line[:160] if first_line else "ok"
    if isinstance(parsed, dict):
        state = parsed.get("state") or parsed.get("status")
        score = parsed.get("score")
        ready = parsed.get("ready")
        parts = []
        if state:
            parts.append(str(state))
        if score is not None:
            parts.append(f"score {score}")
        if ready is not None:
            parts.append("ready" if ready else "not ready")
        if parts:
            return " · ".join(parts)[:160]
    return "json ok"

def run_probe(cmd):
    resolved = [str(root / cmd[0]), *cmd[1:]]
    try:
        proc = subprocess.run(
            resolved,
            cwd=root,
            env={**os.environ, "SEVENOS_ROOT": str(root)},
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=8,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "code": 124, "message": "timeout"}
    except Exception as exc:
        return {"ok": False, "code": 127, "message": str(exc)}
    raw_output = (proc.stdout or proc.stderr or "").strip()
    return {
        "ok": proc.returncode == 0,
        "code": proc.returncode,
        "message": summarize_probe_output(raw_output),
    }

rows = []
for item in tools:
    native_path = root / item["native"]
    desktop_path = root / item["desktop"] if item["desktop"] else None
    native_ok = native_path.exists() and os.access(native_path, os.X_OK)
    desktop_ok = True if desktop_path is None else desktop_path.exists()
    action_ok = bool(item["action"] and item["action"] in actions_text)
    probe = run_probe(item["probe"]) if native_ok else {"ok": False, "code": 127, "message": "native missing"}
    blockers = []
    if not native_ok:
        blockers.append("native-missing")
    if not desktop_ok:
        blockers.append("desktop-missing")
    if not action_ok:
        blockers.append("action-missing")
    if not probe["ok"]:
        blockers.append("probe-failed")
    state = "OK" if not blockers else ("PART" if native_ok else "MISS")
    recommendation = "Open this tool." if state == "OK" else "Open Seven Doctor or inspect the blockers before using this tool."
    rows.append({
        **item,
        "native_ready": native_ok,
        "desktop_ready": desktop_ok,
        "action_ready": action_ok,
        "probe": probe,
        "state": state,
        "blockers": blockers,
        "recommendation": recommendation,
    })

ok_count = sum(1 for row in rows if row["state"] == "OK")
score = round((ok_count / len(rows)) * 100) if rows else 0
state = "ready" if ok_count == len(rows) else ("needs-attention" if ok_count else "blocked")
category_order = ["system", "workspace", "knowledge", "support"]
categories = {}
for category in category_order:
    items = [row for row in rows if row.get("category") == category]
    if not items:
        continue
    categories[category] = {
        "tools": len(items),
        "ok": sum(1 for row in items if row["state"] == "OK"),
        "partial": sum(1 for row in items if row["state"] == "PART"),
        "missing": sum(1 for row in items if row["state"] == "MISS"),
    }

payload = {
    "schema": "sevenos.tools.v1",
    "state": state,
    "score": score,
    "root": str(root),
    "summary": {
        "tools": len(rows),
        "ok": ok_count,
        "partial": sum(1 for row in rows if row["state"] == "PART"),
        "missing": sum(1 for row in rows if row["state"] == "MISS"),
    },
    "categories": categories,
    "tools": rows,
    "plan": [
        "Keep every daily tool native-first, localized and profile-aware.",
        "Use progress, feedback and safe previews before destructive actions.",
        "Expose the same tool state to Settings, Helper, Spotlight and SevenAI.",
    ],
}

if action == "detail":
    if not target:
        print("seven tools detail: missing tool name", file=sys.stderr)
        print("available: settings, files, store, reader, notes, widgets, doctor, terminal", file=sys.stderr)
        raise SystemExit(2)
    match = next(
        (
            row for row in rows
            if target in {
                str(row.get("key", "")).lower(),
                str(row.get("name", "")).lower(),
                str(row.get("name", "")).lower().replace(" ", "-"),
            }
        ),
        None,
    )
    if match is None:
        print(f'seven tools detail: unknown tool "{target}"', file=sys.stderr)
        print("available: settings, files, store, reader, notes, widgets, doctor, terminal", file=sys.stderr)
        raise SystemExit(2)
    detail = {
        "schema": "sevenos.tools.detail.v1",
        "state": match["state"],
        "root": str(root),
        "tool": match,
    }
    if wants_json:
        print(json.dumps(detail, ensure_ascii=False, indent=2))
    else:
        print(f"{match['name']} · {match['state']}")
        print(f"role: {match['role']}")
        print(f"category: {match['category']}")
        print(f"intent: {match['intent']}")
        print(f"recommendation: {match['recommendation']}")
        print(f"native: {match['native']} · {'ready' if match['native_ready'] else 'missing'}")
        print(f"desktop: {match['desktop'] or 'not required'} · {'ready' if match['desktop_ready'] else 'missing'}")
        print(f"action: {match['action']} · {'ready' if match['action_ready'] else 'missing'}")
        print(f"probe: {match['probe'].get('code')} · {match['probe'].get('message')}")
        if match["blockers"]:
            print(f"blockers: {', '.join(match['blockers'])}")
    raise SystemExit(0 if match["state"] == "OK" else 1)

if action in {"json", "doctor"}:
    wants_json = True

if wants_json:
    print(json.dumps(payload, ensure_ascii=False, indent=2))
else:
    print(f"SevenOS Tools · {state} · {score}%")
    print(f"{ok_count}/{len(rows)} tools ready")
    for category, values in categories.items():
        print(f"  {category}: {values['ok']}/{values['tools']} ready")
    for row in rows:
        marker = "OK" if row["state"] == "OK" else row["state"]
        print(f"- {marker:4} {row['name']}: {row['role']}")
        print(f"       {row['intent']}")
        if row["blockers"]:
            print(f"       blockers: {', '.join(row['blockers'])}")
    if action == "plan":
        print()
        for step in payload["plan"]:
            print(f"- {step}")

sys.exit(0 if state == "ready" or action in {"status", "plan"} else 1)
PY
}

main() {
  local action="${1:-status}"
  shift || true
  local wants_json=0
  for arg in "$@"; do
    [[ "$arg" == "--json" ]] && wants_json=1
  done
  case "$action" in
    open|gui)
      open_tool "${1:-}"
      ;;
    detail)
      local target=""
      for arg in "$@"; do
        [[ "$arg" == "--json" ]] && continue
        target="$arg"
        break
      done
      python_status "$action" "$wants_json" "$target"
      ;;
    status|doctor|plan|json)
      [[ "$action" == "json" ]] && wants_json=1
      python_status "$action" "$wants_json"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      printf 'seven tools: supported actions are open, detail, status, doctor, plan and json\n' >&2
      exit 2
      ;;
  esac
}

main "$@"
