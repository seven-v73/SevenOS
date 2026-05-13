#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

LAB_NAME="default"
OFFLINE=0
SHELL_COMMAND="${SHELL:-/bin/bash}"

usage() {
  cat <<'EOF'
SevenOS Cyber Lab

Usage:
  ./install.sh cyber-lab [--name NAME] [--offline] [--shell SHELL] [--dry-run]

Examples:
  ./install.sh cyber-lab
  ./install.sh cyber-lab --name webapp
  ./install.sh cyber-lab --name malware-notes --offline

Behavior:
  Opens a Firejail session with a private home under ~/SevenOS-Labs/cyber/NAME.
  Use --offline to disable networking inside the lab.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --name)
      LAB_NAME="${2:-}"
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
  printf 'firejail'
  printf ' %q' "${firejail_args[@]}"
  printf ' -- %q\n' "$SHELL_COMMAND"
  exit 0
fi

require_command firejail
mkdir -p "$LAB_ROOT"

log_info "Opening SevenOS cyber lab: $LAB_NAME"
if [[ "$OFFLINE" -eq 1 ]]; then
  log_info "Network disabled inside this lab."
fi
log_info "Private lab home: $LAB_ROOT"

exec firejail "${firejail_args[@]}" -- "$SHELL_COMMAND"
