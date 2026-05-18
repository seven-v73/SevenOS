#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS installer

Usage:
  ./install.sh <target> [--dry-run] [--yes]

Targets:
  base             Install base SevenOS desktop layer
  dev              Install development profile
  cybersecurity    Install cybersecurity profile, optionally by category
  creation         Install creation profile
  windows          Install Windows compatibility layer
  server           Install SevenOS server and deployment layer
  installer-stack  Install graphical installer foundation packages
  hub-gui-stack    Install Seven Hub Tauri GUI foundation packages
  shell-ags        Install Seven Shell AGS/TypeScript foundation packages
  shell-preview    Preview Seven Shell AGS migration plan
  flatpak          Manage Flatpak/Flathub bridge
  security         Apply base security hardening
  cyber-audit      Show cybersecurity profile readiness
  cyber-lab        Open an isolated cybersecurity lab shell
  blackarch-setup  Add the optional BlackArch repository bridge
  blackarch-category <name>
                   Install one BlackArch category, for example webapp
  blackarch-tool <pkg>
                   Install one BlackArch package
  doctor           Check host readiness
  post-install     Check common post-install blockers
  status           Show SevenOS installation status
  branding         Apply SevenOS system branding
  cli              Install SevenOS CLI tools
  theme [dark|light]
                   Apply SevenOS visual theme
  hub              Install Seven Hub launcher
  iso-tools        Install ISO build tooling
  iso              Build SevenOS live ISO
  vm-check         Check KVM/libvirt readiness
  vm-network       Start and autostart libvirt default network
  vm-windows       Create a Windows VM with virt-install
  windows-mode     Guided Windows compatibility and VM workflow
  installer-plan   Create a non-destructive install plan
  installer-check  Validate an install plan
  installer-script Generate non-destructive install step script
  migrate-plan     Show SevenOS protected user-state migration plan
  migrate-backup   Back up protected SevenOS user state before upgrading
  daily-driver     Consolidate SevenOS for primary PC testing
  all              Install base layer and all profiles

Options:
  --dry-run         Show actions without installing packages or copying configs
  --yes             Run package installs non-interactively where supported
  -h, --help        Show this help
EOF
}

TARGET="${1:-}"
DRY_RUN="${SEVENOS_DRY_RUN:-0}"
YES="${SEVENOS_YES:-0}"
TARGET_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes) YES=1 ;;
    -h|--help) usage; exit 0 ;;
  esac
done

if [[ "$#" -gt 1 ]]; then
  for arg in "${@:2}"; do
    case "$arg" in
      --dry-run|--yes) ;;
      *) TARGET_ARGS+=("$arg") ;;
    esac
  done
fi

if [[ -z "$TARGET" || "$TARGET" == "--dry-run" ]]; then
  usage
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -eq 0 && "${SEVENOS_ALLOW_ROOT:-0}" != "1" ]]; then
  log_error "Do not run SevenOS installer with sudo/root."
  log_info "Run it as your normal user. The scripts ask sudo only when needed."
  log_info "Correct: ./install.sh base --yes"
  log_info "Wrong:   sudo ./install.sh base --yes"
  exit 1
fi

export SEVENOS_ROOT="$ROOT_DIR"
export SEVENOS_DRY_RUN="$DRY_RUN"
export SEVENOS_YES="$YES"

if [[ "$TARGET" != "doctor" && "$TARGET" != "status" && "$TARGET" != "migrate-plan" && "$TARGET" != "migrate-backup" ]]; then
  require_arch
  require_command sudo
  require_command pacman
fi

case "$TARGET" in
  base)
    "$ROOT_DIR/bootstrap.sh"
    ;;
  dev)
    "$ROOT_DIR/profiles/dev.sh"
    ;;
  cybersecurity)
    "$ROOT_DIR/profiles/cybersecurity.sh" "${TARGET_ARGS[@]}"
    ;;
  creation)
    "$ROOT_DIR/profiles/creation.sh"
    ;;
  windows)
    "$ROOT_DIR/profiles/windows.sh"
    ;;
  server)
    install_package_file "$ROOT_DIR/scripts/packages-server.txt"
    ;;
  installer-stack)
    "$ROOT_DIR/scripts/installer-stack.sh" install
    ;;
  hub-gui-stack)
    "$ROOT_DIR/seven-hub/gui-stack.sh" install
    ;;
  shell-ags)
    install_package_file "$ROOT_DIR/scripts/packages-shell-ags.txt"
    ;;
  shell-preview)
    "$ROOT_DIR/scripts/shell.sh" preview
    ;;
  flatpak)
    "$ROOT_DIR/scripts/flatpak.sh" "${TARGET_ARGS[@]}"
    ;;
  security)
    "$ROOT_DIR/security/hardening.sh"
    ;;
  cyber-audit)
    "$ROOT_DIR/security/cyber-audit.sh"
    ;;
  cyber-lab)
    "$ROOT_DIR/security/cyber-lab.sh" "${TARGET_ARGS[@]}"
    ;;
  blackarch-setup)
    "$ROOT_DIR/security/blackarch.sh" setup "${TARGET_ARGS[@]}"
    ;;
  blackarch-category)
    "$ROOT_DIR/security/blackarch.sh" category "${TARGET_ARGS[@]}"
    ;;
  blackarch-tool)
    "$ROOT_DIR/security/blackarch.sh" tool "${TARGET_ARGS[@]}"
    ;;
  doctor)
    "$ROOT_DIR/scripts/doctor.sh"
    ;;
  migrate-plan)
    "$ROOT_DIR/scripts/migrate.sh" plan
    ;;
  migrate-backup)
    "$ROOT_DIR/scripts/migrate.sh" backup
    ;;
  daily-driver)
    "$ROOT_DIR/scripts/daily-driver.sh" apply "${TARGET_ARGS[@]}"
    ;;
  post-install)
    "$ROOT_DIR/scripts/post-install.sh"
    ;;
  status)
    "$ROOT_DIR/scripts/status.sh" "${TARGET_ARGS[@]}"
    ;;
  branding)
    "$ROOT_DIR/branding/apply-branding.sh"
    ;;
  cli)
    "$ROOT_DIR/scripts/install-cli.sh"
    ;;
  theme)
    "$ROOT_DIR/scripts/apply-theme.sh" "${TARGET_ARGS[@]}"
    ;;
  hub)
    "$ROOT_DIR/seven-hub/install.sh"
    ;;
  iso-tools)
    install_package_file "$ROOT_DIR/scripts/packages-iso.txt"
    ;;
  iso)
    "$ROOT_DIR/scripts/build-iso.sh" "${TARGET_ARGS[@]}"
    ;;
  vm-check)
    "$ROOT_DIR/vm/check.sh"
    ;;
  vm-network)
    "$ROOT_DIR/vm/network.sh"
    ;;
  vm-windows)
    "$ROOT_DIR/vm/windows-vm.sh" "${TARGET_ARGS[@]}"
    ;;
  windows-mode)
    "$ROOT_DIR/vm/windows-mode.sh" "${TARGET_ARGS[@]}"
    ;;
  installer-plan)
    "$ROOT_DIR/installer/plan.sh" "${TARGET_ARGS[@]}"
    ;;
  installer-check)
    "$ROOT_DIR/installer/validate-plan.sh" "${TARGET_ARGS[@]}"
    ;;
  installer-script)
    "$ROOT_DIR/installer/generate-script.sh" "${TARGET_ARGS[@]}"
    ;;
  all)
    "$ROOT_DIR/profiles/all.sh"
    ;;
  *)
    log_error "Unknown target: $TARGET"
    usage
    exit 1
    ;;
esac

if [[ "$TARGET" == "status" && " $* " == *" --json "* ]]; then
  exit 0
fi

if [[ " $* " == *" --json "* ]]; then
  exit 0
fi

log_success "SevenOS target '$TARGET' completed."
