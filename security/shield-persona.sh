#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
PERSONA=""
SESSION_MODE=""

WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
STATE_DIR="$WORKSPACE/.sevenos"
PERSONA_FILE="$STATE_DIR/persona.json"
ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/shield.env"
JSON_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/shield-persona.json"

usage() {
  cat <<'EOF'
SevenOS Shield Persona Engine

Usage:
  seven shield persona [--json]
  seven shield personas [--json]
  seven shield persona <safe|research|lab|osint|forensics|malware|devsecops|redteam|blueteam>
  seven shield session [persistent|ephemeral] [--json]
  seven shield cleanup [--json]
  security/shield-persona.sh [status|personas|set|session|cleanup] [...]

Shield Persona adapts the cybersecurity mini OS without copying Kali or
BlackArch. It changes visible intent, isolation expectations, networking
posture and workspace behavior while staying scope-first and safe by default.
EOF
}

shift_if_action() {
  case "${1:-}" in
    status|persona) ACTION="status"; shift ;;
    personas) ACTION="personas"; shift ;;
    set) ACTION="set"; shift ;;
    session) ACTION="session"; shift ;;
    cleanup) ACTION="cleanup"; shift ;;
  esac

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --json|json) JSON_OUTPUT=1 ;;
      -h|--help|help) usage; exit 0 ;;
      persistent|ephemeral)
        SESSION_MODE="$1"
        ;;
      safe|research|lab|osint|forensics|malware|devsecops|redteam|blueteam)
        PERSONA="$1"
        ;;
      *)
        log_error "Unknown Shield persona option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

personas_json() {
  python - <<'PY'
import json

personas = [
    {
        "key": "safe",
        "title": "Safe Audit",
        "tagline": "Defensive baseline and posture review.",
        "session_default": "persistent",
        "network": "normal-guarded",
        "isolation": "standard-sandbox",
        "visual": "blue guarded SOC",
        "workspaces": ["Posture", "Logs", "Reports"],
        "tools": ["lynis", "ufw", "journalctl", "rkhunter"],
        "actions": ["seven shield status", "seven shield enable", "seven shield report"],
        "rules": ["no intrusive scans", "local system first", "report every change"],
    },
    {
        "key": "research",
        "title": "Security Research",
        "tagline": "CVE notes, references, controlled reproduction planning.",
        "session_default": "persistent",
        "network": "vpn-recommended",
        "isolation": "browser-sandbox",
        "visual": "indigo intelligence board",
        "workspaces": ["References", "Notes", "Lab Plan"],
        "tools": ["firefox", "whois", "nmap", "obsidian"],
        "actions": ["seven shield context intel", "seven shield scope", "seven shield report"],
        "rules": ["document sources", "separate research from execution", "scope before reproduction"],
    },
    {
        "key": "lab",
        "title": "Pentest Lab",
        "tagline": "Authorized testing against declared targets only.",
        "session_default": "persistent",
        "network": "scoped-lab",
        "isolation": "lab-home",
        "visual": "amber lab console",
        "workspaces": ["Target", "Proxy", "Evidence", "Report"],
        "tools": ["nmap", "burpsuite", "zaproxy", "sqlmap", "metasploit"],
        "actions": ["seven shield scope", "seven shield lab --preset web", "seven shield report"],
        "rules": ["authorized targets only", "captures stay in Shield workspace", "no scan without active scope"],
    },
    {
        "key": "osint",
        "title": "OSINT",
        "tagline": "Open-source intelligence with privacy-aware collection.",
        "session_default": "ephemeral",
        "network": "vpn-or-tor-recommended",
        "isolation": "private-browser",
        "visual": "quiet map wall",
        "workspaces": ["Search", "Sources", "Timeline", "Report"],
        "tools": ["firefox", "whois", "exiftool", "recon-ng"],
        "actions": ["seven shield context recon", "seven shield report"],
        "rules": ["respect platform rules", "record provenance", "clear ephemeral cache after session"],
    },
    {
        "key": "forensics",
        "title": "Forensics",
        "tagline": "Evidence-safe offline analysis and reporting.",
        "session_default": "persistent",
        "network": "offline-preferred",
        "isolation": "read-only-evidence",
        "visual": "cool evidence desk",
        "workspaces": ["Evidence", "Timeline", "Artifacts", "Report"],
        "tools": ["sleuthkit", "volatility3", "yara", "exiftool", "testdisk"],
        "actions": ["seven shield lab --preset forensics", "seven shield report"],
        "rules": ["preserve originals", "hash before analysis", "write notes to Reports"],
    },
    {
        "key": "malware",
        "title": "Malware Triage",
        "tagline": "Offline sample triage with disposable workspace defaults.",
        "session_default": "ephemeral",
        "network": "offline-enforced",
        "isolation": "disposable-lab",
        "visual": "red sealed sandbox",
        "workspaces": ["Quarantine", "Static", "Notes", "Report"],
        "tools": ["yara", "radare2", "rizin", "ghidra", "strings"],
        "actions": ["seven shield lab --preset offline", "seven shield cleanup"],
        "rules": ["offline only", "never execute unknown samples on host", "destroy ephemeral lab after closure"],
    },
    {
        "key": "devsecops",
        "title": "DevSecOps",
        "tagline": "Code, dependency and service security review.",
        "session_default": "persistent",
        "network": "normal-guarded",
        "isolation": "project-sandbox",
        "visual": "green pipeline dashboard",
        "workspaces": ["Code", "Scan", "Services", "Report"],
        "tools": ["bandit", "trivy", "docker", "podman", "git"],
        "actions": ["seven runtime plan forge shield", "seven shield report"],
        "rules": ["prefer local test data", "separate secrets", "record remediation"],
    },
    {
        "key": "redteam",
        "title": "Red Team",
        "tagline": "Controlled adversary emulation with explicit authorization.",
        "session_default": "ephemeral",
        "network": "scope-required",
        "isolation": "scoped-lab",
        "visual": "crimson operation board",
        "workspaces": ["Scope", "Ops", "Evidence", "Report"],
        "tools": ["nmap", "metasploit", "impacket", "john", "hashcat"],
        "actions": ["seven shield scope", "seven shield context exploit", "seven shield report"],
        "rules": ["active scope required", "no persistence on third-party systems", "report every action"],
    },
    {
        "key": "blueteam",
        "title": "Blue Team",
        "tagline": "Monitoring, logs, detection and hardening.",
        "session_default": "persistent",
        "network": "defensive-monitoring",
        "isolation": "host-observe",
        "visual": "cyan SOC wall",
        "workspaces": ["Logs", "Network", "Detection", "Hardening"],
        "tools": ["journalctl", "tcpdump", "wireshark", "lynis", "rkhunter"],
        "actions": ["seven shield context logs", "seven shield enable", "seven shield report"],
        "rules": ["observe before changing", "preserve logs", "prefer least privilege"],
    },
]

print(json.dumps({"schema": "sevenos.shield-personas.v1", "personas": personas}, indent=2))
PY
}

current_json() {
  local personas active session created
  personas="$(personas_json)"
  if [[ -s "$PERSONA_FILE" ]]; then
    cat "$PERSONA_FILE"
    return 0
  fi
  active="${SEVENOS_SHIELD_PERSONA:-safe}"
  session="${SEVENOS_SHIELD_SESSION:-persistent}"
  created="$(date -Is)"
  PERSONAS_JSON="$personas" ACTIVE="$active" SESSION="$session" CREATED="$created" WORKSPACE="$WORKSPACE" python - <<'PY'
import json
import os

personas = json.loads(os.environ["PERSONAS_JSON"])["personas"]
active_key = os.environ["ACTIVE"]
persona = next((item for item in personas if item["key"] == active_key), personas[0])
print(json.dumps({
    "schema": "sevenos.shield-persona-state.v1",
    "state": "DEFAULT",
    "active": persona,
    "session": os.environ["SESSION"],
    "workspace": os.environ["WORKSPACE"],
    "created_at": os.environ["CREATED"],
    "files": {
        "persona": "",
        "env": "",
        "json": "",
    },
}, indent=2))
PY
}

write_state() {
  local persona="$1"
  local session="$2"
  local personas now
  personas="$(personas_json)"
  now="$(date -Is)"
  mkdir -p "$STATE_DIR" "$(dirname "$ENV_FILE")" "$(dirname "$JSON_FILE")"
  PERSONAS_JSON="$personas" PERSONA="$persona" SESSION="$session" NOW="$now" \
  WORKSPACE="$WORKSPACE" PERSONA_FILE="$PERSONA_FILE" ENV_FILE="$ENV_FILE" JSON_FILE="$JSON_FILE" \
  python - <<'PY' >"$PERSONA_FILE"
import json
import os

personas = json.loads(os.environ["PERSONAS_JSON"])["personas"]
key = os.environ["PERSONA"]
persona = next((item for item in personas if item["key"] == key), None)
if not persona:
    raise SystemExit(f"Unknown Shield persona: {key}")
session = os.environ["SESSION"] or persona["session_default"]
payload = {
    "schema": "sevenos.shield-persona-state.v1",
    "state": "ACTIVE",
    "active": persona,
    "session": session,
    "workspace": os.environ["WORKSPACE"],
    "updated_at": os.environ["NOW"],
    "files": {
        "persona": os.environ["PERSONA_FILE"],
        "env": os.environ["ENV_FILE"],
        "json": os.environ["JSON_FILE"],
    },
}
print(json.dumps(payload, indent=2))
PY
  cp "$PERSONA_FILE" "$JSON_FILE"
  cat >"$ENV_FILE" <<EOF
export SEVENOS_SHIELD_PERSONA="$persona"
export SEVENOS_SHIELD_SESSION="$session"
export SEVENOS_SHIELD_WORKSPACE="$WORKSPACE"
EOF
}

set_persona() {
  local persona="${PERSONA:-safe}" session
  session="$SESSION_MODE"
  if [[ -z "$session" ]]; then
    session="$(PERSONAS_JSON="$(personas_json)" PERSONA="$persona" python - <<'PY'
import json
import os
personas = json.loads(os.environ["PERSONAS_JSON"])["personas"]
item = next((row for row in personas if row["key"] == os.environ["PERSONA"]), None)
if not item:
    raise SystemExit(1)
print(item["session_default"])
PY
)"
  fi

  if is_dry_run; then
    printf 'write Shield persona %q session %q\n' "$persona" "$session"
  else
    write_state "$persona" "$session"
    "$ROOT_DIR/scripts/events.sh" log \
      --source shield \
      --type persona \
      --state OK \
      --message "Shield persona active: $persona ($session)" \
      --command "seven shield persona $persona" >/dev/null || true
  fi

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    current_json
  else
    log_success "Shield persona active: $persona ($session)"
  fi
}

set_session() {
  local session="${SESSION_MODE:-}"
  if [[ -z "$session" ]]; then
    current_json
    return 0
  fi
  local active
  active="$(current_json | python -c 'import json,sys; print(json.load(sys.stdin).get("active",{}).get("key","safe"))')"
  PERSONA="$active" SESSION_MODE="$session" set_persona
}

cleanup_ephemeral() {
  local ephemeral_dir="$WORKSPACE/Ephemeral"
  if is_dry_run; then
    printf 'rm -rf %q\n' "$ephemeral_dir"
    return 0
  fi
  mkdir -p "$WORKSPACE"
  rm -rf "$ephemeral_dir"
  mkdir -p "$ephemeral_dir"
  "$ROOT_DIR/scripts/events.sh" log \
    --source shield \
    --type cleanup \
    --state OK \
    --message "Shield ephemeral workspace cleaned" \
    --command "seven shield cleanup" >/dev/null || true

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '{"schema":"sevenos.shield-cleanup.v1","state":"OK","cleaned":"%s"}\n' "$ephemeral_dir"
  else
    log_success "Shield ephemeral workspace cleaned: $ephemeral_dir"
  fi
}

status_human() {
  local payload
  payload="$(current_json)"
  SHIELD_PERSONA_JSON="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["SHIELD_PERSONA_JSON"])
active = data.get("active", {})
print("SevenOS Shield Persona")
print("======================")
print(f"Persona:   {active.get('title')} ({active.get('key')})")
print(f"Session:   {data.get('session')}")
print(f"Network:   {active.get('network')}")
print(f"Isolation: {active.get('isolation')}")
print(f"Visual:    {active.get('visual')}")
print()
print("Rules")
for rule in active.get("rules", []):
    print(f"  - {rule}")
print()
print("Actions")
for action in active.get("actions", []):
    print(f"  {action}")
PY
}

shift_if_action "$@"

case "$ACTION" in
  status)
    if [[ -n "$PERSONA" ]]; then
      set_persona
    elif [[ "$JSON_OUTPUT" -eq 1 ]]; then
      current_json
    else
      status_human
    fi
    ;;
  personas)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      personas_json
    else
      personas_json | python -c 'import json,sys; data=json.load(sys.stdin); [print(f"{p[\"key\"]:<10} {p[\"title\"]:<20} {p[\"tagline\"]}") for p in data["personas"]]'
    fi
    ;;
  set)
    set_persona
    ;;
  session)
    if [[ "$JSON_OUTPUT" -eq 1 && -z "$SESSION_MODE" ]]; then
      current_json
    else
      set_session
    fi
    ;;
  cleanup)
    cleanup_ephemeral
    ;;
  *)
    log_error "Unknown Shield persona action: $ACTION"
    usage
    exit 1
    ;;
esac
