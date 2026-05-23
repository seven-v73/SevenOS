#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
CONTEXT=""
WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
STATE_DIR="$WORKSPACE/.sevenos"
CONTEXT_FILE="$STATE_DIR/cyberspace-context.json"

usage() {
  cat <<'EOF'
SevenOS CyberSpace

Usage:
  seven shield mode
  seven shield mode --json
  seven shield workspaces
  seven shield context <name>
  seven shield context <name> --json
  seven shield layout <name>
  seven shield hud

CyberSpace turns Shield into a context-aware cybersecurity workspace: dedicated
workspaces, safe workflow presets, scope awareness and OS-native actions.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|mode|workspaces|context|layout|hud)
      ACTION="$1"
      shift
      ;;
    --json|json)
      JSON_OUTPUT=1
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$CONTEXT" ]]; then
        CONTEXT="$1"
      else
        log_error "Unknown CyberSpace option: $1"
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

context_json() {
  if [[ "${SEVENOS_CYBERSPACE_USE_DAEMON:-1}" == "1" && -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    SEVENOS_CYBERSPACE_USE_DAEMON=0 "$ROOT_DIR/bin/seven-daemon" cyberspace --json
    return 0
  fi

  SEVENOS_ROOT="$ROOT_DIR" SEVENOS_SHIELD_WORKSPACE="$WORKSPACE" SEVENOS_CONTEXT_FILE="$CONTEXT_FILE" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
workspace = Path(os.environ["SEVENOS_SHIELD_WORKSPACE"]).expanduser()
context_file = Path(os.environ["SEVENOS_CONTEXT_FILE"])


def command_json(command, fallback):
    result = subprocess.run(command, cwd=root, text=True, capture_output=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback


def command_state(name):
    result = subprocess.run(["bash", "-lc", f"command -v {name} >/dev/null 2>&1"], check=False)
    return "OK" if result.returncode == 0 else "MISS"


contexts = [
    {
        "key": "recon",
        "title": "Recon",
        "workspace": 1,
        "accent": "indigo",
        "purpose": "OSINT, discovery and authorized surface mapping.",
        "apps": ["kitty", "firefox", "nmap"],
        "tools": [{"name": "nmap", "state": command_state("nmap")}, {"name": "whois", "state": command_state("whois")}],
        "actions": ["seven shield scope", "seven shield lab --preset web"],
    },
    {
        "key": "web",
        "title": "Web Pentest",
        "workspace": 2,
        "accent": "gold",
        "purpose": "Browser, proxy and web application testing in a scoped lab.",
        "apps": ["firefox", "burpsuite", "zaproxy", "sqlmap"],
        "tools": [{"name": "burpsuite", "state": command_state("burpsuite")}, {"name": "zaproxy", "state": command_state("zaproxy")}, {"name": "sqlmap", "state": command_state("sqlmap")}],
        "actions": ["seven shield lab --preset web", "seven shield report"],
    },
    {
        "key": "reversing",
        "title": "Reverse Engineering",
        "workspace": 3,
        "accent": "clay",
        "purpose": "Offline binary triage and reverse engineering notes.",
        "apps": ["ghidra", "radare2", "gdb"],
        "tools": [{"name": "ghidra", "state": command_state("ghidra")}, {"name": "radare2", "state": command_state("radare2")}, {"name": "gdb", "state": command_state("gdb")}],
        "actions": ["seven shield lab --preset reversing", "seven shield report"],
    },
    {
        "key": "network",
        "title": "Network",
        "workspace": 4,
        "accent": "baobab",
        "purpose": "Packet inspection, network visibility and authorized capture.",
        "apps": ["wireshark", "tcpdump", "kitty"],
        "tools": [{"name": "wireshark", "state": command_state("wireshark")}, {"name": "tcpdump", "state": command_state("tcpdump")}],
        "actions": ["seven shield scope", "seven shield tools"],
    },
    {
        "key": "forensics",
        "title": "Forensics",
        "workspace": 5,
        "accent": "baobab",
        "purpose": "Evidence-safe offline triage, captures and reports.",
        "apps": ["autopsy", "sleuthkit", "kitty"],
        "tools": [{"name": "autopsy", "state": command_state("autopsy")}, {"name": "mmls", "state": command_state("mmls")}],
        "actions": ["seven shield lab --preset forensics", "seven shield report"],
    },
    {
        "key": "exploit",
        "title": "Exploitation",
        "workspace": 6,
        "accent": "clay",
        "purpose": "Controlled exploitation workflow for authorized targets only.",
        "apps": ["metasploit", "kitty"],
        "tools": [{"name": "msfconsole", "state": command_state("msfconsole")}],
        "actions": ["seven shield scope", "seven shield report"],
    },
    {
        "key": "intel",
        "title": "Threat Intel",
        "workspace": 7,
        "accent": "indigo",
        "purpose": "Indicators, notes, references and knowledge capture.",
        "apps": ["firefox", "obsidian", "kitty"],
        "tools": [{"name": "firefox", "state": command_state("firefox")}, {"name": "obsidian", "state": command_state("obsidian")}],
        "actions": ["seven shield open", "seven shield report"],
    },
    {
        "key": "logs",
        "title": "Logs & Monitoring",
        "workspace": 8,
        "accent": "indigo",
        "purpose": "System logs, services, posture events and monitoring.",
        "apps": ["journalctl", "btop", "kitty"],
        "tools": [{"name": "journalctl", "state": command_state("journalctl")}, {"name": "btop", "state": command_state("btop")}],
        "actions": ["seven events", "seven shield status"],
    },
    {
        "key": "sandbox",
        "title": "Sandbox",
        "workspace": 9,
        "accent": "gold",
        "purpose": "Isolated unknown workloads, offline labs and disposable tests.",
        "apps": ["firejail", "bwrap", "kitty"],
        "tools": [{"name": "firejail", "state": command_state("firejail")}, {"name": "bwrap", "state": command_state("bwrap")}],
        "actions": ["seven shield lab --preset offline", "seven shield tools"],
    },
]

active = {"key": "none", "state": "MISS"}
if context_file.is_file():
    try:
        active = json.loads(context_file.read_text())
    except json.JSONDecodeError:
        active = {"key": "invalid", "state": "INVALID"}

shield = command_json([str(root / "bin/seven"), "shield", "dashboard", "--json"], {})
persona = command_json([str(root / "security/shield-persona.sh"), "status", "--json"], {"state": "MISS", "active": {"key": "safe", "title": "Safe Audit"}, "session": "persistent"})
scope = shield.get("scope", {})
payload = {
    "schema": "sevenos.cyberspace.v1",
    "state": "ready",
    "workspace": str(workspace),
    "state_dir": str(workspace / ".sevenos"),
    "active_context": active,
    "persona": {
        "active": persona.get("active", {}),
        "session": persona.get("session", "persistent"),
        "network": (persona.get("active") or {}).get("network", "normal-guarded"),
        "isolation": (persona.get("active") or {}).get("isolation", "standard-sandbox"),
    },
    "scope": {
        "state": scope.get("state", "MISS"),
        "active": scope.get("active", False),
        "target_count": scope.get("target_count", 0),
        "path": scope.get("path", str(workspace / ".sevenos" / "scope.json")),
    },
    "workspaces": contexts,
    "commands": {
        "activate": "seven profile activate shield",
        "dashboard": "seven shield dashboard",
        "hud": "seven shield hud",
        "scope": "seven shield scope",
        "layout": "seven shield layout <context>",
    },
    "principles": [
        "context before tool",
        "scope before scan",
        "isolation before unknown workloads",
        "report before closure",
    ],
}
print(json.dumps(payload, indent=2))
PY
}

find_context_workspace() {
  local key="$1"
  local payload
  payload="$(context_json)"
  CYBERSPACE_JSON="$payload" python - "$key" <<'PY'
import json
import os
import sys

data = json.loads(os.environ["CYBERSPACE_JSON"])
key = sys.argv[1]
for item in data.get("workspaces", []):
    if item.get("key") == key:
        print(item.get("workspace", 1))
        raise SystemExit(0)
raise SystemExit(1)
PY
}

write_context() {
  local context="$1"
  local workspace_id="$2"
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$STATE_DIR"
    printf 'write %q\n' "$CONTEXT_FILE"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  python - "$CONTEXT_FILE" "$context" "$workspace_id" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, context, workspace = sys.argv[1:4]
payload = {
    "schema": "sevenos.cyberspace-context.v1",
    "key": context,
    "state": "ACTIVE",
    "workspace": int(workspace),
    "activated_at": datetime.now(timezone.utc).isoformat(),
}
open(path, "w", encoding="utf-8").write(json.dumps(payload, indent=2) + "\n")
PY
}

dispatch_workspace() {
  local workspace_id="$1"
  if is_dry_run; then
    printf 'hyprctl dispatch workspace %q\n' "$workspace_id"
    return 0
  fi
  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl dispatch workspace "$workspace_id" >/dev/null || true
  fi
}

scope_is_active() {
  local payload
  payload="$("$ROOT_DIR/security/shield-scope.sh" status --json 2>/dev/null || true)"
  SHIELD_SCOPE_JSON="$payload" python - <<'PY'
import json
import os
import sys

try:
    data = json.loads(os.environ.get("SHIELD_SCOPE_JSON", "{}"))
except Exception:
    raise SystemExit(1)
if data.get("active") and data.get("target_count", 0) > 0:
    raise SystemExit(0)
raise SystemExit(1)
PY
}

guard_context() {
  local context="$1"
  case "$context" in
    exploit)
      if ! scope_is_active; then
        log_error "CyberSpace exploit context needs an active Shield scope with targets."
        log_info "Create it with: seven shield scope create --owner YOU --engagement NAME --window TEXT --target HOST"
        log_info "Then activate it with: seven shield scope activate"
        exit 1
      fi
      ;;
  esac
}

activate_context() {
  local context="${1:-}"
  if [[ -z "$context" ]]; then
    log_error "Missing CyberSpace context."
    usage
    exit 1
  fi

  local workspace_id
  if ! workspace_id="$(find_context_workspace "$context")"; then
    log_error "Unknown CyberSpace context: $context"
    usage
    exit 1
  fi

  guard_context "$context"
  write_context "$context" "$workspace_id"
  dispatch_workspace "$workspace_id"

  if ! is_dry_run; then
    "$ROOT_DIR/scripts/events.sh" log \
      --source shield \
      --type cyberspace \
      --state OK \
      --message "CyberSpace context activated: $context" \
      --command "seven shield context $context" >/dev/null || true
  fi

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    local payload
    payload="$(context_json)"
    CYBERSPACE_JSON="$payload" python - "$context" <<'PY'
import json
import os
import sys

data = json.loads(os.environ["CYBERSPACE_JSON"])
context = sys.argv[1]
selected = next((item for item in data.get("workspaces", []) if item.get("key") == context), {})
print(json.dumps({"schema": "sevenos.cyberspace-activation.v1", "context": selected, "state": "ACTIVE"}, indent=2))
PY
  else
    log_success "CyberSpace context active: $context (workspace $workspace_id)"
  fi
}

human_status() {
  local payload
  payload="$(context_json)"
  CYBERSPACE_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["CYBERSPACE_JSON"])
active = data.get("active_context", {})
scope = data.get("scope", {})
print("SevenOS CyberSpace")
print("==================")
print(f"Active:    {active.get('key', 'none')} ({active.get('state', 'MISS')})")
persona = data.get("persona", {})
persona_active = persona.get("active", {})
print(f"Persona:   {persona_active.get('title', 'Safe Audit')} · {persona.get('session', 'persistent')}")
print(f"Workspace: {data.get('workspace')}")
print(f"Scope:     {scope.get('state')} · active={scope.get('active')} · targets={scope.get('target_count')}")
print()
print("Contexts")
for item in data.get("workspaces", []):
    print(f"  {item.get('workspace')}: {item.get('title'):<20} {item.get('key'):<10} {item.get('purpose')}")
print()
print("Use: seven shield context recon")
PY
}

human_hud() {
  local payload
  payload="$(context_json)"
  CYBERSPACE_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["CYBERSPACE_JSON"])
active = data.get("active_context", {})
scope = data.get("scope", {})
print("CYBERSPACE HUD")
print("==============")
print(f"Context : {active.get('key', 'none')} / {active.get('state', 'MISS')}")
persona = data.get("persona", {})
persona_active = persona.get("active", {})
print(f"Persona : {persona_active.get('key', 'safe')} / {persona.get('session', 'persistent')}")
print(f"Scope   : {scope.get('state')} / active={scope.get('active')} / targets={scope.get('target_count')}")
print(f"Posture : run `seven shield dashboard`")
print(f"Reports : {data.get('workspace')}/Reports")
print(f"Sandbox : seven shield lab --preset offline")
PY
}

layout_preview() {
  local context="${1:-}"
  if [[ -z "$context" ]]; then
    context="${CONTEXT:-recon}"
  fi
  local payload
  payload="$(context_json)"
  CYBERSPACE_JSON="$payload" python - "$context" <<'PY'
import json
import os
import sys

data = json.loads(os.environ["CYBERSPACE_JSON"])
context = sys.argv[1]
item = next((row for row in data.get("workspaces", []) if row.get("key") == context), None)
if not item:
    raise SystemExit(f"Unknown CyberSpace context: {context}")
payload = {
    "schema": "sevenos.cyberspace-layout.v1",
    "context": item,
    "layout": [
        {"zone": "left", "role": "primary terminal", "command": "kitty"},
        {"zone": "right-top", "role": "context tools", "command": item.get("actions", ["seven shield dashboard"])[0]},
        {"zone": "right-bottom", "role": "logs and notes", "command": "seven shield report"},
        {"zone": "floating", "role": "scope and rules", "command": "seven shield scope"},
    ],
}
print(json.dumps(payload, indent=2))
PY
}

case "$ACTION" in
  status|mode)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      context_json
    else
      human_status
    fi
    ;;
  workspaces)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      context_json | python -c 'import json,sys; data=json.load(sys.stdin); print(json.dumps({"schema":"sevenos.cyberspace-workspaces.v1","workspaces":data["workspaces"]}, indent=2))'
    else
      human_status
    fi
    ;;
  context)
    activate_context "$CONTEXT"
    ;;
  layout)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      layout_preview "$CONTEXT"
    else
      layout_preview "$CONTEXT" | python -c 'import json,sys; data=json.load(sys.stdin); print("SevenOS CyberSpace Layout"); print("==========================="); print("Context: {}".format(data["context"]["title"])); [print("  {zone:<12} {role:<18} {command}".format(**item)) for item in data["layout"]]'
    fi
    ;;
  hud)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      context_json | python -c 'import json,sys; data=json.load(sys.stdin); print(json.dumps({"schema":"sevenos.cyberspace-hud.v1","active_context":data["active_context"],"persona":data["persona"],"scope":data["scope"],"workspace":data["workspace"]}, indent=2))'
    else
      human_hud
    fi
    ;;
  *)
    log_error "Unknown CyberSpace action: $ACTION"
    usage
    exit 1
    ;;
esac
