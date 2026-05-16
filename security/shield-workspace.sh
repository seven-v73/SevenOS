#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0

WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
STATE_DIR="$WORKSPACE/.sevenos"
POLICY_FILE="$STATE_DIR/shield.json"
SCOPE_FILE="$STATE_DIR/scope.json"
CHECKLIST_FILE="$STATE_DIR/SHIELD_CHECKLIST.md"
SANDBOX_FILE="$STATE_DIR/SANDBOXES.md"
LAUNCHER_DIR="$STATE_DIR/launchers"

usage() {
  cat <<'EOF'
SevenOS Shield Workspace

Usage:
  seven shield bootstrap
  seven shield workspace [--json]
  ./security/shield-workspace.sh [status|bootstrap] [--json]

Creates a non-destructive Shield workspace contract: local policy JSON,
checklist, sandbox notes and safe launchers for future Seven Hub actions.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|workspace) ACTION="status" ;;
    bootstrap) ACTION="bootstrap" ;;
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown Shield workspace option: $1"; usage; exit 1 ;;
  esac
  shift
done

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

file_state() {
  local path="$1"
  [[ -s "$path" ]] && printf OK || printf MISS
}

executable_state() {
  local path="$1"
  [[ -x "$path" ]] && printf OK || printf MISS
}

command_state() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 && printf OK || printf MISS
}

write_policy() {
  if is_dry_run; then
    printf 'write %q\n' "$POLICY_FILE"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  cat > "$POLICY_FILE" <<EOF
{
  "schema": "sevenos.shield-workspace.v1",
  "workspace": "$WORKSPACE",
  "principles": [
    "audit before action",
    "isolate unknown workloads",
    "preserve evidence",
    "never attack systems without permission"
  ],
  "presets": {
    "web": {
      "command": "seven shield lab --preset web",
      "purpose": "browser and web application assessment workspace"
    },
    "forensics": {
      "command": "seven shield lab --preset forensics",
      "purpose": "evidence-safe analysis workspace"
    },
    "offline": {
      "command": "seven shield lab --preset offline",
      "purpose": "network-isolated notes and sample triage"
    }
  },
  "next": [
    "seven improve security --apply --yes",
    "seven shield enable",
    "seven profile install shield",
    "seven shield status"
  ]
}
EOF
}

write_scope() {
  if is_dry_run; then
    printf 'write %q\n' "$SCOPE_FILE"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  cat > "$SCOPE_FILE" <<EOF
{
  "schema": "sevenos.shield-scope.v1",
  "workspace": "$WORKSPACE",
  "active": false,
  "owner": "",
  "engagement": "",
  "time_window": "",
  "targets": [],
  "excluded": [],
  "rules": [
    "authorized targets only",
    "document owner and time window before scanning",
    "keep captures and reports inside the Shield workspace",
    "prefer offline labs for unknown samples"
  ],
  "created_at": "$(date -Is)"
}
EOF
}

write_checklist() {
  if is_dry_run; then
    printf 'write %q\n' "$CHECKLIST_FILE"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  cat > "$CHECKLIST_FILE" <<EOF
# SevenOS Shield Checklist

Shield is the SevenOS trust layer: firewall, sandbox, audit tools and safe labs.

## Baseline

- [ ] Install security packages: \`seven improve security --apply --yes\`
- [ ] Enable firewall posture: \`seven shield enable\`
- [ ] Complete Shield profile: \`seven profile install shield\`
- [ ] Open a web lab: \`seven shield lab --preset web\`
- [ ] Define audit scope: \`seven shield scope\`

## Trust Rules

- Audit before action.
- Use private labs for unknown files or targets.
- Keep reports under \`$WORKSPACE/Reports\`.
- Keep captures under \`$WORKSPACE/Captures\`.
- Never scan networks or systems without authorization.
- Network audit launchers only run against targets listed in \`$SCOPE_FILE\`.

## OS Integration

- Hub action source: \`seven shield plan --json\`
- Status source: \`seven shield status --json\`
- Workspace source: \`seven shield workspace --json\`
- Scope source: \`seven shield scope --json\`
EOF
}

write_sandbox_notes() {
  if is_dry_run; then
    printf 'write %q\n' "$SANDBOX_FILE"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  cat > "$SANDBOX_FILE" <<EOF
# SevenOS Shield Sandboxes

SevenOS uses a layered sandbox strategy:

- Firejail for quick user-facing application isolation.
- Bubblewrap for namespace isolation and Flatpak-style flows.
- Cyber Lab workspaces for controlled testing folders.

Recommended commands:

\`\`\`bash
seven shield lab --preset web
seven shield lab --preset forensics
seven shield lab --preset offline
\`\`\`
EOF
}

write_launchers() {
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$LAUNCHER_DIR"
    printf 'write %q\n' "$LAUNCHER_DIR/secure-browser.sh"
    printf 'write %q\n' "$LAUNCHER_DIR/network-audit.sh"
    printf 'chmod +x %q %q\n' "$LAUNCHER_DIR/secure-browser.sh" "$LAUNCHER_DIR/network-audit.sh"
    return 0
  fi

  mkdir -p "$LAUNCHER_DIR"
  cat > "$LAUNCHER_DIR/secure-browser.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if command -v firejail >/dev/null 2>&1; then
  exec firejail --private="${HOME}/ShieldLab/Labs/browser" firefox
fi

printf 'Firejail is missing. Install it with: seven improve security --apply --yes\n' >&2
exec xdg-open "${HOME}/ShieldLab" >/dev/null 2>&1
EOF

  cat > "$LAUNCHER_DIR/network-audit.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

target="${1:-}"
scope_file="${HOME}/ShieldLab/.sevenos/scope.json"
if [[ -z "$target" ]]; then
  printf 'Usage: %s <authorized-target>\n' "$0" >&2
  exit 1
fi

if ! python - "$scope_file" "$target" <<'PY'
import json
import sys
from pathlib import Path

scope = Path(sys.argv[1])
target = sys.argv[2]
if not scope.is_file():
    print(f"Shield scope missing: {scope}", file=sys.stderr)
    raise SystemExit(1)
try:
    data = json.loads(scope.read_text())
except json.JSONDecodeError:
    print(f"Shield scope is not valid JSON: {scope}", file=sys.stderr)
    raise SystemExit(1)
targets = set(data.get("targets") or [])
if not data.get("active") or target not in targets:
    print("Target is not active in Shield scope.", file=sys.stderr)
    print("Edit scope first: seven shield scope", file=sys.stderr)
    raise SystemExit(1)
PY
then
  exit 1
fi

if ! command -v nmap >/dev/null 2>&1; then
  printf 'nmap is missing. Install Shield tools with: seven profile install shield\n' >&2
  exit 1
fi

exec nmap -A "$target"
EOF
  chmod +x "$LAUNCHER_DIR/secure-browser.sh" "$LAUNCHER_DIR/network-audit.sh"
}

bootstrap() {
  if is_dry_run; then
    printf 'mkdir -p %q %q %q %q %q\n' "$WORKSPACE" "$WORKSPACE/Labs" "$WORKSPACE/Reports" "$WORKSPACE/Captures" "$WORKSPACE/Evidence"
  else
    mkdir -p "$WORKSPACE/Labs" "$WORKSPACE/Reports" "$WORKSPACE/Captures" "$WORKSPACE/Evidence"
  fi

  write_policy
  write_scope
  write_checklist
  write_sandbox_notes
  write_launchers

  if ! is_dry_run; then
    "$ROOT_DIR/scripts/events.sh" log \
      --source shield \
      --type workspace \
      --state OK \
      --message "Shield workspace bootstrapped" \
      --command "seven shield bootstrap" >/dev/null || true
  fi

  log_success "Shield workspace ready: $WORKSPACE"
}

status_json() {
  printf '{'
  printf '"schema":"sevenos.shield-workspace.v1",'
  printf '"workspace":%s,' "$(printf '%s' "$WORKSPACE" | json_string)"
  printf '"state_dir":%s,' "$(printf '%s' "$STATE_DIR" | json_string)"
  printf '"policy":%s,' "$(file_state "$POLICY_FILE" | json_string)"
  printf '"scope":%s,' "$(file_state "$SCOPE_FILE" | json_string)"
  printf '"checklist":%s,' "$(file_state "$CHECKLIST_FILE" | json_string)"
  printf '"sandboxes":%s,' "$(file_state "$SANDBOX_FILE" | json_string)"
  printf '"secure_browser_launcher":%s,' "$(executable_state "$LAUNCHER_DIR/secure-browser.sh" | json_string)"
  printf '"network_audit_launcher":%s,' "$(executable_state "$LAUNCHER_DIR/network-audit.sh" | json_string)"
  printf '"firejail":%s,' "$(command_state firejail | json_string)"
  printf '"bubblewrap":%s,' "$(command_state bwrap | json_string)"
  printf '"nmap":%s,' "$(command_state nmap | json_string)"
  printf '"bootstrap_command":"seven shield bootstrap"'
  printf '}\n'
}

status_human() {
  printf 'SevenOS Shield Workspace\n'
  printf '========================\n'
  printf 'Workspace:  %s\n' "$WORKSPACE"
  printf 'Policy:     %s\n' "$(file_state "$POLICY_FILE")"
  printf 'Scope:      %s\n' "$(file_state "$SCOPE_FILE")"
  printf 'Checklist:  %s\n' "$(file_state "$CHECKLIST_FILE")"
  printf 'Sandboxes:  %s\n' "$(file_state "$SANDBOX_FILE")"
  printf 'Browser:    %s\n' "$(executable_state "$LAUNCHER_DIR/secure-browser.sh")"
  printf 'Audit:      %s\n' "$(executable_state "$LAUNCHER_DIR/network-audit.sh")"
  printf '\nNext: seven shield bootstrap\n'
}

case "$ACTION" in
  bootstrap) bootstrap ;;
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      status_json
    else
      status_human
    fi
    ;;
esac
