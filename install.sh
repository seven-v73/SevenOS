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
  atlas            Install Atlas Explorer mini OS
  server           Install SevenOS server and deployment layer
  installer-stack  Install graphical installer foundation packages
  calamares-runtime
                   Prepare the Calamares package source for public ISO builds
  hub-gui-stack    Install Seven Hub Tauri GUI foundation packages
  shell-ags        Install Seven Shell AGS/TypeScript foundation packages
  shell-ags-runtime
                   Install Aylur's Gtk Shell runtime from the explicit AUR route
  runtime-tools    Install optional runtime orchestration tools such as CRIU
  network          Prepare and repair Wi-Fi/NetworkManager stack
  language         Prepare and inspect French/English language packs
  system-profile   Ensure Equinox is the host-system/admin side
  system-install    Install SevenOS into /opt/SevenOS for public updates
  aur-helpers      Install yay and paru for SevenOS AUR-backed features
  hypr-ecosystem   Install premium Hyprland ecosystem tools
  shell-preview    Preview Seven Shell AGS migration plan
  flatpak          Manage Flatpak/Flathub bridge
  security         Apply base security hardening
  cyber-audit      Show cybersecurity profile readiness
  cyber-lab        Open an isolated cybersecurity lab shell
  blackarch-setup  Add the optional BlackArch repository bridge
  blackarch-full   Install the complete BlackArch package set
  blackarch-category <name>
                   Install one BlackArch category, for example webapp
  blackarch-tool <pkg>
                   Install one BlackArch package
  doctor           Check host readiness
  post-install     Check common post-install blockers
  status           Show SevenOS installation status
  branding         Apply SevenOS system branding
  identity         Install SevenOS identity requirements, splash and login theme
  boot-splash      Apply SevenOS quiet boot/shutdown splash
  login-theme      Apply SevenOS SDDM login screen
  cli              Install SevenOS CLI tools
  theme [dark|light]
                   Apply SevenOS visual theme
  hub              Install Seven Hub launcher
  iso-tools        Install ISO build tooling
  iso              Build SevenOS live ISO
  vm-check         Check KVM/libvirt readiness
  vm-network       Start and autostart libvirt default network
  installer-plan   Create a non-destructive install plan
  installer-check  Validate an install plan
  installer-script Generate non-destructive install step script
  migrate-plan     Show SevenOS protected user-state migration plan
  migrate-backup   Back up protected SevenOS user state before upgrading
  daily-driver     Consolidate SevenOS for primary PC testing
  new              One-command fresh machine setup
  new-device       Fully prepare a fresh machine: fonts, deps, profiles, isolation
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

if [[ "$TARGET" != "doctor" && "$TARGET" != "status" && "$TARGET" != "language" && "$TARGET" != "languages" && "$TARGET" != "locale" && "$TARGET" != "migrate-plan" && "$TARGET" != "migrate-backup" && "$TARGET" != "calamares-runtime" ]]; then
  require_arch
  if [[ -z "$(privileged_backend)" ]]; then
    log_error "SevenOS needs sudo or a graphical Polkit prompt for package/system changes."
    exit 1
  fi
  require_command pacman
fi

case "$TARGET" in
  base)
    "$ROOT_DIR/bootstrap.sh"
    ;;
  culture)
    install_package_file "$ROOT_DIR/scripts/packages-culture.txt"
    ;;
  performance)
    install_package_file "$ROOT_DIR/scripts/packages-performance.txt"
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
  atlas)
    "$ROOT_DIR/profiles/atlas.sh"
    ;;
  server)
    install_package_file "$ROOT_DIR/scripts/packages-server.txt"
    ;;
  installer-stack)
    "$ROOT_DIR/scripts/installer-stack.sh" install
    ;;
  calamares-runtime)
    if [[ "${#TARGET_ARGS[@]}" -eq 0 ]]; then
      "$ROOT_DIR/scripts/calamares-runtime.sh" status
    else
      "$ROOT_DIR/scripts/calamares-runtime.sh" "${TARGET_ARGS[@]}"
    fi
    ;;
  hub-gui-stack)
    "$ROOT_DIR/seven-hub/gui-stack.sh" install
    ;;
  shell-ags)
    install_package_file "$ROOT_DIR/scripts/packages-shell-ags.txt"
    ;;
  shell-ags-runtime)
    "$ROOT_DIR/scripts/shell-ags-runtime.sh" install
    ;;
  runtime-tools)
    install_package_file "$ROOT_DIR/scripts/packages-runtime-optional.txt"
    ;;
  network)
    "$ROOT_DIR/scripts/network.sh" bootstrap "${TARGET_ARGS[@]}"
    ;;
  language|languages|locale)
    if [[ "${#TARGET_ARGS[@]}" -eq 0 || "${TARGET_ARGS[0]}" == "prepare" || "${TARGET_ARGS[0]}" == "apply" || "${TARGET_ARGS[0]}" == "defaults" ]]; then
      "$ROOT_DIR/bin/seven-language" ensure en_US.UTF-8
      "$ROOT_DIR/bin/seven-language" ensure fr_FR.UTF-8
      "$ROOT_DIR/bin/seven-language" doctor
    else
      "$ROOT_DIR/bin/seven-language" "${TARGET_ARGS[@]}"
    fi
    ;;
  system-profile|equinox|equinox-system)
    if [[ "$YES" == "1" ]]; then
      "$ROOT_DIR/scripts/system-profile.sh" apply --yes "${TARGET_ARGS[@]}"
    else
      "$ROOT_DIR/scripts/system-profile.sh" apply "${TARGET_ARGS[@]}"
    fi
    ;;
  system-install|public-install|opt-install)
    if [[ "$YES" == "1" ]]; then
      "$ROOT_DIR/scripts/system-install.sh" --yes "${TARGET_ARGS[@]}"
    else
      "$ROOT_DIR/scripts/system-install.sh" "${TARGET_ARGS[@]}"
    fi
    ;;
  aur-helpers)
    "$ROOT_DIR/scripts/aur-helpers.sh" install
    ;;
  hypr-ecosystem)
    "$ROOT_DIR/scripts/hypr-ecosystem.sh" install "${TARGET_ARGS[@]}"
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
  blackarch-full)
    "$ROOT_DIR/security/blackarch.sh" full "${TARGET_ARGS[@]}"
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
  new|new-device|fresh-device|first-boot|setup)
    if [[ "$YES" == "1" ]]; then
      "$ROOT_DIR/scripts/new-device.sh" --yes "${TARGET_ARGS[@]}"
    else
      "$ROOT_DIR/scripts/new-device.sh" "${TARGET_ARGS[@]}"
    fi
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
  identity)
    install_package_file "$ROOT_DIR/scripts/packages-identity.txt"
    "$ROOT_DIR/scripts/boot-splash.sh" apply "${TARGET_ARGS[@]}"
    "$ROOT_DIR/scripts/login-theme.sh" apply "${TARGET_ARGS[@]}"
    ;;
  boot-splash)
    "$ROOT_DIR/scripts/boot-splash.sh" apply "${TARGET_ARGS[@]}"
    ;;
  login-theme)
    "$ROOT_DIR/scripts/login-theme.sh" apply "${TARGET_ARGS[@]}"
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
