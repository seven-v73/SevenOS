#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

failures=0
warnings=0
JSON_OUTPUT=0
FULL_AUDIT=0

section() {
  printf '\n== %s ==\n' "$1"
}

mark_warn() {
  warnings=$((warnings + 1))
  log_warn "$*"
}

run_required() {
  local label="$1"
  shift

  printf '[CHECK] %s\n' "$label"
  if "$@"; then
    printf '[OK] %s\n' "$label"
  else
    printf '[FAIL] %s\n' "$label" >&2
    failures=$((failures + 1))
  fi
}

run_advisory() {
  local label="$1"
  shift

  printf '[CHECK] %s\n' "$label"
  if "$@"; then
    printf '[OK] %s\n' "$label"
  else
    printf '[WARN] %s\n' "$label" >&2
    warnings=$((warnings + 1))
  fi
}

readiness_summary() {
  "$ROOT_DIR/bin/seven-daemon" readiness --json | python -c '
import json
import sys

data = json.load(sys.stdin)
print(f"State: {data.get('state', 'unknown')}")
print(f"Score: {data.get('percent', data.get('score', 0))}%")
print(f"Source: {data.get('writer', 'unknown')}")
print()
print("Categories:")
categories = data.get("categories", {})
if isinstance(categories, dict):
    iterator = categories.items()
else:
    iterator = [(item.get("key", "gate"), item) for item in categories if isinstance(item, dict)]
for key, item in iterator:
    if not isinstance(item, dict):
        continue
    title = item.get("title") or key or "Gate"
    actual = item.get("percent", item.get("actual", item.get("score", 0)))
    state = item.get("state", "unknown")
    print(f"- {title}: {actual}% ({state})")
'
}

git_summary() {
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$ROOT_DIR/.git" ]]; then
    mark_warn "Git repository not detected."
    return 0
  fi

  local status
  status="$(git -C "$ROOT_DIR" status --short)"
  if [[ -z "$status" ]]; then
    printf '[OK] Git worktree clean\n'
  else
    printf '%s\n' "$status" | sed 's/^/  /'
    mark_warn "Git worktree has uncommitted changes. Commit the phase before moving on."
  fi
}

json_gate() {
  if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    "$ROOT_DIR/bin/seven-daemon" phase-gate --json
    return
  fi

  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess

ROOT = os.environ["SEVENOS_ROOT"]


def command_json(command, fallback):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback


readiness = command_json([os.path.join(ROOT, "bin/seven-daemon"), "readiness", "--json"], {"percent": 0})
experience = command_json([os.path.join(ROOT, "bin/seven-daemon"), "experience", "--json"], {"percent": 0})
control = command_json([os.path.join(ROOT, "scripts/control-plane.sh"), "--json"], {"overall": 0, "summary": {}, "actions": []})
shield = command_json([os.path.join(ROOT, "security/shield-status.sh"), "--json"], {"percent": 0, "posture": "unknown"})
server = command_json([os.path.join(ROOT, "server/seven-server.sh"), "status", "--json"], {"service": {"state": "MISS"}})
atlas = command_json([os.path.join(ROOT, "bin/seven"), "atlas", "status", "--json"], {"state": "unknown", "missing_required": []})
installer = command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "status", "--json"], {"ready": False, "mode": "foundation"})
profiles = command_json([os.path.join(ROOT, "bin/seven-daemon"), "profile-plan", "--json"], {"summary": {"total": 0}, "next": []})
packages = command_json([os.path.join(ROOT, "bin/seven-daemon"), "packages-plan", "--json"], {"summary": {"total": 0}, "next": []})
identity = command_json([os.path.join(ROOT, "scripts/identity.sh"), "current", "--json"], {"pack": {"key": "unknown"}})
stack = command_json([os.path.join(ROOT, "scripts/stack.sh"), "--json"], {"summary": {"checks_ok": 0, "checks_total": 1}})
core = command_json([os.path.join(ROOT, "scripts/core.sh"), "status", "--json"], {"state": "MISS", "components": []})


def band(value):
    try:
        value = int(value)
    except Exception:
        value = 0
    if value >= 85:
        return "strong"
    if value >= 65:
        return "workable"
    if value >= 40:
        return "fragile"
    return "blocked"


def gate(key, title, actual, target, command, severity="block", detail=""):
    passed = actual >= target if isinstance(actual, (int, float)) else actual == target
    state = "PASS" if passed else ("BLOCK" if severity == "block" else "WARN")
    return {
        "key": key,
        "title": title,
        "state": state,
        "actual": actual,
        "target": target,
        "band": band(actual) if isinstance(actual, (int, float)) else str(actual),
        "command": command,
        "detail": detail,
    }


server_state = (server.get("service") or {}).get("state", "MISS")
server_runtime_state = "RUN" if server.get("runtime_ready") else server_state
installer_mode = installer.get("mode", "foundation")
profile_total = (profiles.get("summary") or {}).get("total", 0)
package_total = (packages.get("summary") or {}).get("total", 0)
package_blocking = (packages.get("summary") or {}).get("critical", 0) + (packages.get("summary") or {}).get("high", 0)
stack_summary = stack.get("summary") or {}
stack_ok = stack_summary.get("checks_ok", 0)
stack_total = stack_summary.get("checks_total", 1)
core_state = core.get("state", "MISS")

gates = [
    gate("readiness", "OS readiness", readiness.get("percent", 0), 85, "seven core readiness", "block", "Minimum product readiness before B3."),
    gate("experience", "User experience", experience.get("percent", 0), 85, "seven experience", "block", "Shell, Hub, actions and onboarding must feel coherent."),
    gate("control", "Control plane", control.get("overall", 0), 65, "seven control", "block", "Seven Hub needs a useful prioritized decision contract."),
    gate("shield", "Trust posture", shield.get("percent", 0), 70, "seven shield plan", "block", "Security must be visible and default-safe before a higher phase."),
    {
        "key": "server",
        "title": "Seven Server backend",
        "state": "PASS" if server.get("runtime_ready") or server_state in ("READY", "RUN") else "BLOCK",
        "actual": server_runtime_state,
        "target": "RUNTIME_READY",
        "band": server_runtime_state,
        "command": "seven server plan",
        "detail": "The ecosystem needs a local OS API surface. Go/Podman/Caddy complete Forge DevOps deployment, but they are not required to prove that the local API is running.",
    },
    {
        "key": "installer",
        "title": "Installer path",
        "state": "PASS" if installer.get("ready") else ("WARN" if installer_mode != "foundation" else "BLOCK"),
        "actual": installer_mode,
        "target": "ready",
        "band": installer_mode,
        "command": "seven installer plan",
        "detail": "A real OS needs a reproducible install path, not a manual post-install story.",
    },
    {
        "key": "atlas",
        "title": "Atlas Explorer",
        "state": "PASS" if not atlas.get("missing_required") else "WARN",
        "actual": atlas.get("state", "unknown"),
        "target": "ready",
        "band": atlas.get("state", "unknown"),
        "command": "seven atlas status",
        "detail": "SevenOS keeps its seventh identity native through documents, maps, OCR and references.",
    },
    {
        "key": "profiles",
        "title": "Profile completeness",
        "state": "PASS" if profile_total == 0 else "WARN",
        "actual": profile_total,
        "target": 0,
        "band": "open" if profile_total else "strong",
        "command": "seven core profile-plan",
        "detail": "Profiles must keep moving from decorative modes to complete workspaces.",
    },
    {
        "key": "software",
        "title": "Software plan",
        "state": "PASS" if package_blocking == 0 else "WARN",
        "actual": package_blocking,
        "target": 0,
        "band": "open" if package_blocking else "strong",
        "command": "seven core packages-plan",
        "detail": "SevenPkg must explain critical and high-priority app delivery gaps. Medium bundles stay optional.",
    },
    {
        "key": "stack",
        "title": "Stack discipline",
        "state": "PASS" if stack_ok >= max(stack_total - 1, 0) else "WARN",
        "actual": f"{stack_ok}/{stack_total}",
        "target": f"{max(stack_total - 1, 0)}/{stack_total}",
        "band": "ready" if stack_ok >= max(stack_total - 1, 0) else "open",
        "command": "seven stack doctor",
        "detail": "AGS and Rust should enter in a controlled B3 order, not as parallel rewrites.",
    },
    {
        "key": "core",
        "title": "Seven Core foundation",
        "state": "PASS" if core_state in ("FOUNDATION", "READY_FOR_DAEMON") else "WARN",
        "actual": core_state,
        "target": "FOUNDATION",
        "band": core_state.lower(),
        "command": "seven core plan",
        "detail": "SevenOS needs a named system experience layer before replacing script surfaces with daemon-backed UI.",
    },
]

blocked = [item for item in gates if item["state"] == "BLOCK"]
warnings = [item for item in gates if item["state"] == "WARN"]
passed = [item for item in gates if item["state"] == "PASS"]

decision = "blocked" if blocked else "warning" if warnings else "pass"
next_commands = []
for item in gates:
    if item["state"] != "PASS" and item.get("command") not in next_commands:
        next_commands.append(item["command"])

print(json.dumps({
    "schema": "sevenos.phase-gate.v1",
    "phase": "B2",
    "next_phase": "B3 - native backend, installer readiness and active trust",
    "decision": decision,
    "summary": {
        "pass": len(passed),
        "warn": len(warnings),
        "block": len(blocked),
        "total": len(gates),
    },
    "identity": {
        "active_pack": (identity.get("pack") or {}).get("key", "unknown"),
    },
    "gates": gates,
    "next_commands": next_commands[:8],
}, indent=2))
PY
}

native_human_gate() {
  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  "$ROOT_DIR/bin/seven-daemon" phase-gate --json > "$tmp"
  python - "$tmp" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
summary = data.get("summary") or {}
gates = data.get("gates") or []
decision = data.get("decision", "unknown")

print("SevenOS Phase Gate")
print("==================")
print("Mode: native runtime")
print(f"Decision: {decision}")
print(f"Phase: {data.get('phase', 'unknown')} -> {data.get('next_phase', 'unknown')}")
print(f"Checks: {summary.get('pass', 0)} pass, {summary.get('warn', 0)} warn, {summary.get('block', 0)} block / {summary.get('total', len(gates))}")
print()

print("Gates")
for item in gates:
    state = item.get("state", "UNKNOWN")
    title = item.get("title", item.get("key", "Gate"))
    actual = item.get("actual", "?")
    target = item.get("target", "?")
    detail = item.get("detail", "")
    command = item.get("command", "")
    marker = "OK" if state == "PASS" else "WARN" if state == "WARN" else "BLOCK"
    print(f"[{marker}] {title}: {actual} / {target}")
    if detail:
        print(f"      {detail}")
    if command and state != "PASS":
        print(f"      Next: {command}")

next_commands = data.get("next_commands") or []
if next_commands:
    print()
    print("Next useful commands")
    for command in next_commands:
        print(f"  {command}")

print()
print("Deep audit")
print("  seven phase-gate --full")
PY
}

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    --full|full) FULL_AUDIT=1 ;;
    -h|--help|help)
      cat <<'EOF'
SevenOS Phase Gate

Usage:
  seven phase-gate
  seven phase-gate --json
  seven phase-gate --full
  ./scripts/phase-gate.sh [--json|--full]

By default the gate reads the daemon-owned SevenOS phase contract, so it is
fast enough for Settings, Helper, Doctor and daily use. Use --full for the
older long developer audit before a release freeze.
EOF
      exit 0
      ;;
    *) log_error "Unknown phase gate option: $arg"; exit 1 ;;
  esac
done

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  json_gate
  exit 0
fi

if [[ "$FULL_AUDIT" -ne 1 ]]; then
  native_human_gate
  exit 0
fi

printf 'SevenOS Phase Gate\n'
printf '==================\n'
printf 'Mode: full developer audit\n'
printf 'Purpose: decide whether the current foundation is ready for the next phase.\n'

section "Required Checks"
run_required "Core repository checks" "$ROOT_DIR/scripts/check.sh"
run_required "UX coherence checks" "$ROOT_DIR/scripts/ux-check.sh"
run_required "Architecture foundation doctor" "$ROOT_DIR/scripts/architecture.sh" doctor
run_required "Installer stack doctor" "$ROOT_DIR/scripts/installer-stack.sh" doctor
run_required "Seven Hub GUI scaffold doctor" "$ROOT_DIR/seven-hub/gui-stack.sh" doctor
run_required "Readiness JSON export" "$ROOT_DIR/bin/seven-daemon" readiness --json
run_required "Ecosystem foundation doctor" "$ROOT_DIR/scripts/ecosystem.sh" doctor
run_required "Deployment planner dry-run" env SEVENOS_DRY_RUN=1 "$ROOT_DIR/server/seven-deploy.sh" plan "$ROOT_DIR"

section "Advisory Checks"
run_advisory "Server dependency doctor" "$ROOT_DIR/server/seven-server.sh" doctor

section "Readiness"
readiness_summary

section "Git"
git_summary

section "Decision"
if [[ "$failures" -gt 0 ]]; then
  log_error "Phase gate blocked: $failures required check(s) failed."
  exit 1
fi

if [[ "$warnings" -gt 0 ]]; then
  log_warn "Phase gate passed with $warnings advisory warning(s). Consolidate them before a release ISO."
  printf 'Next useful commands:\n'
  printf '  seven improve security --apply --yes\n'
  printf '  seven improve compatibility --apply --yes\n'
  printf '  seven improve deployment --apply --yes\n'
  printf '  seven readiness --record\n'
else
  log_success "Phase gate passed cleanly."
fi
