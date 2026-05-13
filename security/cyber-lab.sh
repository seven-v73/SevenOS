#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

LAB_NAME="default"
OFFLINE=0
SHELL_COMMAND="${SHELL:-/bin/bash}"
PRESET="default"

usage() {
  cat <<'EOF'
SevenOS Cyber Lab

Usage:
  ./install.sh cyber-lab [--preset NAME] [--name NAME] [--offline] [--shell SHELL] [--dry-run]

Examples:
  ./install.sh cyber-lab
  ./install.sh cyber-lab --preset web
  ./install.sh cyber-lab --preset forensics
  ./install.sh cyber-lab --preset reversing
  ./install.sh cyber-lab --preset offline
  ./install.sh cyber-lab --name webapp
  ./install.sh cyber-lab --name malware-notes --offline

Behavior:
  Opens a Firejail session with a private home under ~/SevenOS-Labs/cyber/NAME.
  Use --offline to disable networking inside the lab.
EOF
}

apply_preset() {
  case "$PRESET" in
    default)
      ;;
    web)
      LAB_NAME="${LAB_NAME:-web}"
      ;;
    forensics)
      LAB_NAME="${LAB_NAME:-forensics}"
      OFFLINE=1
      ;;
    reversing)
      LAB_NAME="${LAB_NAME:-reversing}"
      OFFLINE=1
      ;;
    offline)
      LAB_NAME="${LAB_NAME:-offline}"
      OFFLINE=1
      ;;
    *)
      log_error "Unknown cyber-lab preset: $PRESET"
      usage
      exit 1
      ;;
  esac
}

write_lab_readme() {
  local readme="$LAB_ROOT/README.md"

  cat > "$readme" <<EOF
# SevenOS Cyber Lab: $LAB_NAME

Preset: $PRESET
Network: $([[ "$OFFLINE" -eq 1 ]] && printf 'disabled' || printf 'enabled')

This directory is the private home for an isolated Firejail session.

Recommended workflow:

- keep notes and captures inside this lab
- avoid mixing unrelated assessments
- use only authorized systems and networks
- export reports intentionally after review

Useful commands:

\`\`\`bash
seven shield audit
sevenpkg info shield
\`\`\`
EOF
}

print_banner() {
  cat <<EOF
SevenOS Cyber Lab
=================
Lab:     $LAB_NAME
Preset:  $PRESET
Network: $([[ "$OFFLINE" -eq 1 ]] && printf 'offline' || printf 'enabled')
Home:    $LAB_ROOT

Authorized work only.
EOF
}

name_was_set=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --preset)
      PRESET="${2:-}"
      shift 2
      ;;
    --name)
      LAB_NAME="${2:-}"
      name_was_set=1
      shift 2
      ;;
    --offline)
      OFFLINE=1
      shift
      ;;
    --shell)
      SHELL_COMMAND="${2:-}"
      shift 2
      ;;
    --dry-run)
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown cyber-lab option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$name_was_set" -eq 0 ]]; then
  LAB_NAME=""
fi
apply_preset
if [[ -z "$LAB_NAME" ]]; then
  LAB_NAME="default"
fi

[[ -n "$LAB_NAME" ]] || { log_error "Lab name cannot be empty."; exit 1; }
[[ "$LAB_NAME" =~ ^[a-zA-Z0-9._-]+$ ]] || { log_error "Invalid lab name: $LAB_NAME"; exit 1; }
[[ -n "$SHELL_COMMAND" ]] || { log_error "Shell command cannot be empty."; exit 1; }

LAB_ROOT="$HOME/SevenOS-Labs/cyber/$LAB_NAME"
firejail_args=(--private="$LAB_ROOT" --private-cache --hostname="sevenos-$LAB_NAME")

if [[ "$OFFLINE" -eq 1 ]]; then
  firejail_args+=(--net=none)
fi

if is_dry_run; then
  printf 'mkdir -p %q\n' "$LAB_ROOT"
  printf 'write README %q\n' "$LAB_ROOT/README.md"
  printf 'firejail'
  printf ' %q' "${firejail_args[@]}"
  printf ' -- %q\n' "$SHELL_COMMAND"
  exit 0
fi

require_command firejail
mkdir -p "$LAB_ROOT"
write_lab_readme

log_info "Opening SevenOS cyber lab: $LAB_NAME"
if [[ "$OFFLINE" -eq 1 ]]; then
  log_info "Network disabled inside this lab."
fi
log_info "Private lab home: $LAB_ROOT"
print_banner

exec firejail "${firejail_args[@]}" -- "$SHELL_COMMAND"
