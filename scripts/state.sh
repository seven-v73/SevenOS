#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS state snapshot

Usage:
  seven state --json
  ./scripts/state.sh --json

This command is a machine-facing contract for Seven Hub, native UI,
automation and future Seven Server endpoints.
EOF
}

JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown state option: $arg"; usage; exit 1 ;;
  esac
done

if [[ "$JSON_OUTPUT" -ne 1 ]]; then
  usage
  exit 0
fi

json_or_null() {
  local command_output
  if command -v timeout >/dev/null 2>&1; then
    if command_output="$(SEVENOS_DRY_RUN=0 timeout 8 "$@" 2>/dev/null)" && [[ -n "$command_output" ]]; then
      printf '%s' "$command_output"
    else
      printf 'null'
    fi
  elif command_output="$(SEVENOS_DRY_RUN=0 "$@" 2>/dev/null)" && [[ -n "$command_output" ]]; then
    printf '%s' "$command_output"
  else
    printf 'null'
  fi
}

json_to_file() {
  local output_file="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    SEVENOS_DRY_RUN=0 timeout 8 "$@" > "$output_file" 2>/dev/null || printf 'null' > "$output_file"
  else
    SEVENOS_DRY_RUN=0 "$@" > "$output_file" 2>/dev/null || printf 'null' > "$output_file"
  fi

  [[ -s "$output_file" ]] || printf 'null' > "$output_file"
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

STATE_TMP="$(mktemp -d)"
trap 'rm -rf "$STATE_TMP"' EXIT

json_to_file "$STATE_TMP/status.json" "$ROOT_DIR/bin/seven" status --json &
pid_status=$!
json_to_file "$STATE_TMP/profiles.json" "$ROOT_DIR/bin/seven" profile status --json &
pid_profiles=$!
json_to_file "$STATE_TMP/profile_gaps.json" "$ROOT_DIR/bin/seven" profile gaps --json &
pid_profile_gaps=$!
json_to_file "$STATE_TMP/profile_plan.json" "$ROOT_DIR/bin/seven" profile plan --json &
pid_profile_plan=$!
json_to_file "$STATE_TMP/active_profile.json" "$ROOT_DIR/bin/seven" profile current --json &
pid_active_profile=$!
json_to_file "$STATE_TMP/windows.json" "$ROOT_DIR/bin/seven-windows-assistant" status --json &
pid_windows=$!
json_to_file "$STATE_TMP/shield.json" "$ROOT_DIR/security/shield-status.sh" --json &
pid_shield=$!
json_to_file "$STATE_TMP/shield_plan.json" "$ROOT_DIR/security/shield-status.sh" plan --json &
pid_shield_plan=$!
json_to_file "$STATE_TMP/server.json" "$ROOT_DIR/server/seven-server.sh" status --json &
pid_server=$!
json_to_file "$STATE_TMP/server_plan.json" "$ROOT_DIR/server/seven-server.sh" plan --json &
pid_server_plan=$!
json_to_file "$STATE_TMP/readiness.json" "$ROOT_DIR/scripts/readiness.sh" --json &
pid_readiness=$!
json_to_file "$STATE_TMP/packages.json" "$ROOT_DIR/bin/sevenpkg" status --json &
pid_packages=$!
json_to_file "$STATE_TMP/manifest.json" "$ROOT_DIR/scripts/manifest.sh" summary-json &
pid_manifest=$!
json_to_file "$STATE_TMP/ecosystem.json" "$ROOT_DIR/scripts/ecosystem.sh" json &
pid_ecosystem=$!
json_to_file "$STATE_TMP/experience.json" "$ROOT_DIR/scripts/experience.sh" --json &
pid_experience=$!
json_to_file "$STATE_TMP/control.json" "$ROOT_DIR/scripts/control-plane.sh" --json &
pid_control=$!
json_to_file "$STATE_TMP/events.json" "$ROOT_DIR/scripts/events.sh" summary-json &
pid_events=$!
json_to_file "$STATE_TMP/actions.json" "$ROOT_DIR/scripts/actions.sh" --json &
pid_actions=$!

wait "$pid_status" "$pid_profiles" "$pid_profile_gaps" "$pid_profile_plan" "$pid_active_profile" "$pid_windows" "$pid_shield" "$pid_shield_plan" \
  "$pid_server" "$pid_server_plan" "$pid_readiness" "$pid_packages" "$pid_manifest" "$pid_ecosystem" \
  "$pid_experience" "$pid_control" "$pid_events" "$pid_actions" || true

printf '{'
printf '"schema":"sevenos.state.v1",'
printf '"generated_at":%s,' "$(date -u +%Y-%m-%dT%H:%M:%SZ | json_string)"
printf '"root":%s,' "$(printf '%s' "$ROOT_DIR" | json_string)"
printf '"status":'
cat "$STATE_TMP/status.json"
printf ','
printf '"profiles":'
cat "$STATE_TMP/profiles.json"
printf ','
printf '"profile_gaps":'
cat "$STATE_TMP/profile_gaps.json"
printf ','
printf '"profile_plan":'
cat "$STATE_TMP/profile_plan.json"
printf ','
printf '"active_profile":'
cat "$STATE_TMP/active_profile.json"
printf ','
printf '"windows":'
cat "$STATE_TMP/windows.json"
printf ','
printf '"shield":'
cat "$STATE_TMP/shield.json"
printf ','
printf '"shield_plan":'
cat "$STATE_TMP/shield_plan.json"
printf ','
printf '"server":'
cat "$STATE_TMP/server.json"
printf ','
printf '"server_plan":'
cat "$STATE_TMP/server_plan.json"
printf ','
printf '"readiness":'
cat "$STATE_TMP/readiness.json"
printf ','
printf '"packages":'
cat "$STATE_TMP/packages.json"
printf ','
printf '"manifest":'
cat "$STATE_TMP/manifest.json"
printf ','
printf '"ecosystem":'
cat "$STATE_TMP/ecosystem.json"
printf ','
printf '"experience":'
cat "$STATE_TMP/experience.json"
printf ','
printf '"control":'
cat "$STATE_TMP/control.json"
printf ','
printf '"events":'
cat "$STATE_TMP/events.json"
printf ','
printf '"actions":'
cat "$STATE_TMP/actions.json"
printf ','
printf '"native_hub":{'
if [[ -x "$ROOT_DIR/bin/seven-hub-native" ]]; then
  printf '"state":"OK","command":"seven hub-native open"'
else
  printf '"state":"MISS","command":"./install.sh hub"'
fi
printf '}'
printf '}\n'
