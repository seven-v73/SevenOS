#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS action registry

Usage:
  seven actions
  seven actions --json
  seven actions list
  seven actions category <name>
  seven actions run <id> [--dry-run]

The registry is the shared action contract for Seven Hub, Waybar,
Quick Settings and future native SevenOS surfaces.
EOF
}

action_rows() {
  cat <<'EOF'
hub.open	Desktop	Open Seven Hub	seven hub	safe	Open the SevenOS Control Center.
apps.open	Desktop	Open Apps	seven-overview apps	safe	Open the SevenOS application library.
files.open	Desktop	Open Files	seven-files	safe	Open Seven Files.
quick.open	Desktop	Open Quick Settings	seven-quick-settings	safe	Open SevenOS quick controls.
readiness.run	System	Run Readiness	seven readiness	safe	Score SevenOS against product readiness checks.
experience.run	System	Experience Audit	seven experience	safe	Check whether SevenOS behaves like a coherent OS.
control.plan	System	Control Plane	seven control	safe	Show prioritized SevenOS actions across readiness, trust and services.
control.preview	System	Preview Control Fixes	seven control apply --limit 5	safe	Preview the next prioritized SevenOS fixes without changing the system.
events.open	System	Event Journal	seven events	safe	Show local SevenOS decision and action history.
insights.open	System	OS Insights	seven insights	safe	Show product-facing SevenOS limits and next actions.
doctor.run	System	Run Doctor	seven doctor	safe	Check common system blockers.
repair.ux	System	Repair UX	seven repair ux	changes	Review desktop and shell repair actions.
theme.apply	System	Apply Theme	./install.sh theme	changes	Reapply SevenOS shell, toolkit and wallpaper identity.
profile.status	Profiles	Profile Status	seven profile status	safe	Show installed and active profile state.
profile.current	Profiles	Current Profile	seven profile current	safe	Show the active profile in detail.
profile.guide	Profiles	Profile Guide	seven profile guide	safe	Show recommended actions for the active profile.
profile.apps	Profiles	Profile Apps	seven profile apps	safe	Show apps and launch commands for the active profile.
profile.gaps	Profiles	Profile Gaps	seven profile gaps	safe	Show incomplete profile packages, apps and next actions.
profile.plan	Profiles	Profile Plan	seven profile plan	safe	Show prioritized profile completion plan.
profile.open	Profiles	Open Active Workspace	seven profile open	safe	Open the current profile workspace.
profile.activate.forge	Profiles	Activate Forge	seven profile activate forge	changes	Switch the desktop context to Forge.
profile.activate.shield	Profiles	Activate Shield	seven profile activate shield	changes	Switch the desktop context to Shield.
profile.activate.studio	Profiles	Activate Studio	seven profile activate studio	changes	Switch the desktop context to Studio.
profile.activate.windows	Profiles	Activate Windows	seven profile activate windows	changes	Switch the desktop context to Windows Mode.
profile.activate.horizon	Profiles	Activate Horizon	seven profile activate horizon	changes	Switch the desktop context to Horizon.
profile.forge	Profiles	Install Forge	seven profile install forge	packages	Install the development workspace.
profile.shield	Profiles	Install Shield	seven profile install shield	packages	Install the cybersecurity workspace.
profile.studio	Profiles	Install Studio	seven profile install studio	packages	Install the creative workspace.
profile.windows	Profiles	Install Windows Mode	seven profile install windows	packages	Install Windows compatibility tooling.
profile.horizon	Profiles	Install Horizon	seven profile install horizon	packages	Install server and deployment tooling.
security.audit	Security	Shield Audit	seven shield audit	safe	Audit firewall, sandbox and cyber tooling.
security.status	Security	Shield Status	seven shield status	safe	Show firewall, sandbox and Shield trust posture.
security.enable	Security	Enable Shield	seven shield enable	changes	Apply base SevenOS security hardening.
security.lab	Security	Open Cyber Lab	seven shield lab --preset web	safe	Open an isolated web testing lab.
windows.status	Windows	Windows Status	seven windows status	safe	Check Wine, Bottles and VM readiness.
windows.guide	Windows	Windows Guide	seven windows guide	safe	Explain Bottles, Wine and KVM Windows paths.
windows.open	Windows	Open Windows Mode	seven windows open	safe	Open Bottles or Virt Manager depending on what is available.
windows.apps	Windows	Windows Apps	seven windows apps	safe	Open Bottles for Windows applications.
windows.vm	Windows	Windows VM	seven windows vm	safe	Open Virt Manager for the Windows VM.
windows.create	Windows	Create Windows VM	seven windows create	packages	Start the guided Windows VM creation command.
windows.start	Windows	Start Windows VM	seven windows start	changes	Start the SevenOS Windows virtual machine.
server.status	Server	Server Status	seven server status	safe	Check the local SevenOS API service.
server.install	Server	Install Server Service	seven server install-user-service	changes	Install the local SevenOS API user service.
server.start	Server	Start Server Service	seven server start	changes	Start the local SevenOS API user service.
deploy.plan	Server	Deployment Plan	seven deploy plan .	safe	Detect and plan deployment for the current project.
installer.status	Installer	Installer Status	seven installer status	safe	Check Calamares and ISO foundations.
flatpak.status	Apps	Flatpak Status	seven flatpak status	safe	Check Flathub and Flatpak readiness.
sevenpkg.status	Apps	SevenPkg Status	sevenpkg status	safe	Show SevenOS software layer state.
ecosystem.status	Ecosystem	Ecosystem Map	seven ecosystem	safe	Show modules and maturity states.
ecosystem.processes	Ecosystem	Process Map	seven ecosystem processes	safe	Show all-in-one SevenOS user flows.
ecosystem.roadmap	Ecosystem	Ecosystem Roadmap	seven ecosystem roadmap	safe	Show Phase 4 and Phase 5 priorities.
ecosystem.doctor	Ecosystem	Ecosystem Doctor	seven ecosystem doctor	safe	Validate ecosystem foundation files.
EOF
}

print_rows_for_category() {
  local wanted="$1"
  action_rows | awk -F '\t' -v wanted="$wanted" 'tolower($2) == tolower(wanted)'
}

json_output() {
  local rows
  rows="${1:-$(action_rows)}"
  ACTION_ROWS="$rows" python - <<'PY'
import json
import os

items = []
for raw in os.environ.get("ACTION_ROWS", "").splitlines():
    raw = raw.rstrip("\n")
    if not raw:
        continue
    action_id, category, title, command, impact, description = raw.split("\t", 5)
    items.append({
        "id": action_id,
        "category": category,
        "title": title,
        "command": command,
        "impact": impact,
        "description": description,
    })

print(json.dumps({
    "schema": "sevenos.actions.v1",
    "actions": items,
}, indent=2))
PY
}

list_output() {
  printf '%-22s %-11s %-24s %s\n' "ID" "IMPACT" "CATEGORY" "TITLE"
  local rows
  rows="${1:-$(action_rows)}"
  while IFS=$'\t' read -r action_id category title _command impact _description; do
    [[ -n "${action_id:-}" ]] || continue
    printf '%-22s %-11s %-24s %s\n' "$action_id" "$impact" "$category" "$title"
  done <<<"$rows"
}

command_for_id() {
  local wanted="$1"
  action_rows | awk -F '\t' -v wanted="$wanted" '$1 == wanted { print $4; found=1 } END { exit found ? 0 : 1 }'
}

run_action() {
  local action_id="$1"
  local command
  command="$(command_for_id "$action_id")" || {
    log_error "Unknown SevenOS action: $action_id"
    exit 1
  }

  if is_dry_run; then
    printf '%s\n' "$command"
    return 0
  fi

  log_info "Running SevenOS action: $action_id"
  bash -lc "cd '$ROOT_DIR' && $command"
}

ACTION="${1:-list}"
case "$ACTION" in
  -h|--help|help)
    usage
    ;;
  --json|json)
    json_output
    ;;
  list)
    list_output
    ;;
  category)
    shift
    if [[ -z "${1:-}" ]]; then
      log_error "Missing category name."
      usage
      exit 1
    fi
    rows="$(print_rows_for_category "$1")"
    if [[ -z "$rows" ]]; then
      log_error "Unknown SevenOS action category: $1"
      exit 1
    fi
    list_output "$rows"
    ;;
  run)
    shift
    if [[ -z "${1:-}" ]]; then
      log_error "Missing action id."
      usage
      exit 1
    fi
    run_action "$1"
    ;;
  *)
    log_error "Unknown actions command: $ACTION"
    usage
    exit 1
    ;;
esac
