#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS installer stack

Usage:
  ./scripts/installer-stack.sh [status|install|doctor|plan] [--json]

Actions:
  status   Show installer tooling state
  status --json
           Show machine-readable installer tooling state
  install  Install official installer foundation packages
  doctor   Validate SevenOS installer foundation
  plan     Explain Calamares + Archinstall next steps
  plan --json
           Show prioritized installer/ISO productization actions
EOF
}

JSON_OUTPUT=0

state() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 && printf OK || printf MISS
}

file_state() {
  local path="$1"
  [[ -s "$ROOT_DIR/$path" ]] && printf OK || printf MISS
}

dir_state() {
  local path="$1"
  [[ -d "$ROOT_DIR/$path" ]] && printf OK || printf MISS
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

status() {
  local archinstall_state calamares_state planner_state profile_state archiso_state build_state packages_state
  archinstall_state="$(state archinstall)"
  calamares_state="$(state calamares)"
  planner_state="$([[ -x "$ROOT_DIR/installer/plan.sh" ]] && printf OK || printf MISS)"
  profile_state="$(dir_state installer/calamares)"
  archiso_state="$(dir_state archiso/profile)"
  build_state="$([[ -x "$ROOT_DIR/scripts/build-iso.sh" ]] && printf OK || printf MISS)"
  packages_state="$(file_state archiso/profile/packages.x86_64)"

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '{'
    printf '"schema":"sevenos.installer.v1",'
    printf '"tooling":['
    printf '{"key":"archinstall","state":%s},' "$(printf '%s' "$archinstall_state" | json_string)"
    printf '{"key":"calamares","state":%s}' "$(printf '%s' "$calamares_state" | json_string)"
    printf '],'
    printf '"foundation":['
    printf '{"key":"planner","state":%s},' "$(printf '%s' "$planner_state" | json_string)"
    printf '{"key":"calamares-profile","state":%s},' "$(printf '%s' "$profile_state" | json_string)"
    printf '{"key":"archiso-profile","state":%s},' "$(printf '%s' "$archiso_state" | json_string)"
    printf '{"key":"iso-builder","state":%s},' "$(printf '%s' "$build_state" | json_string)"
    printf '{"key":"iso-packages","state":%s}' "$(printf '%s' "$packages_state" | json_string)"
    printf '],'
    printf '"ready":%s,' "$([[ "$archinstall_state" == OK && "$planner_state" == OK && "$archiso_state" == OK && "$build_state" == OK ]] && printf true || printf false)"
    printf '"mode":%s' "$(if [[ "$calamares_state" == OK ]]; then printf graphical | json_string; elif [[ "$archinstall_state" == OK ]]; then printf tui-ready | json_string; else printf foundation | json_string; fi)"
    printf '}\n'
    return 0
  fi

  printf 'SevenOS Installer Stack\n'
  printf '=======================\n'
  printf 'archinstall: %s\n' "$archinstall_state"
  printf 'calamares:   %s\n' "$calamares_state"
  printf 'planner:     %s\n' "$planner_state"
  printf 'profile:     %s\n' "$profile_state"
  printf 'archiso:     %s\n' "$archiso_state"
  printf 'iso builder: %s\n' "$build_state"
}

install_stack() {
  install_package_file "$ROOT_DIR/scripts/packages-installer.txt"
}

doctor() {
  local failures=0
  local path

  status
  printf '\nFoundation files:\n'
  for path in \
    "installer/README.md" \
    "installer/plan.sh" \
    "installer/validate-plan.sh" \
    "installer/generate-script.sh" \
    "installer/calamares/settings.conf" \
    "installer/calamares/modules/sevenos.conf" \
    "scripts/packages-installer.txt"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  if [[ "$failures" -gt 0 ]]; then
    log_error "Installer stack has $failures issue(s)."
    return 1
  fi

  log_success "Installer stack foundation is coherent."
}

plan() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    INSTALLER_STATUS="$(JSON_OUTPUT=1 status)" python - <<'PY'
import json
import os

status = json.loads(os.environ["INSTALLER_STATUS"])
states = {item["key"]: item["state"] for item in status.get("tooling", []) + status.get("foundation", [])}

metadata = {
    "archinstall": {
        "title": "Install Archinstall automation",
        "severity": "high",
        "impact": "packages",
        "phase": "automation",
        "command": "seven installer install",
        "reason": "Archinstall gives SevenOS an official automation backend before destructive disk flows are enabled.",
    },
    "calamares": {
        "title": "Package Calamares installer",
        "severity": "medium",
        "impact": "packages",
        "phase": "gui",
        "command": "seven installer plan",
        "reason": "Calamares is the graphical path for public ISO installation, but packaging remains a downstream step.",
    },
    "planner": {
        "title": "Restore installer planner",
        "severity": "critical",
        "impact": "changes",
        "phase": "planner",
        "command": "seven installer doctor",
        "reason": "SevenOS needs a non-destructive install plan before generating disk steps.",
    },
    "calamares-profile": {
        "title": "Restore Calamares profile",
        "severity": "high",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer doctor",
        "reason": "The graphical installer profile must travel with the ISO.",
    },
    "archiso-profile": {
        "title": "Restore Archiso profile",
        "severity": "critical",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "SevenOS cannot produce a live ISO without an Archiso profile.",
    },
    "iso-builder": {
        "title": "Restore ISO build script",
        "severity": "critical",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "The ISO builder is the bridge from repository to bootable SevenOS media.",
    },
    "iso-packages": {
        "title": "Restore ISO package list",
        "severity": "high",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "The live image needs an explicit package set for repeatable builds.",
    },
}

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions = []
for key, state in states.items():
    if state == "OK":
        continue
    item = metadata[key]
    actions.append({
        "key": key,
        "state": state,
        "title": item["title"],
        "severity": item["severity"],
        "impact": item["impact"],
        "phase": item["phase"],
        "reason": item["reason"],
        "command": item["command"],
    })

actions.append({
    "key": "dry-run-iso",
    "state": "READY",
    "title": "Validate ISO dry-run",
    "severity": "medium",
    "impact": "safe",
    "phase": "iso",
    "reason": "Before moving to a public ISO, SevenOS should prove the build path without touching the host.",
    "command": "./install.sh iso --dry-run",
})

actions.sort(key=lambda item: (rank.get(item["severity"], 9), item["phase"], item["key"]))

print(json.dumps({
    "schema": "sevenos.installer-plan.v1",
    "mode": status.get("mode", "foundation"),
    "ready": bool(status.get("ready")),
    "summary": {
        "total": len(actions),
        "critical": sum(1 for item in actions if item["severity"] == "critical"),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
    },
    "next": actions,
}, indent=2))
PY
    return 0
  fi

  cat <<'EOF'
SevenOS installer direction
===========================

Primary path:
  1. Use Calamares for the graphical installer experience.
  2. Use the existing SevenOS install plan as the source of truth.
  3. Use Archinstall only as a secondary/automation backend where useful.

Why:
  - Calamares unlocks non-technical users.
  - Archinstall gives an official Arch automation path.
  - SevenOS keeps destructive disk steps behind explicit confirmation.

Next engineering steps:
  - package or source Calamares for the live ISO
  - map installer/plan.sh fields to Calamares modules
  - add a SevenOS post-install module that runs /opt/SevenOS/install.sh base
  - keep a dry-run installer script for development safety
EOF
}

action="${1:-status}"
shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown installer option: $arg"; usage; exit 1 ;;
  esac
done
case "$action" in
  status) status ;;
  install) install_stack ;;
  doctor) doctor ;;
  plan) plan ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown installer stack action: $action"; usage; exit 1 ;;
esac
