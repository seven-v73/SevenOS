#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

failures=0
warnings=0

section() {
  printf '\n== %s ==\n' "$1"
}

mark_warn() {
  warnings=$((warnings + 1))
  log_warn "$*"
}

run_required() {
  local label="$1"
  shift

  printf '[CHECK] %s\n' "$label"
  if "$@"; then
    printf '[OK] %s\n' "$label"
  else
    printf '[FAIL] %s\n' "$label" >&2
    failures=$((failures + 1))
  fi
}

run_advisory() {
  local label="$1"
  shift

  printf '[CHECK] %s\n' "$label"
  if "$@"; then
    printf '[OK] %s\n' "$label"
  else
    printf '[WARN] %s\n' "$label" >&2
    warnings=$((warnings + 1))
  fi
}

readiness_summary() {
  "$ROOT_DIR/scripts/readiness.sh" | sed -n '/== Category Scores ==/,$p'
}

git_summary() {
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$ROOT_DIR/.git" ]]; then
    mark_warn "Git repository not detected."
    return 0
  fi

  local status
  status="$(git -C "$ROOT_DIR" status --short)"
  if [[ -z "$status" ]]; then
    printf '[OK] Git worktree clean\n'
  else
    printf '%s\n' "$status" | sed 's/^/  /'
    mark_warn "Git worktree has uncommitted changes. Commit the phase before moving on."
  fi
}

printf 'SevenOS Phase Gate\n'
printf '==================\n'
printf 'Purpose: decide whether the current foundation is ready for the next phase.\n'

section "Required Checks"
run_required "Core repository checks" "$ROOT_DIR/scripts/check.sh"
run_required "UX coherence checks" "$ROOT_DIR/scripts/ux-check.sh"
run_required "Architecture foundation doctor" "$ROOT_DIR/scripts/architecture.sh" doctor
run_required "Readiness JSON export" "$ROOT_DIR/scripts/readiness.sh" --json
run_required "Ecosystem foundation doctor" "$ROOT_DIR/scripts/ecosystem.sh" doctor
run_required "Deployment planner dry-run" env SEVENOS_DRY_RUN=1 "$ROOT_DIR/server/seven-deploy.sh" plan "$ROOT_DIR"

section "Advisory Checks"
run_advisory "Server dependency doctor" "$ROOT_DIR/server/seven-server.sh" doctor

section "Readiness"
readiness_summary

section "Git"
git_summary

section "Decision"
if [[ "$failures" -gt 0 ]]; then
  log_error "Phase gate blocked: $failures required check(s) failed."
  exit 1
fi

if [[ "$warnings" -gt 0 ]]; then
  log_warn "Phase gate passed with $warnings advisory warning(s). Consolidate them before a release ISO."
  printf 'Next useful commands:\n'
  printf '  seven improve security --apply --yes\n'
  printf '  seven improve compatibility --apply --yes\n'
  printf '  seven improve deployment --apply --yes\n'
  printf '  seven readiness --record\n'
else
  log_success "Phase gate passed cleanly."
fi
