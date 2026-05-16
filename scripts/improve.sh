#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

APPLY=0
YES=0
CRITERION="${1:-all}"

usage() {
  cat <<'EOF'
SevenOS Improve

Usage:
  seven improve [criterion] [--apply] [--yes]
  ./scripts/improve.sh [criterion] [--apply] [--yes]

Criteria:
  all
  daily
  performance
  ux
  compatibility
  ease
  security
  customization
  target
  ecosystem
  deployment

Default is a safe plan. Use --apply to execute the recommended install targets.
Use --yes with --apply to run supported package installs non-interactively.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done

if [[ "$CRITERION" == "--apply" ]]; then
  CRITERION="all"
fi
if [[ "$CRITERION" == "--yes" ]]; then
  CRITERION="all"
fi

if [[ "$YES" -eq 1 ]]; then
  export SEVENOS_YES=1
fi

run_step() {
  local label="$1"
  shift

  printf '  - %s\n' "$label"
  if [[ "$APPLY" -eq 1 && ! is_dry_run ]]; then
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

improve_performance() {
  section "Performance"
  run_step "Install lightweight SevenOS desktop base" "$ROOT_DIR/install.sh" base
  run_step "Apply desktop configuration and wallpaper" "$ROOT_DIR/install.sh" theme
}

improve_ux() {
  section "UX/UI"
  run_step "Install SevenOS CLI commands" "$ROOT_DIR/install.sh" cli
  run_step "Install Seven Hub control center" "$ROOT_DIR/install.sh" hub
  run_step "Apply theme, Waybar, Rofi, Mako and power controls" "$ROOT_DIR/install.sh" theme
}

improve_compatibility() {
  section "Software Compatibility"
  run_step "Install Windows compatibility profile" "$ROOT_DIR/install.sh" windows
  run_step "Install Flatpak defaults for accessible app compatibility" "$ROOT_DIR/scripts/flatpak.sh" install-defaults
  run_step "Check KVM/libvirt readiness" "$ROOT_DIR/install.sh" vm-check
  run_step "Start libvirt default network" "$ROOT_DIR/install.sh" vm-network
  run_step "Show guided Windows Mode assistant" "$ROOT_DIR/bin/seven-windows-assistant" plan
}

improve_ease() {
  section "Ease Of Use"
  run_step "Install SevenOS commands" "$ROOT_DIR/install.sh" cli
  run_step "Install Seven Hub" "$ROOT_DIR/install.sh" hub
  run_step "Show onboarding after setup" "$ROOT_DIR/bin/seven-welcome"
}

improve_security() {
  section "Security"
  run_step "Install firewall, secrets and hardening tools" "$ROOT_DIR/install.sh" security
  run_step "Install Shield core audit tools" "$ROOT_DIR/install.sh" cybersecurity core
  run_step "Apply base hardening" "$ROOT_DIR/install.sh" security
  run_step "Install Shield sandbox helpers" "$ROOT_DIR/install.sh" cybersecurity sandbox
  run_step "Bootstrap native Shield workspace" "$ROOT_DIR/security/shield-workspace.sh" bootstrap
  run_step "Audit Shield readiness" "$ROOT_DIR/install.sh" cyber-audit
  run_step "Show CyberSpace runtime status" "$ROOT_DIR/security/cyberspace.sh" mode
}

improve_customization() {
  section "Customization"
  run_step "Apply SevenOS African first desktop identity" "$ROOT_DIR/install.sh" theme
  run_step "Apply SevenOS system branding" "$ROOT_DIR/install.sh" branding
}

improve_target() {
  section "Target Use"
  run_step "Bootstrap all SevenOS profile workspaces" "$ROOT_DIR/profiles/profile-manager.sh" bootstrap all
  run_step "Install Forge development workspace" "$ROOT_DIR/install.sh" dev
  run_step "Install Shield cybersecurity workspace" "$ROOT_DIR/install.sh" cybersecurity
  run_step "Install Studio creative workspace" "$ROOT_DIR/install.sh" creation
  run_step "Install Windows bridge workspace" "$ROOT_DIR/install.sh" windows
  run_step "Install Horizon deployment workspace" "$ROOT_DIR/install.sh" server
}

improve_ecosystem() {
  section "Ecosystem"
  run_step "Install SevenOS installer automation foundation" "$ROOT_DIR/install.sh" installer-stack
  run_step "Install ISO build tooling" "$ROOT_DIR/install.sh" iso-tools
  run_step "Create installer plan" "$ROOT_DIR/install.sh" installer-plan
  run_step "Validate installer plan" "$ROOT_DIR/install.sh" installer-check
}

improve_deployment() {
  section "Deployment"
  run_step "Install SevenOS server and deployment packages" "$ROOT_DIR/install.sh" server
  run_step "Install Seven Server user service" "$ROOT_DIR/server/seven-server.sh" install-user-service
  run_step "Start Seven Server local API" "$ROOT_DIR/server/seven-server.sh" start
  run_step "Check local server readiness" "$ROOT_DIR/server/seven-server.sh" doctor
  run_step "Preview deployment planner on this repository" "$ROOT_DIR/server/seven-deploy.sh" plan "$ROOT_DIR"
}

improve_daily() {
  section "Daily Driver Consolidation"
  run_step "Back up protected SevenOS user state" "$ROOT_DIR/install.sh" migrate-backup
  run_step "Install SevenOS CLI commands" "$ROOT_DIR/install.sh" cli
  run_step "Apply desktop session, theme and persistent wallpaper runtime" "$ROOT_DIR/install.sh" theme
  run_step "Install Seven Hub control center" "$ROOT_DIR/install.sh" hub
  improve_security
  improve_target
  improve_compatibility
  improve_deployment
  improve_ecosystem
  run_step "Install Seven Core user services" "$ROOT_DIR/scripts/core.sh" install-service
  run_step "Install Seven Context observer" "$ROOT_DIR/scripts/core.sh" install-observer
  run_step "Start Seven Core user service" "$ROOT_DIR/scripts/core.sh" start
  run_step "Start Seven Context observer" "$ROOT_DIR/scripts/core.sh" start-observer
  run_step "Refresh persistent wallpaper runtime" "$ROOT_DIR/bin/seven-wallpaper" refresh
  run_step "Bootstrap all SevenOS profile workspaces after package installation" "$ROOT_DIR/profiles/profile-manager.sh" bootstrap all
  run_step "Run post-install blocker check" "$ROOT_DIR/install.sh" post-install
  run_step "Run daily driver gate" "$ROOT_DIR/scripts/daily-driver.sh" status
}

printf 'SevenOS Improve Plan\n'
printf '====================\n'
if [[ "$APPLY" -eq 1 ]]; then
  log_warn "Apply mode enabled. System-changing commands may run."
  if [[ "$YES" -eq 1 ]]; then
    log_warn "Non-interactive package install mode enabled."
  fi
  if ! is_dry_run && ! sudo -n true 2>/dev/null; then
    log_error "Apply mode needs an active sudo session."
    log_info "Run 'sudo -v' in a terminal first, then retry the same command."
    exit 1
  fi
else
  printf 'Dry plan only. Add --apply to execute.\n'
fi

case "$CRITERION" in
  all)
    improve_performance
    improve_ux
    improve_compatibility
    improve_ease
    improve_security
    improve_customization
    improve_target
    improve_ecosystem
    improve_deployment
    ;;
  daily|daily-driver) improve_daily ;;
  performance) improve_performance ;;
  ux) improve_ux ;;
  compatibility) improve_compatibility ;;
  ease) improve_ease ;;
  security) improve_security ;;
  customization) improve_customization ;;
  target) improve_target ;;
  ecosystem) improve_ecosystem ;;
  deployment|server|deploy) improve_deployment ;;
  *)
    log_error "Unknown criterion: $CRITERION"
    usage
    exit 1
    ;;
esac

printf '\nNext check:\n'
printf '  seven readiness\n'
