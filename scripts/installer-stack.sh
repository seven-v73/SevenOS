#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS installer stack

Usage:
  ./scripts/installer-stack.sh [status|install|doctor|plan]

Actions:
  status   Show installer tooling state
  install  Install official installer foundation packages
  doctor   Validate SevenOS installer foundation
  plan     Explain Calamares + Archinstall next steps
EOF
}

state() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 && printf OK || printf MISS
}

status() {
  printf 'SevenOS Installer Stack\n'
  printf '=======================\n'
  printf 'archinstall: %s\n' "$(state archinstall)"
  printf 'calamares:   %s\n' "$(state calamares)"
  printf 'planner:     %s\n' "$([[ -x "$ROOT_DIR/installer/plan.sh" ]] && printf OK || printf MISS)"
  printf 'profile:     %s\n' "$([[ -d "$ROOT_DIR/installer/calamares" ]] && printf OK || printf MISS)"
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
case "$action" in
  status) status ;;
  install) install_stack ;;
  doctor) doctor ;;
  plan) plan ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown installer stack action: $action"; usage; exit 1 ;;
esac
