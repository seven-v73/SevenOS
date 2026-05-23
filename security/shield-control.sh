#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-dashboard}"
JSON_OUTPUT=0
WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"

usage() {
  cat <<'EOF'
SevenOS Shield Control

Usage:
  seven shield dashboard
  seven shield dashboard --json
  seven shield open
  seven shield labs
  seven shield tools
  seven shield persona
  seven shield scope
  seven shield network
  seven shield evidence
  seven shield optional-tools
  seven shield toolchain
  seven shield bundles
  seven shield wrappers
  seven shield tool-doctor
  seven shield performance
  seven shield scope --json
  seven shield report

Shield Control is the native cybersecurity workspace surface. It aggregates
trust posture, lab presets, authorized scope, workspace files, launchers and
next actions.
EOF
}

shift_if_action() {
  case "${1:-}" in
    dashboard|open|labs|tools|persona|scope|network|evidence|optional-tools|toolchain|bundles|wrappers|tool-doctor|performance|report)
      ACTION="$1"
      shift
      ;;
  esac
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --json|json) JSON_OUTPUT=1 ;;
      -h|--help|help) usage; exit 0 ;;
      *) log_error "Unknown Shield Control option: $1"; usage; exit 1 ;;
    esac
    shift
  done
}

json_dashboard() {
  SEVENOS_ROOT="$ROOT_DIR" SEVENOS_SHIELD_WORKSPACE="$WORKSPACE" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
workspace = Path(os.environ["SEVENOS_SHIELD_WORKSPACE"]).expanduser()
state_dir = workspace / ".sevenos"


def command_json(command, fallback):
    result = subprocess.run(command, cwd=root, text=True, capture_output=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback


def command_exists(name):
    return subprocess.run(["bash", "-lc", f"command -v {name} >/dev/null 2>&1"], check=False).returncode == 0


def path_state(path):
    if path.is_file() or path.is_dir():
        return "OK"
    return "MISS"


def executable_state(path):
    return "OK" if path.is_file() and os.access(path, os.X_OK) else "MISS"


def load_scope(path):
    fallback = {
        "schema": "sevenos.shield-scope.v1",
        "workspace": str(workspace),
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
        "state": "MISS",
        "path": str(path),
    }
    if not path.is_file():
        return fallback
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        fallback["state"] = "INVALID"
        return fallback
    data.setdefault("schema", "sevenos.shield-scope.v1")
    data.setdefault("workspace", str(workspace))
    data.setdefault("active", False)
    data.setdefault("owner", "")
    data.setdefault("engagement", "")
    data.setdefault("time_window", "")
    data.setdefault("targets", [])
    data.setdefault("excluded", [])
    data.setdefault("rules", fallback["rules"])
    data["state"] = "ACTIVE" if data.get("active") else "DRAFT"
    data["path"] = str(path)
    data["target_count"] = len(data.get("targets") or [])
    return data


shield = command_json([str(root / "bin/seven-daemon"), "shield", "--json"], {"percent": 0, "posture": "unknown", "checks": []})
plan = command_json([str(root / "bin/seven-daemon"), "shield-plan", "--json"], {"summary": {}, "next": []})
profile = command_json([str(root / "bin/seven-daemon"), "profiles", "--json"], {"profiles": []})
persona = command_json([str(root / "security/shield-persona.sh"), "status", "--json"], {"state": "MISS", "active": {"key": "safe", "title": "Safe Audit"}, "session": "persistent"})
personas = command_json([str(root / "security/shield-persona.sh"), "personas", "--json"], {"personas": []})
scope = command_json([str(root / "security/shield-scope.sh"), "status", "--json"], {"state": "MISS", "active": False, "targets": [], "target_count": 0})
network = command_json([str(root / "security/shield-network-guard.sh"), "status", "--json"], {"state": "MISS"})
evidence = command_json([str(root / "security/shield-evidence.sh"), "status", "--json"], {"state": "MISS", "items": 0})
optional_tools = command_json([str(root / "security/shield-optional-tools.sh"), "status", "--json"], {"state": "MISS", "missing": []})
toolchain = command_json([str(root / "security/shield-toolchain.sh"), "status", "--json"], {"state": "MISS", "sources": []})
bundles = command_json([str(root / "security/shield-bundles.sh"), "status", "--json"], {"schema": "sevenos.shield-bundles.v1", "bundles": []})
wrappers = command_json([str(root / "security/shield-wrappers.sh"), "status", "--json"], {"state": "MISS", "wrappers": []})
tool_doctor = command_json([str(root / "security/shield-tool-doctor.sh"), "--json"], {"state": "MISS", "overall": 0, "domains": []})
performance = command_json([str(root / "security/shield-performance.sh"), "status", "--json"], {"mode": "normal"})

shield_profile = {}
for item in profile.get("profiles", []):
    if item.get("key") == "shield":
        shield_profile = item
        break

labs_root = Path.home() / "SevenOS-Labs" / "cyber"
lab_presets = [
    {
        "key": "web",
        "title": "Web Lab",
        "network": "enabled",
        "command": "seven shield lab --preset web",
        "purpose": "Browser and web application assessment workspace.",
    },
    {
        "key": "forensics",
        "title": "Forensics Lab",
        "network": "offline",
        "command": "seven shield lab --preset forensics",
        "purpose": "Evidence-safe analysis workspace with networking disabled.",
    },
    {
        "key": "reversing",
        "title": "Reversing Lab",
        "network": "offline",
        "command": "seven shield lab --preset reversing",
        "purpose": "Binary and sample triage workspace with networking disabled.",
    },
    {
        "key": "offline",
        "title": "Offline Lab",
        "network": "offline",
        "command": "seven shield lab --preset offline",
        "purpose": "General isolated notes and sample triage.",
    },
]

tool_groups = [
    {
        "key": "audit",
        "title": "Audit",
        "tools": [
            {"name": "nmap", "state": "OK" if command_exists("nmap") else "MISS", "command": "nmap"},
            {"name": "wireshark", "state": "OK" if command_exists("wireshark") else "MISS", "command": "wireshark"},
            {"name": "tcpdump", "state": "OK" if command_exists("tcpdump") else "MISS", "command": "tcpdump"},
        ],
    },
    {
        "key": "web",
        "title": "Web",
        "tools": [
            {"name": "burpsuite", "state": "OK" if command_exists("burpsuite") else "MISS", "command": "burpsuite"},
            {"name": "zaproxy", "state": "OK" if command_exists("zaproxy") else "MISS", "command": "zaproxy"},
            {"name": "sqlmap", "state": "OK" if command_exists("sqlmap") else "MISS", "command": "sqlmap"},
        ],
    },
    {
        "key": "sandbox",
        "title": "Sandbox",
        "tools": [
            {"name": "firejail", "state": "OK" if command_exists("firejail") else "MISS", "command": "firejail"},
            {"name": "bubblewrap", "state": "OK" if command_exists("bwrap") else "MISS", "command": "bwrap"},
        ],
    },
]

workspace_state = {
    "root": str(workspace),
    "state_dir": str(state_dir),
    "policy": path_state(state_dir / "shield.json"),
    "scope": path_state(state_dir / "scope.json"),
    "checklist": path_state(state_dir / "SHIELD_CHECKLIST.md"),
    "sandboxes": path_state(state_dir / "SANDBOXES.md"),
    "secure_browser_launcher": executable_state(state_dir / "launchers" / "secure-browser.sh"),
    "network_audit_launcher": executable_state(state_dir / "launchers" / "network-audit.sh"),
    "reports": path_state(workspace / "Reports"),
    "captures": path_state(workspace / "Captures"),
    "evidence": path_state(workspace / "Evidence"),
    "labs_root": str(labs_root),
}

quick_actions = [
    {"key": "open", "title": "Open Shield workspace", "command": "seven shield open", "impact": "safe"},
    {"key": "persona", "title": "Switch Shield persona", "command": "seven shield personas", "impact": "safe"},
    {"key": "network", "title": "Review Network Guard", "command": "seven shield network", "impact": "safe"},
    {"key": "evidence", "title": "Open Evidence Manager", "command": "seven shield evidence", "impact": "safe"},
    {"key": "optional-tools", "title": "Review Optional Tools", "command": "seven shield optional-tools", "impact": "packages"},
    {"key": "toolchain", "title": "Open Toolchain Sources", "command": "seven shield toolchain", "impact": "safe"},
    {"key": "bundles", "title": "Review Shield Bundles", "command": "seven shield bundles", "impact": "safe"},
    {"key": "wrappers", "title": "Install GUI Wrappers", "command": "seven shield wrappers install", "impact": "safe"},
    {"key": "tool-doctor", "title": "Run Tool Doctor", "command": "seven shield tool-doctor", "impact": "safe"},
    {"key": "performance", "title": "Apply Performance Mode", "command": "seven shield performance apply", "impact": "safe"},
    {"key": "session", "title": "Toggle ephemeral session", "command": "seven shield session ephemeral", "impact": "safe"},
    {"key": "scope", "title": "Review audit scope", "command": "seven shield scope", "impact": "safe"},
    {"key": "lab-web", "title": "Open Web Lab", "command": "seven shield lab --preset web", "impact": "safe"},
    {"key": "lab-forensics", "title": "Open Forensics Lab", "command": "seven shield lab --preset forensics", "impact": "safe"},
    {"key": "report", "title": "Create Shield report", "command": "seven shield report", "impact": "safe"},
    {"key": "bootstrap", "title": "Bootstrap Shield workspace", "command": "seven shield bootstrap", "impact": "safe"},
    {"key": "enable", "title": "Enable Shield posture", "command": "seven shield enable", "impact": "changes"},
]

payload = {
    "schema": "sevenos.shield-control.v1",
    "state": "ready" if shield.get("posture") in ("trusted", "partial") else "needs-setup",
    "mode": "shield",
    "posture": {
        "label": shield.get("posture", "unknown"),
        "percent": shield.get("percent", 0),
        "checks": shield.get("checks", []),
    },
    "profile": {
        "state": shield_profile.get("state", "MISS"),
        "installed": shield_profile.get("installed", 0),
        "total": shield_profile.get("total", 0),
        "workspace": shield_profile.get("workspace", str(workspace)),
        "apps": shield_profile.get("apps", []),
        "missing": (shield_profile.get("packages") or {}).get("missing_count", 0),
    },
    "workspace": workspace_state,
    "persona": persona,
    "personas": personas.get("personas", []),
    "scope": scope,
    "network": network,
    "evidence": evidence,
    "optional_tools": optional_tools,
    "toolchain": toolchain,
    "bundles": bundles,
    "wrappers": wrappers,
    "tool_doctor": tool_doctor,
    "performance": performance,
    "labs": lab_presets,
    "tools": tool_groups,
    "plan": {
        "summary": plan.get("summary", {}),
        "next": plan.get("next", []),
    },
    "quick_actions": quick_actions,
    "principles": [
        "audit before action",
        "isolate unknown workloads",
        "preserve evidence",
        "authorized systems only",
    ],
    "writer": "shield-control",
}

print(json.dumps(payload, indent=2))
PY
}

dashboard_human() {
  local payload
  payload="$(json_dashboard)"
  SHIELD_CONTROL_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["SHIELD_CONTROL_JSON"])
posture = data.get("posture", {})
profile = data.get("profile", {})
workspace = data.get("workspace", {})
persona = data.get("persona", {})
active_persona = persona.get("active", {})
scope = data.get("scope", {})
network = data.get("network", {})
evidence = data.get("evidence", {})
optional_tools = data.get("optional_tools", {})
toolchain = data.get("toolchain", {})
bundles = data.get("bundles", {})
wrappers = data.get("wrappers", {})
tool_doctor = data.get("tool_doctor", {})
performance = data.get("performance", {})
plan = data.get("plan", {}).get("summary", {})

print("SevenOS Shield Control")
print("======================")
print(f"Posture:   {posture.get('label', 'unknown')} ({posture.get('percent', 0)}%)")
print(f"Profile:   {profile.get('state', 'MISS')} {profile.get('installed', 0)}/{profile.get('total', 0)}")
print(f"Workspace: {workspace.get('root')}")
print(f"Persona:   {active_persona.get('title', 'Safe Audit')} · {persona.get('session', 'persistent')}")
print(f"Scope:     {scope.get('state', 'MISS')} · {scope.get('target_count', 0)} target(s)")
print(f"Network:   {network.get('state', 'MISS')} · {network.get('persona', {}).get('policy', 'normal-guarded')}")
print(f"Evidence:  {evidence.get('items', 0)} item(s)")
print(f"Optional:  {len(optional_tools.get('missing', []))} missing")
print(f"Sources:   {sum(1 for item in toolchain.get('sources', []) if item.get('state') == 'OK')}/{len(toolchain.get('sources', []))} ready")
print(f"Bundles:   {sum(1 for item in bundles.get('bundles', []) if item.get('state') == 'OK')}/{len(bundles.get('bundles', []))} complete")
print(f"Tools:     {tool_doctor.get('overall', 0)}% · wrappers {sum(1 for item in wrappers.get('wrappers', []) if item.get('state') == 'OK')}/{len(wrappers.get('wrappers', []))}")
print(f"Perf:      {performance.get('mode', 'normal')}")
print(f"Open plan: {plan.get('total', 0)} action(s)")
print()
print("Quick actions")
for item in data.get("quick_actions", [])[:6]:
    print(f"  {item.get('title'):<28} {item.get('command')}")
print()
print("Labs")
for item in data.get("labs", []):
    print(f"  {item.get('title'):<16} {item.get('network'):<8} {item.get('command')}")
PY
}

open_workspace() {
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$WORKSPACE"
    printf 'xdg-open %q\n' "$WORKSPACE"
    return 0
  fi
  mkdir -p "$WORKSPACE"
  xdg-open "$WORKSPACE" >/dev/null 2>&1 || printf '%s\n' "$WORKSPACE"
}

create_report() {
  local report_dir report_file timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  report_dir="$WORKSPACE/Reports"
  report_file="$report_dir/shield-report-$timestamp.md"
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$report_dir"
    printf 'write %q\n' "$report_file"
    return 0
  fi
  mkdir -p "$report_dir"
  cat > "$report_file" <<EOF
# SevenOS Shield Report

Created: $(date -Is)
Workspace: $WORKSPACE
Scope: $WORKSPACE/.sevenos/scope.json

## Scope

- Authorized target(s):
- Engagement owner:
- Time window:

## Findings

| Severity | Finding | Evidence | Recommendation |
|----------|---------|----------|----------------|
|          |         |          |                |

## Evidence

- Captures:
- Notes:
- Commands:

## Closure

- [ ] Sensitive files reviewed
- [ ] Report shared intentionally
- [ ] Lab cleaned or archived
EOF
  printf '%s\n' "$report_file"
}

scope_output() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    json_dashboard | python -c 'import json,sys; data=json.load(sys.stdin); print(json.dumps({"schema":"sevenos.shield-scope-view.v1","scope":data["scope"],"workspace":data["workspace"]}, indent=2))'
    return 0
  fi

  json_dashboard | python -c 'import json,sys
data = json.load(sys.stdin)
scope = data.get("scope", {})
print("SevenOS Shield Scope")
print("====================")
print("State:      {}".format(scope.get("state", "MISS")))
print("Active:     {}".format(scope.get("active", False)))
print("Owner:      {}".format(scope.get("owner") or "-"))
print("Engagement: {}".format(scope.get("engagement") or "-"))
print("Window:     {}".format(scope.get("time_window") or "-"))
print("Path:       {}".format(scope.get("path")))
print()
print("Targets")
targets = scope.get("targets") or []
if targets:
    [print("  {}".format(target)) for target in targets]
else:
    print("  none yet")
print()
print("Rules")
[print("  - {}".format(rule)) for rule in scope.get("rules", [])]
print()
print("Edit the JSON scope file, then set active=true only for authorized work.")'
}

shift_if_action "$@"

case "$ACTION" in
  dashboard)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      json_dashboard
    else
      dashboard_human
    fi
    ;;
  open)
    open_workspace
    ;;
  labs)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      json_dashboard | python -c 'import json,sys; print(json.dumps({"schema":"sevenos.shield-labs.v1","labs":json.load(sys.stdin)["labs"]}, indent=2))'
    else
      json_dashboard | python -c 'import json,sys; data=json.load(sys.stdin); [print(f"{x[\"title\"]:<16} {x[\"network\"]:<8} {x[\"command\"]}") for x in data["labs"]]'
    fi
    ;;
  tools)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      json_dashboard | python -c 'import json,sys; print(json.dumps({"schema":"sevenos.shield-tools.v1","tools":json.load(sys.stdin)["tools"]}, indent=2))'
    else
      json_dashboard | python -c 'import json,sys; data=json.load(sys.stdin); [print(f"{group[\"title\"]}\\n" + "\\n".join(f"  {tool[\"state\"]:<4} {tool[\"name\"]}" for tool in group["tools"])) for group in data["tools"]]'
    fi
    ;;
  persona)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      json_dashboard | python -c 'import json,sys; data=json.load(sys.stdin); print(json.dumps({"schema":"sevenos.shield-persona-view.v1","active":data["persona"],"personas":data["personas"]}, indent=2))'
    else
      "$ROOT_DIR/security/shield-persona.sh" status
    fi
    ;;
  scope)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-scope.sh" status --json; else "$ROOT_DIR/security/shield-scope.sh" status; fi
    ;;
  network)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-network-guard.sh" status --json; else "$ROOT_DIR/security/shield-network-guard.sh" status; fi
    ;;
  evidence)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-evidence.sh" status --json; else "$ROOT_DIR/security/shield-evidence.sh" status; fi
    ;;
  optional-tools)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-optional-tools.sh" status --json; else "$ROOT_DIR/security/shield-optional-tools.sh" status; fi
    ;;
  toolchain)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-toolchain.sh" status --json; else "$ROOT_DIR/security/shield-toolchain.sh" status; fi
    ;;
  bundles)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-bundles.sh" status --json; else "$ROOT_DIR/security/shield-bundles.sh" status; fi
    ;;
  wrappers)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-wrappers.sh" status --json; else "$ROOT_DIR/security/shield-wrappers.sh" status; fi
    ;;
  tool-doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-tool-doctor.sh" --json; else "$ROOT_DIR/security/shield-tool-doctor.sh"; fi
    ;;
  performance)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then "$ROOT_DIR/security/shield-performance.sh" status --json; else "$ROOT_DIR/security/shield-performance.sh" status; fi
    ;;
  report)
    create_report
    ;;
  *)
    log_error "Unknown Shield Control action: $ACTION"
    usage
    exit 1
    ;;
esac
