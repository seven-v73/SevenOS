#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
APPLY=0
YES=0
LIMIT=12
PHASE_FILTER="all"

usage() {
  cat <<'EOF'
SevenOS B3 Consolidation

Usage:
  seven b3 status
  seven b3 plan [--json] [--phase trust|backend|profiles|shell|installer]
  seven b3 apply [--apply] [--yes] [--limit N] [--phase <phase>]
  seven b3 doctor
  ./scripts/b3.sh [status|plan|apply|doctor] [--json]

This command is the B2 -> B3 productization orchestrator. It turns the current
blockers into one ordered OS path:

  1. active trust and Shield
  2. local Seven Server backend
  3. concrete profiles
  4. Seven Shell AGS foundation
  5. installer readiness

It is safe by default. Use apply --apply to execute commands.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|plan|apply|doctor) ACTION="$1" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    --phase)
      shift
      PHASE_FILTER="${1:-}"
      case "$PHASE_FILTER" in
        all|trust|backend|profiles|shell|installer) ;;
        *) log_error "--phase expects one of: trust, backend, profiles, shell, installer"; exit 1 ;;
      esac
      ;;
    --limit)
      shift
      LIMIT="${1:-}"
      [[ "$LIMIT" =~ ^[0-9]+$ ]] || { log_error "--limit expects a number."; exit 1; }
      ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown B3 option: $1"; usage; exit 1 ;;
  esac
  shift
done

if [[ "$YES" -eq 1 ]]; then
  export SEVENOS_YES=1
fi

json_payload() {
  SEVENOS_ROOT="$ROOT_DIR" PHASE_FILTER="$PHASE_FILTER" python - <<'PY'
import json
import os
import subprocess

ROOT = os.environ["SEVENOS_ROOT"]
PHASE_FILTER = os.environ.get("PHASE_FILTER", "all")


def command_json(command, fallback):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback


def command_ok(command):
    return subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0


shield = command_json([os.path.join(ROOT, "security/shield-status.sh"), "--json"], {"percent": 0, "checks": []})
shield_plan = command_json([os.path.join(ROOT, "security/shield-status.sh"), "plan", "--json"], {"next": []})
server = command_json([os.path.join(ROOT, "server/seven-server.sh"), "status", "--json"], {"service": {"state": "MISS"}, "dependencies": []})
server_plan = command_json([os.path.join(ROOT, "server/seven-server.sh"), "plan", "--json"], {"next": []})
profile_plan = command_json([os.path.join(ROOT, "bin/seven"), "profile", "plan", "--json"], {"next": [], "summary": {}})
profile_status = command_json([os.path.join(ROOT, "bin/seven"), "profile", "status", "--json"], [])
shell = command_json([os.path.join(ROOT, "scripts/shell.sh"), "status", "--json"], {"state": "PLANNED", "dependencies": []})
shell_plan = command_json([os.path.join(ROOT, "scripts/shell.sh"), "plan", "--json"], {"next": []})
core_plan = command_json([os.path.join(ROOT, "scripts/core.sh"), "plan", "--json"], {"next": []})
installer = command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "status", "--json"], {"ready": False, "mode": "foundation"})
installer_plan = command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "plan", "--json"], {"next": []})

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions = []
seen = set()


def add(key, phase_name, severity, title, command, reason, impact="changes", satisfied=False):
    if satisfied:
        return
    identity = (phase_name, command, reason)
    if identity in seen:
        return
    seen.add(identity)
    actions.append({
        "key": key,
        "phase": phase_name,
        "severity": severity,
        "title": title,
        "command": command,
        "reason": reason,
        "impact": impact,
    })


for item in shield_plan.get("next", []):
    add(
        f"shield.{item.get('key', 'fix')}",
        "trust",
        item.get("severity", "high"),
        item.get("title", "Improve Shield"),
        item.get("command", "seven shield plan"),
        item.get("reason", "Improve Shield posture."),
        item.get("impact", "changes"),
    )

if shield.get("percent", 0) < 70:
    add("shield.bundle", "trust", "critical", "Install and activate Shield baseline", "seven improve security --apply --yes", "Install UFW, Firejail, Bubblewrap and base hardening helpers.", "packages")
    add("shield.enable", "trust", "critical", "Enable firewall posture", "seven shield enable", "Apply default deny incoming, allow outgoing, and preserve SSH when active.", "changes")

for item in server_plan.get("next", []):
    add(
        f"server.{item.get('key', 'fix')}",
        "backend",
        item.get("severity", "high"),
        item.get("title", "Prepare Seven Server"),
        item.get("command", "seven server plan"),
        item.get("reason", "Prepare local SevenOS API backend."),
        item.get("impact", "changes"),
    )

service_state = (server.get("service") or {}).get("state", "MISS")
server_dependencies = server.get("dependencies") or []
server_dependency_total = len(server_dependencies)
server_dependency_ok = sum(1 for item in server_dependencies if item.get("state") == "OK")
runtime_ready = bool(server.get("runtime_ready")) or service_state == "RUN"
if runtime_ready:
    backend_score = 55 + round((server_dependency_ok / server_dependency_total) * 45) if server_dependency_total else 55
elif service_state == "READY":
    backend_score = 35 + round((server_dependency_ok / server_dependency_total) * 25) if server_dependency_total else 35
else:
    backend_score = round((server_dependency_ok / server_dependency_total) * 25) if server_dependency_total else 0
if not runtime_ready and service_state != "READY":
    add("server.packages", "backend", "high", "Install deployment/backend layer", "seven improve deployment --apply --yes", "Install Podman, Caddy, Go and deployment tools for Horizon.", "packages")
    add("server.install-service", "backend", "high", "Install Seven Server user service", "seven server install-user-service", "Make the local API durable instead of ad-hoc script calls.", "changes")
if not runtime_ready:
    add("server.start", "backend", "high", "Start Seven Server runtime", "seven server start", "Expose SevenOS state to Hub and future shell surfaces.", "changes")

profile_priority = {"shield": "critical", "studio": "high", "windows": "high", "horizon": "high", "baobab": "medium", "forge": "medium"}
profile_bootstrap_total = len(profile_status) if isinstance(profile_status, list) else 0
profile_bootstrap_ok = sum(1 for item in profile_status if item.get("bootstrap_state") == "OK") if isinstance(profile_status, list) else 0
if profile_bootstrap_total and profile_bootstrap_ok < profile_bootstrap_total:
    add(
        "profile.bootstrap",
        "profiles",
        "medium",
        "Bootstrap SevenOS profile workspaces",
        "seven profile bootstrap all",
        "Create manifests, checklists and launchers so profiles become visible workspaces before full package installs.",
        "safe",
    )
for profile in profile_plan.get("next", []):
    key = profile.get("key", "profile")
    severity = profile_priority.get(key, profile.get("priority", "medium"))
    if profile.get("bootstrap_state") != "OK":
        add(
            f"profile.{key}.bootstrap",
            "profiles",
            "medium",
            f"Bootstrap {profile.get('title', key.title())}",
            profile.get("bootstrap_command", f"seven profile bootstrap {key}"),
            f"{profile.get('title', key.title())} workspace contract is {profile.get('bootstrap_state', 'MISS')}.",
            "safe",
        )
    add(
        f"profile.{key}",
        "profiles",
        severity,
        f"Complete {profile.get('title', key.title())}",
        profile.get("command", f"seven profile install {key}"),
        profile.get("reason", f"{key} profile is incomplete."),
        "packages",
    )

for item in shell_plan.get("next", []):
    add(
        f"shell.{item.get('key', 'fix')}",
        "shell",
        item.get("severity", "medium"),
        item.get("title", "Prepare Seven Shell"),
        item.get("command", "./install.sh shell-ags"),
        item.get("reason", "Prepare AGS/TypeScript shell foundation."),
        item.get("impact", "packages"),
    )

if shell.get("state") == "PLANNED":
    add("shell.foundation", "shell", "high", "Install Seven Shell AGS foundation", "./install.sh shell-ags --yes", "Prepare GJS, TypeScript, GTK4 and libadwaita before replacing Rofi surfaces.", "packages")
    add("shell.doctor", "shell", "medium", "Validate shell foundation", "seven shell doctor", "Confirm the AGS foundation remains coherent with fallback surfaces.", "safe")

for item in core_plan.get("next", []):
    command = item.get("command", "")
    if command in ("seven core install-service", "seven core install-observer", "seven core start", "seven core start-observer"):
        add(
            f"core.{item.get('key', 'runtime')}",
            "backend",
            item.get("severity", "medium"),
            item.get("title", "Activate Seven Core runtime"),
            command,
            item.get("reason", "Move Seven Core from contracts toward supervised runtime services."),
            item.get("impact", "changes"),
        )

for item in installer_plan.get("next", []):
    add(
        f"installer.{item.get('key', 'fix')}",
        "installer",
        item.get("severity", "medium"),
        item.get("title", "Prepare installer"),
        item.get("command", "seven installer plan"),
        item.get("reason", "Prepare reproducible installation path."),
        item.get("impact", "safe"),
    )

if not installer.get("ready"):
    add("installer.foundation", "installer", "medium", "Install installer foundation", "seven installer install", "Prepare Archinstall and Calamares foundation after trust/backend are stable.", "packages")

phase_order = {"trust": 0, "backend": 1, "profiles": 2, "shell": 3, "installer": 4}

merged = {}
for item in actions:
    command = item["command"]
    previous = merged.get(command)
    if previous is None:
        merged[command] = item
        continue
    previous_score = (rank.get(previous["severity"], 9), phase_order.get(previous["phase"], 9))
    item_score = (rank.get(item["severity"], 9), phase_order.get(item["phase"], 9))
    if item_score < previous_score:
        if previous.get("reason") and previous["reason"] not in item.get("reason", ""):
            item["reason"] = f"{item['reason']} Also: {previous['reason']}"
        merged[command] = item
    elif item.get("reason") and item["reason"] not in previous.get("reason", ""):
        previous["reason"] = f"{previous['reason']} Also: {item['reason']}"

actions = list(merged.values())
preferred_commands = {
    "seven improve security --apply": "seven improve security --apply --yes",
    "seven improve deployment --apply": "seven improve deployment --apply --yes",
    "./install.sh shell-ags": "./install.sh shell-ags --yes",
    "seven installer plan": "seven installer install",
    "seven core install-observer": "seven core install-service",
    "seven profile bootstrap baobab": "seven profile bootstrap all",
    "seven profile bootstrap forge": "seven profile bootstrap all",
    "seven profile bootstrap shield": "seven profile bootstrap all",
    "seven profile bootstrap studio": "seven profile bootstrap all",
    "seven profile bootstrap windows": "seven profile bootstrap all",
    "seven profile bootstrap horizon": "seven profile bootstrap all",
}
available_commands = {item["command"] for item in actions}
actions = [
    item for item in actions
    if preferred_commands.get(item["command"]) not in available_commands
]
actions.sort(key=lambda item: (rank.get(item["severity"], 9), phase_order.get(item["phase"], 9), item["key"]))
if PHASE_FILTER != "all":
    actions = [item for item in actions if item.get("phase") == PHASE_FILTER]

sudo_ready = command_ok(["sudo", "-n", "true"])
impact_counts = {}
phase_counts = {}
for item in actions:
    impact_counts[item.get("impact", "safe")] = impact_counts.get(item.get("impact", "safe"), 0) + 1
    phase_counts[item.get("phase", "unknown")] = phase_counts.get(item.get("phase", "unknown"), 0) + 1

blocked_by = []
if any(item.get("impact") in ("packages", "changes") for item in actions) and not sudo_ready:
    blocked_by.append({
        "key": "sudo",
        "state": "MISS",
        "detail": "System-changing B3 actions need an active sudo session.",
        "command": "sudo -v",
    })
if any(item.get("impact") == "manual" for item in actions):
    blocked_by.append({
        "key": "manual",
        "state": "WAITING",
        "detail": "One or more B3 actions need an explicit human workflow decision.",
        "command": "seven stack roadmap",
    })

phase_scores = {
    "trust": shield.get("percent", 0),
    "backend": min(100, backend_score),
    "profiles": max(0, 100 - min(100, (profile_plan.get("summary", {}) or {}).get("total", 0) * 15)) if not profile_bootstrap_total else round(
        max(0, 100 - min(100, (profile_plan.get("summary", {}) or {}).get("total", 0) * 15)) * 0.7
        + ((profile_bootstrap_ok / profile_bootstrap_total) * 100) * 0.3
    ),
    "shell": 100 if shell.get("state") == "READY" else 65 if shell.get("state") == "FOUNDATION" else 35,
    "installer": 100 if installer.get("ready") else 35,
}

target_scores = {
    "trust": 70,
    "backend": 80,
    "profiles": 70,
    "shell": 65,
    "installer": 50,
}
phase_state = {
    key: "pass" if phase_scores.get(key, 0) >= target else "block"
    for key, target in target_scores.items()
}
critical_or_high = sum(1 for item in actions if item.get("severity") in ("critical", "high"))

overall = round(
    phase_scores["trust"] * 0.3
    + phase_scores["backend"] * 0.25
    + phase_scores["profiles"] * 0.18
    + phase_scores["shell"] * 0.12
    + phase_scores["installer"] * 0.15
)

print(json.dumps({
    "schema": "sevenos.b3.v1",
    "phase": "B2",
    "target": "B3",
    "filter": PHASE_FILTER,
    "state": "satisfactory" if critical_or_high == 0 and all(state == "pass" for state in phase_state.values()) else "blocked",
    "overall": overall,
    "scores": {
        **phase_scores,
    },
    "targets": target_scores,
    "phase_state": phase_state,
    "phase_gate": {
        "decision": "pass" if critical_or_high == 0 and all(state == "pass" for state in phase_state.values()) else "blocked",
        "summary": {
            "open_actions": len(actions),
            "critical_or_high": critical_or_high,
            "targets_met": all(state == "pass" for state in phase_state.values()),
        },
    },
    "preflight": {
        "sudo": "READY" if sudo_ready else "MISS",
        "can_apply_system_changes": sudo_ready,
        "dry_run_default": True,
    },
    "summary": {
        "total": len(actions),
        "critical": sum(1 for item in actions if item["severity"] == "critical"),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
        "by_impact": impact_counts,
        "by_phase": phase_counts,
    },
    "blocked_by": blocked_by,
    "phase_order": ["trust", "backend", "profiles", "shell", "installer"],
    "phase_commands": {
        "trust": "seven b3 apply --phase trust --limit 4",
        "backend": "seven b3 apply --phase backend --limit 4",
        "profiles": "seven b3 apply --phase profiles --limit 4",
        "shell": "seven b3 apply --phase shell --limit 4",
        "installer": "seven b3 apply --phase installer --limit 4",
    },
    "actions": actions,
}, indent=2))
PY
}

print_status() {
  B3_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["B3_PAYLOAD"])
summary = data.get("summary", {})
scores = data.get("scores", {})
targets = data.get("targets", {})
phase_state = data.get("phase_state", {})
preflight = data.get("preflight", {})

print("SevenOS B3 Consolidation")
print("========================")
print(f"State:   {data.get('state', 'blocked')}")
print(f"Filter:  {data.get('filter', 'all')}")
print(f"Overall: {data.get('overall', 0)}%")
print(f"Sudo:    {preflight.get('sudo', 'unknown')}")
print(
    f"Open:    {summary.get('total', 0)} "
    f"({summary.get('critical', 0)} critical, {summary.get('high', 0)} high, {summary.get('medium', 0)} medium)"
)
print()
print(f"{'Phase':<10} {'Score':<7} {'Target':<7} {'Gate'}")
print(f"{'-----':<10} {'-----':<7} {'------':<7} {'----'}")
for key in ("trust", "backend", "profiles", "shell", "installer"):
    print(f"{key:<10} {scores.get(key, 0)}%{'':<4} {targets.get(key, 0)}%{'':<4} {phase_state.get(key, 'block')}")
print()
print("Next:")
for item in data.get("actions", [])[:5]:
    print(f"  {item.get('severity', ''):<8} {item.get('command', '')}")
    print(f"           {item.get('reason', '')}")
print()
print("Phase commands:")
for phase, command in (data.get("phase_commands") or {}).items():
    print(f"  {phase:<9} {command}")
if data.get("blocked_by"):
    print()
    print("Blocked by:")
    for item in data.get("blocked_by", []):
        print(f"  {item.get('key'):<8} {item.get('command')} - {item.get('detail')}")
PY
}

print_plan() {
  B3_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["B3_PAYLOAD"])
summary = data.get("summary", {})

print("SevenOS B3 Plan")
print("===============")
print(f"Filter: {data.get('filter', 'all')}")
print(f"Actions: {summary.get('total', 0)}")
print(f"Sudo: {data.get('preflight', {}).get('sudo', 'unknown')}")
print(f"Gate: {data.get('phase_gate', {}).get('decision', 'blocked')}")
print()
print(f"{'Phase':<10} {'Score':<7} {'Target':<7} {'Gate'}")
print(f"{'-----':<10} {'-----':<7} {'------':<7} {'----'}")
for phase in data.get("phase_order", []):
    print(
        f"{phase:<10} {data.get('scores', {}).get(phase, 0)}%{'':<4} "
        f"{data.get('targets', {}).get(phase, 0)}%{'':<4} "
        f"{data.get('phase_state', {}).get(phase, 'block')}"
    )
print()
print(f"{'Severity':<9} {'Phase':<10} {'Command'}")
print(f"{'--------':<9} {'-----':<10} {'-------'}")
for item in data.get("actions", []):
    print(f"{item.get('severity',''):<9} {item.get('phase',''):<10} {item.get('command','')}")
    print(f"{'':<9} {'':<10} {item.get('reason','')}")
PY
}

apply_plan() {
  local payload command_count=0 sudo_ready=0 dry_run=0
  payload="$(json_payload)"
  is_dry_run && dry_run=1

  printf 'SevenOS B3 Apply\n'
  printf '================\n'
  if [[ "$APPLY" -eq 1 ]]; then
    log_warn "Apply mode enabled. SevenOS will execute B3 consolidation actions."
    [[ "$YES" -eq 1 ]] && log_warn "Non-interactive mode enabled where supported."
  else
    printf 'Preview only. Add --apply to execute.\n'
  fi
  printf '\n'

  if sudo -n true 2>/dev/null; then
    sudo_ready=1
  fi

  if [[ "$APPLY" -eq 1 && "$dry_run" -eq 0 && "$sudo_ready" -eq 0 ]]; then
    log_warn "No active sudo session. System-changing B3 actions will be skipped."
    log_info "Run 'sudo -v' first to apply package/security/profile actions."
  fi

  "$ROOT_DIR/scripts/events.sh" log \
    --source b3 \
    --type "$([[ "$APPLY" -eq 1 ]] && printf apply || printf preview)" \
    --state "$([[ "$APPLY" -eq 1 ]] && printf WARN || printf OK)" \
    --message "B3 consolidation $([[ "$APPLY" -eq 1 ]] && printf apply || printf preview) requested with limit $LIMIT" \
    --command "seven b3 apply --limit $LIMIT$([[ "$APPLY" -eq 1 ]] && printf ' --apply')$([[ "$YES" -eq 1 ]] && printf ' --yes')" >/dev/null

  while IFS=$'\t' read -r severity phase impact command reason; do
    [[ -n "${command:-}" ]] || continue
    command_count=$((command_count + 1))
    printf '%-9s %-10s %-9s %s\n' "$severity" "$phase" "$impact" "$command"
    printf '%-9s %-10s %-9s %s\n' "" "" "" "$reason"
    if [[ "$impact" == "manual" ]]; then
      printf '          MANUAL > B3 > %s > %s\n\n' "$phase" "$command"
      continue
    fi
    if [[ "$APPLY" -eq 1 && "$dry_run" -eq 0 && "$sudo_ready" -eq 0 && "$impact" =~ ^(packages|changes)$ ]]; then
      printf '          BLOCKED > B3 > %s > sudo required > %s\n\n' "$phase" "$command"
      continue
    fi
    if [[ "$APPLY" -eq 1 && "$dry_run" -eq 0 ]]; then
      bash -lc "cd '$ROOT_DIR' && $command"
    else
      printf '          DRY-RUN > B3 > %s > %s\n' "$phase" "$command"
    fi
    printf '\n'
  done < <(
    B3_PAYLOAD="$payload" LIMIT="$LIMIT" python - <<'PY'
import json
import os

data = json.loads(os.environ["B3_PAYLOAD"])
limit = int(os.environ.get("LIMIT", "12"))
for item in data.get("actions", [])[:limit]:
    print("\t".join([
        item.get("severity", ""),
        item.get("phase", ""),
        item.get("impact", ""),
        item.get("command", ""),
        item.get("reason", ""),
    ]))
PY
  )

  if [[ "$command_count" -eq 0 ]]; then
    log_success "No B3 consolidation actions are currently open."
  fi
}

doctor() {
  local failures=0
  local payload
  payload="$(json_payload)"

  printf 'SevenOS B3 Doctor\n'
  printf '=================\n'
  for command_name in seven python pacman systemctl; do
    if command -v "$command_name" >/dev/null 2>&1 || [[ "$command_name" == seven && -x "$ROOT_DIR/bin/seven" ]]; then
      printf '[OK] %s\n' "$command_name"
    else
      printf '[MISS] %s\n' "$command_name"
      failures=$((failures + 1))
    fi
  done

  B3_PAYLOAD="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["B3_PAYLOAD"])
print(f"[INFO] filter={data.get('filter', 'all')}")
print(f"[INFO] overall={data.get('overall', 0)}%")
print(f"[INFO] gate={data.get('phase_gate', {}).get('decision', 'blocked')}")
print(f"[INFO] sudo={data.get('preflight', {}).get('sudo', 'unknown')}")
print(f"[INFO] actions={data.get('summary', {}).get('total', 0)}")
for phase in data.get("phase_order", []):
    count = sum(1 for item in data.get("actions", []) if item.get("phase") == phase)
    score = data.get("scores", {}).get(phase, 0)
    target = data.get("targets", {}).get(phase, 0)
    gate = data.get("phase_state", {}).get(phase, "block")
    print(f"[INFO] {phase} score={score}% target={target}% gate={gate} open={count}")
PY

  "$ROOT_DIR/scripts/events.sh" log \
    --source b3 \
    --type doctor \
    --state "$([[ "$failures" -eq 0 ]] && printf OK || printf MISS)" \
    --message "B3 doctor completed with $failures missing foundation command(s)" \
    --command "seven b3 doctor" >/dev/null

  if [[ "$failures" -gt 0 ]]; then
    log_error "B3 foundation has $failures missing command(s)."
    return 1
  fi
  log_success "B3 orchestration foundation is coherent."
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  json_payload
  exit 0
fi

case "$ACTION" in
  status) print_status ;;
  plan) print_plan ;;
  apply) apply_plan ;;
  doctor) doctor ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown B3 action: $ACTION"; usage; exit 1 ;;
esac
