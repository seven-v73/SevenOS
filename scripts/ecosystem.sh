#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Ecosystem

Usage:
  seven ecosystem [status|processes|summary|roadmap|doctor|json]
  ./scripts/ecosystem.sh [status|processes|summary|roadmap|doctor|json]

Actions:
  status     Show all ecosystem modules and maturity
  processes  Show end-to-end all-in-one user flows
  summary    Show compact module/process counts
  roadmap    Show phase priorities
  doctor     Check whether ecosystem foundation files exist
  json       Print machine-readable ecosystem map
EOF
}

modules_tsv() {
  cat <<'EOF'
seven	1-2	active	System controller, repair entrypoint and OS command surface	bin/seven
sevenpkg	2	active	Software, meta-packages and future app layer	bin/sevenpkg
Seven Hub	2-4	preview	Native control center, action launcher and user-facing OS surface	seven-hub/bin/seven-hub
Seven Profiles	2-4	active	Adaptive Forge, Shield, Studio, Windows, Horizon and Baobab contexts	profiles/profile-manager.sh
Seven Files	2	active	Profile-aware file entrypoint and workspace bridge	bin/seven-files
Windows Mode	2-4	preview	Wine, Bottles, Lutris and KVM/QEMU compatibility	vm/windows-mode.sh
SevenShield	2-4	preview	Security hardening, audit, sandbox and Cyber Lab	security/cyber-audit.sh
Seven Server	3	preview	Local API, monitoring and orchestration backend	server/seven-server.sh
Seven Deploy	3	preview	Project detection and deployment planner	server/seven-deploy.sh
Seven Installer	3	preview	Archiso, Calamares and install planning foundation	installer/calamares/README.md
SevenBox	4	preview	Rootless containers and sandbox UX	scripts/box.sh
SevenAI	4	preview	Local system assistant, readiness guidance and automation contract	scripts/ai.sh
Adaptive UI	4	preview	Profile-aware shell, Waybar, panels and Hub actions	bin/seven-shell-panel
Seven Shell	3	active	Native GTK, Waybar, Dock and AGS migration path	scripts/shell.sh
SevenCloud	5	preview	Encrypted backup, config sync and restore	scripts/cloud.sh
SevenStore	5	preview	Apps, profiles, themes and module registry	scripts/store.sh
SevenIdentity	5	preview	User identity, accent packs, permissions and environment	scripts/identity.sh
SevenFlow	5	preview	No-code automation rules for system workflows	scripts/flow.sh
SevenCluster	5	planned	Local/private multi-machine compute mesh	scripts/ecosystem.sh
EOF
}

processes_tsv() {
  cat <<'EOF'
First Run	experience	active	seven welcome -> profile select -> theme -> readiness -> Hub	seven welcome
Daily Control	desktop	active	Waybar -> Quick Settings -> Seven Hub -> actions registry	seven hub
Install Apps	software	preview	SevenStore -> sevenpkg -> Flatpak -> profile apps	seven store
Work Profiles	productivity	active	Forge/Shield/Studio/Windows/Horizon context -> workspace -> apps	seven profile current
Windows Apps	compatibility	preview	Windows profile -> Bottles/Wine or KVM VM -> shared workspace	seven windows guide
Security Trust	security	preview	Shield audit -> UFW/Firejail/Bubblewrap -> Cyber Lab	seven shield audit
Create & Media	creation	preview	Studio profile -> creative apps -> project workspace	seven profile guide studio
Develop & Deploy	deployment	preview	Forge/Horizon -> stack detect -> local API -> deploy planner	seven deploy plan .
Personal Cloud	cloud	preview	SevenCloud -> local-first backup plan -> restore contract	seven cloud
Marketplace	store	preview	SevenStore -> modules/apps/actions -> guided install	seven store
Automation	automation	preview	SevenFlow -> recipes -> confirmed actions -> logs	seven flow
Identity	identity	preview	SevenIdentity -> user context -> regional accents -> permissions	seven identity
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
  while IFS=$'\t' read -r name phase state description _path; do
    module_line "$name" "$phase" "$state" "$description"
  done < <(modules_tsv)
}

processes() {
  printf 'SevenOS All-In-One Process Map\n'
  printf '==============================\n'
  printf '  %-18s %-14s %-10s %s\n' "Process" "Layer" "Status" "Flow"
  printf '  %-18s %-14s %-10s %s\n' "-------" "-----" "------" "----"
  while IFS=$'\t' read -r name layer state flow command; do
    printf '  %-18s %-14s %-10s %s\n' "$name" "$layer" "$state" "$flow"
    printf '  %-18s %-14s %-10s command: %s\n' "" "" "" "$command"
  done < <(processes_tsv)
}

summary() {
  local active=0 preview=0 next=0 planned=0 process_count=0
  local _name _phase state _description _path

  while IFS=$'\t' read -r _name _phase state _description _path; do
    case "$state" in
      active) active=$((active + 1)) ;;
      preview) preview=$((preview + 1)) ;;
      next) next=$((next + 1)) ;;
      planned) planned=$((planned + 1)) ;;
    esac
  done < <(modules_tsv)

  while IFS= read -r _line; do
    process_count=$((process_count + 1))
  done < <(processes_tsv)

  printf 'SevenOS Ecosystem: %s active, %s preview, %s next, %s planned, %s processes\n' "$active" "$preview" "$next" "$planned" "$process_count"
}

roadmap() {
  printf 'SevenOS Innovation Roadmap\n'
  printf '==========================\n\n'
  printf 'Phase 4 - Intelligent OS Preview\n'
  printf '  - SevenAI Local readiness guidance and provider-neutral command contract\n'
  printf '  - SevenDoctor guided repair suggestions\n'
  printf '  - SevenBox rootless container workflow\n'
  printf '  - Adaptive UI signals for Forge, Shield, Studio and Horizon\n'
  printf '  - Seven Hub dashboard cards for ecosystem modules\n\n'
  printf 'Phase 5 - Connected Ecosystem\n'
  printf '  - SevenCloud encrypted backup and restore\n'
  printf '  - SevenStore trust policy, reviews and signed module feeds\n'
  printf '  - SevenIdentity user/environment profiles\n'
  printf '  - SevenFlow automation rules\n'
  printf '  - SevenCluster local/private compute mesh\n'
}

json() {
  MODULES_TSV="$(modules_tsv)" PROCESSES_TSV="$(processes_tsv)" python - <<'PY'
import json
import os

modules = []
for raw in os.environ["MODULES_TSV"].splitlines():
    name, phase, state, purpose, path = raw.split("\t", 4)
    modules.append({
        "name": name,
        "phase": phase,
        "state": state,
        "purpose": purpose,
        "path": path,
    })

processes = []
for raw in os.environ["PROCESSES_TSV"].splitlines():
    name, layer, state, flow, command = raw.split("\t", 4)
    processes.append({
        "name": name,
        "layer": layer,
        "state": state,
        "flow": flow,
        "command": command,
    })

print(json.dumps({
    "schema": "sevenos.ecosystem.v1",
    "positioning": "all-in-one African first Linux ecosystem",
    "modules": modules,
    "processes": processes,
}, indent=2))
PY
}

doctor() {
  local failures=0

  printf 'SevenOS Ecosystem Doctor\n'
  printf '========================\n'

  for path in \
    "docs/ECOSYSTEM.md" \
    "docs/ARCHITECTURE.md" \
    "docs/VISION.md" \
    "docs/PRODUCT_STRATEGY.md" \
    "docs/ECOSYSTEM.md" \
    "bin/seven" \
    "bin/sevenpkg" \
    "seven-hub/bin/seven-hub" \
    "seven-hub/gui-stack.sh" \
    "server/seven-server.sh" \
    "server/seven-deploy.sh" \
    "scripts/architecture.sh" \
    "scripts/readiness.sh" \
    "scripts/actions.sh" \
    "scripts/ai.sh" \
    "scripts/box.sh" \
    "scripts/cloud.sh" \
    "scripts/flow.sh" \
    "scripts/identity.sh" \
    "scripts/store.sh" \
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
  processes|process) processes ;;
  summary) summary ;;
  roadmap) roadmap ;;
  doctor) doctor ;;
  json|--json) json ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown ecosystem action: $action"; usage; exit 1 ;;
esac
