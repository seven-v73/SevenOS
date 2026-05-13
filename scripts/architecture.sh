#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Architecture

Usage:
  seven architecture [map|layers|doctor]
  ./scripts/architecture.sh [map|layers|doctor]

Actions:
  map     Show control plane and product architecture
  layers  Show system layers and modules
  doctor  Validate architecture foundation files and entrypoints
EOF
}

layers() {
  printf 'SevenOS System Layers\n'
  printf '=====================\n'
  printf '  %-22s %s\n' "Layer" "Modules"
  printf '  %-22s %s\n' "-----" "-------"
  printf '  %-22s %s\n' "System Core" "install.sh, bootstrap.sh, seven, repair, readiness, phase-gate"
  printf '  %-22s %s\n' "Package Layer" "sevenpkg, package manifests, meta-packages"
  printf '  %-22s %s\n' "Service Layer" "seven-session, seven-server, seven-deploy, systemd"
  printf '  %-22s %s\n' "UI Layer" "Hyprland, Waybar, Rofi, Kitty, Mako, Seven Hub, Seven Files"
  printf '  %-22s %s\n' "Security Layer" "hardening, cyber audit, cyber lab, sandboxing"
  printf '  %-22s %s\n' "Compatibility Layer" "Wine, Bottles, Lutris, KVM, Windows Mode"
  printf '  %-22s %s\n' "Deployment Layer" "Horizon, local API, deploy planner"
  printf '  %-22s %s\n' "Identity Layer" "branding, palette, vocabulary, wallpaper, icons"
  printf '  %-22s %s\n' "Installer Layer" "archiso, install planner, generated script"
}

map() {
  printf 'SevenOS Architecture Map\n'
  printf '========================\n\n'
  printf 'Product problem:\n'
  printf '  Linux is powerful but fragmented. SevenOS unifies daily desktop, dev,\n'
  printf '  cyber, creation, Windows compatibility and deployment into one system.\n\n'
  printf 'Control plane:\n'
  printf '  User -> Seven Hub / CLI -> seven -> profiles/scripts/services -> system\n\n'
  printf 'Core entrypoints:\n'
  printf '  seven              system controller\n'
  printf '  sevenpkg           package and meta-package manager\n'
  printf '  seven hub          visual control center\n'
  printf '  seven files        file experience\n'
  printf '  seven-server       local API foundation\n'
  printf '  seven-deploy       deployment planner\n\n'
  layers
}

doctor() {
  local failures=0
  local path

  printf 'SevenOS Architecture Doctor\n'
  printf '===========================\n'

  for path in \
    "docs/ARCHITECTURE.md" \
    "docs/VISION.md" \
    "docs/PRODUCT_STRATEGY.md" \
    "docs/UX_PRINCIPLES.md" \
    "docs/VOCABULARY.md" \
    "docs/OS_CRITERIA.md" \
    "docs/DEPLOYMENT.md" \
    "docs/ECOSYSTEM.md" \
    "install.sh" \
    "bootstrap.sh" \
    "bin/seven" \
    "bin/sevenpkg" \
    "bin/seven-session" \
    "bin/seven-files" \
    "seven-hub/bin/seven-hub" \
    "seven-hub/bin/seven-control-center" \
    "server/seven-server.sh" \
    "server/seven-deploy.sh" \
    "scripts/readiness.sh" \
    "scripts/phase-gate.sh" \
    "scripts/ux-check.sh" \
    "scripts/check.sh" \
    "scripts/packages-base.txt" \
    "sevenpkg/metapackages.json" \
    "security/hardening.sh" \
    "vm/windows-mode.sh" \
    "installer/plan.sh" \
    "archiso/README.md"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  if ! grep -q 'System Core' "$ROOT_DIR/docs/ARCHITECTURE.md" ||
     ! grep -q 'Package Layer' "$ROOT_DIR/docs/ARCHITECTURE.md" ||
     ! grep -q 'Security Layer' "$ROOT_DIR/docs/ARCHITECTURE.md" ||
     ! grep -q 'Deployment Layer' "$ROOT_DIR/docs/ARCHITECTURE.md"; then
    printf '[MISS] docs/ARCHITECTURE.md missing required layer language\n'
    failures=$((failures + 1))
  else
    printf '[OK] architecture layers documented\n'
  fi

  if ! grep -q 'architecture_parser' "$ROOT_DIR/bin/seven"; then
    printf '[MISS] seven architecture entrypoint missing\n'
    failures=$((failures + 1))
  else
    printf '[OK] seven architecture entrypoint\n'
  fi

  if [[ "$failures" -gt 0 ]]; then
    log_error "Architecture foundation has $failures issue(s)."
    return 1
  fi

  log_success "Architecture foundation is coherent."
}

action="${1:-map}"
case "$action" in
  map|status) map ;;
  layers) layers ;;
  doctor) doctor ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown architecture action: $action"; usage; exit 1 ;;
esac
