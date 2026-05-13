#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS CYBERSECURITY profile

Usage:
  ./install.sh cybersecurity [core|forensics|reversing|wireless|sandbox|all]

Default:
  all
EOF
}

install_cyber_category() {
  local category="$1"

  case "$category" in
    core)
      install_package_file "$ROOT_DIR/scripts/packages-cybersecurity.txt"
      ;;
    forensics)
      install_package_file "$ROOT_DIR/scripts/packages-cybersecurity-forensics.txt"
      ;;
    reversing)
      install_package_file "$ROOT_DIR/scripts/packages-cybersecurity-reversing.txt"
      ;;
    wireless)
      install_package_file "$ROOT_DIR/scripts/packages-cybersecurity-wireless.txt"
      ;;
    sandbox)
      install_package_file "$ROOT_DIR/scripts/packages-cybersecurity-sandbox.txt"
      ;;
    all)
      install_cyber_category core
      install_cyber_category forensics
      install_cyber_category reversing
      install_cyber_category wireless
      install_cyber_category sandbox
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown cybersecurity category: $category"
      usage
      exit 1
      ;;
  esac
}

category="${1:-all}"

log_info "Installing SevenOS CYBERSECURITY profile: $category"
install_cyber_category "$category"

add_user_to_group wireshark "$USER"
log_info "SevenOS Cyber Core uses official Arch packages first."
log_warn "Use security tooling only on systems and networks where you have permission."
log_warn "For the larger BlackArch catalog, use './install.sh blackarch-setup' only when you explicitly need it."

log_success "CYBERSECURITY profile installed."
log_info "Shield workspace ready. Next: seven shield audit or seven shield lab --preset web"
