#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

AREA="${1:-all}"
APPLY=0
YES=0

usage() {
  cat <<'EOF'
SevenOS Repair

Usage:
  seven repair [area] [--apply] [--yes]
  seven doctor fix [area] [--apply] [--yes]
  ./scripts/repair.sh [area] [--apply] [--yes]

Areas:
  all
  system
  ux
  security
  compatibility
  deployment
  target

Default mode prints a safe repair plan. Use --apply to execute the plan.
Use --yes with --apply for supported non-interactive package installs.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done

if [[ "$AREA" == "--apply" || "$AREA" == "--yes" ]]; then
  AREA="all"
fi

if [[ "$YES" -eq 1 ]]; then
  export SEVENOS_YES=1
fi

run_repair() {
  local label="$1"
  shift

  printf '  - %s\n' "$label"
  if [[ "$APPLY" -eq 1 ]] && ! is_dry_run; then
    "$@"
  else
    printf '    command:'
    printf ' %q' "$@"
    printf '\n'
  fi
}

section() {
  printf '\n== %s ==\n' "$1"
}

repair_ux() {
  section "UX Repair"
  run_repair "Install SevenOS CLI tools" "$ROOT_DIR/install.sh" cli
  run_repair "Apply SevenOS theme, Kitty, shell country signals and desktop configs" "$ROOT_DIR/install.sh" theme
  run_repair "Apply SevenOS branding" "$ROOT_DIR/install.sh" branding
  run_repair "Install Seven Hub" "$ROOT_DIR/install.sh" hub
}

repair_system() {
  section "System Repair"
  run_repair "Repair stale UFW marker and host-level failed service state" "$ROOT_DIR/scripts/system-repair.sh" apply
}

repair_security() {
  section "Security Repair"
  run_repair "Install sandbox helpers and Shield tools" "$ROOT_DIR/install.sh" cybersecurity sandbox
  run_repair "Apply firewall and base hardening" "$ROOT_DIR/install.sh" security
  run_repair "Run cyber audit" "$ROOT_DIR/install.sh" cyber-audit
}

repair_compatibility() {
  section "Compatibility Repair"
  run_repair "Install Windows compatibility layer" "$ROOT_DIR/install.sh" windows
  run_repair "Check VM readiness" "$ROOT_DIR/install.sh" vm-check
  run_repair "Start libvirt default network" "$ROOT_DIR/install.sh" vm-network
  run_repair "Show Windows Mode status" "$ROOT_DIR/install.sh" windows-mode status
}

repair_deployment() {
  section "Deployment Repair"
  run_repair "Install Forge DevOps server and deployment layer" "$ROOT_DIR/install.sh" server
  run_repair "Install seven-server user service" "$ROOT_DIR/server/seven-server.sh" install-user-service
  run_repair "Start seven-server user service" "$ROOT_DIR/server/seven-server.sh" start
  run_repair "Validate ecosystem foundation" "$ROOT_DIR/scripts/ecosystem.sh" doctor
}

repair_target() {
  section "Target Workspace Repair"
  run_repair "Complete Forge development workspace" "$ROOT_DIR/install.sh" dev
  run_repair "Complete Shield cybersecurity workspace" "$ROOT_DIR/install.sh" cybersecurity
  run_repair "Complete Studio creative workspace" "$ROOT_DIR/install.sh" creation
}

printf 'SevenOS Repair Plan\n'
printf '===================\n'

if [[ "$APPLY" -eq 1 ]]; then
  log_warn "Apply mode enabled. Repair commands may change this system."
  if [[ "$YES" -eq 1 ]]; then
    log_warn "Non-interactive package install mode enabled."
  fi
  if ! is_dry_run && ! sudo -n true 2>/dev/null; then
    log_error "Repair apply mode needs an active sudo session."
    log_info "Run 'sudo -v' in a terminal first, then retry."
    exit 1
  fi
else
  printf 'Dry plan only. Add --apply to execute.\n'
fi

case "$AREA" in
  all)
    repair_system
    repair_ux
    repair_security
    repair_compatibility
    repair_deployment
    repair_target
    ;;
  system) repair_system ;;
  ux) repair_ux ;;
  security) repair_security ;;
  compatibility|windows) repair_compatibility ;;
  deployment|server) repair_deployment ;;
  target|profiles) repair_target ;;
  *)
    log_error "Unknown repair area: $AREA"
    usage
    exit 1
    ;;
esac

printf '\nNext checks:\n'
printf '  seven doctor\n'
printf '  seven post-install\n'
printf '  seven readiness\n'
printf '  seven phase-gate\n'
