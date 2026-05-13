#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Ecosystem

Usage:
  seven ecosystem [status|roadmap|doctor]
  ./scripts/ecosystem.sh [status|roadmap|doctor]

Actions:
  status   Show all ecosystem modules and maturity
  roadmap  Show phase priorities
  doctor   Check whether ecosystem foundation files exist
EOF
}

module_line() {
  local name="$1"
  local phase="$2"
  local status="$3"
  local description="$4"

  printf '  %-20s %-8s %-10s %s\n' "$name" "$phase" "$status" "$description"
}

status() {
  printf 'SevenOS Ecosystem Map\n'
  printf '=====================\n'
  printf '  %-20s %-8s %-10s %s\n' "Module" "Phase" "Status" "Purpose"
  printf '  %-20s %-8s %-10s %s\n' "------" "-----" "------" "-------"
  module_line "seven" "1-2" "active" "system controller"
  module_line "sevenpkg" "2" "active" "package and meta-package layer"
  module_line "Seven Hub" "2-4" "preview" "control center"
  module_line "Windows Mode" "2-4" "preview" "Windows compatibility"
  module_line "seven-server" "3" "preview" "local API and monitoring"
  module_line "seven-deploy" "3" "preview" "deployment planner"
  module_line "SevenBox" "4" "planned" "rootless containers and sandbox UX"
  module_line "SevenAI" "4" "planned" "native assistant and automation"
  module_line "SevenDoctor" "3-4" "preview" "diagnostics and repair flow"
  module_line "Adaptive UI" "4" "planned" "profile-aware desktop behavior"
  module_line "SevenCloud" "5" "planned" "backup, sync and restore"
  module_line "SevenStore" "5" "planned" "apps, modules and themes marketplace"
  module_line "SevenIdentity" "5" "planned" "user identity and accent packs"
  module_line "SevenFlow" "5" "planned" "no-code automation rules"
  module_line "SevenCluster" "5" "planned" "multi-machine private compute"
}

roadmap() {
  printf 'SevenOS Innovation Roadmap\n'
  printf '==========================\n\n'
  printf 'Phase 4 - Intelligent OS Preview\n'
  printf '  - SevenAI provider-neutral command contract\n'
  printf '  - SevenDoctor guided repair suggestions\n'
  printf '  - SevenBox rootless container workflow\n'
  printf '  - Adaptive UI signals for Forge, Shield, Studio and Horizon\n'
  printf '  - Seven Hub dashboard cards for ecosystem modules\n\n'
  printf 'Phase 5 - Connected Ecosystem\n'
  printf '  - SevenCloud encrypted backup and restore\n'
  printf '  - SevenStore registry and trust policy\n'
  printf '  - SevenIdentity user/environment profiles\n'
  printf '  - SevenFlow automation rules\n'
  printf '  - SevenCluster local/private compute mesh\n'
}

doctor() {
  local failures=0

  printf 'SevenOS Ecosystem Doctor\n'
  printf '========================\n'

  for path in \
    "docs/ECOSYSTEM.md" \
    "docs/VISION.md" \
    "docs/PRODUCT_STRATEGY.md" \
    "bin/seven" \
    "bin/sevenpkg" \
    "seven-hub/bin/seven-hub" \
    "server/seven-server.sh" \
    "server/seven-deploy.sh" \
    "scripts/readiness.sh" \
    "scripts/phase-gate.sh"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  if [[ "$failures" -gt 0 ]]; then
    log_error "Ecosystem foundation has $failures missing file(s)."
    return 1
  fi

  log_success "Ecosystem foundation is coherent."
}

action="${1:-status}"
case "$action" in
  status) status ;;
  roadmap) roadmap ;;
  doctor) doctor ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown ecosystem action: $action"; usage; exit 1 ;;
esac
