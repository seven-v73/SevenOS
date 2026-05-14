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
  if command_output="$(SEVENOS_DRY_RUN=0 "$@" 2>/dev/null)" && [[ -n "$command_output" ]]; then
    printf '%s' "$command_output"
  else
    printf 'null'
  fi
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

printf '{'
printf '"schema":"sevenos.state.v1",'
printf '"generated_at":%s,' "$(date -u +%Y-%m-%dT%H:%M:%SZ | json_string)"
printf '"root":%s,' "$(printf '%s' "$ROOT_DIR" | json_string)"
printf '"status":'
json_or_null "$ROOT_DIR/bin/seven" status --json
printf ','
printf '"profiles":'
json_or_null "$ROOT_DIR/bin/seven" profile status --json
printf ','
printf '"active_profile":'
json_or_null "$ROOT_DIR/bin/seven" profile current --json
printf ','
printf '"windows":'
json_or_null "$ROOT_DIR/bin/seven-windows-assistant" status --json
printf ','
printf '"readiness":'
json_or_null "$ROOT_DIR/scripts/readiness.sh" --json
printf ','
printf '"packages":'
json_or_null "$ROOT_DIR/bin/sevenpkg" status --json
printf ','
printf '"manifest":'
json_or_null "$ROOT_DIR/scripts/manifest.sh" summary-json
printf ','
printf '"ecosystem":'
json_or_null "$ROOT_DIR/scripts/ecosystem.sh" json
printf ','
printf '"experience":'
json_or_null "$ROOT_DIR/scripts/experience.sh" --json
printf ','
printf '"actions":'
json_or_null "$ROOT_DIR/scripts/actions.sh" --json
printf ','
printf '"native_hub":{'
if [[ -x "$ROOT_DIR/bin/seven-hub-native" ]]; then
  printf '"state":"OK","command":"seven hub-native open"'
else
  printf '"state":"MISS","command":"./install.sh hub"'
fi
printf '}'
printf '}\n'
