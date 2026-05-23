#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-check}"
JSON_OUTPUT=0

if [[ "${2:-}" == "--json" || "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=1
fi

PROFILES=(equinox baobab forge shield studio windows pulse)
SHELL_RC="$ROOT_DIR/branding/shell/terminal-bashrc"
TMP_ROOT="${XDG_RUNTIME_DIR:-/tmp}/sevenos-terminal-guard"

run_profile_check() {
  local profile="$1"
  local home="$TMP_ROOT/$profile/home"
  local config="$home/.config/sevenos"
  local shims="$home/.local/share/sevenos/profile-shims"
  local output status

  rm -rf "$TMP_ROOT/$profile"
  mkdir -p "$config" "$shims"
  cat >"$config/profile.env" <<EOF
SEVENOS_ACTIVE_PROFILE="$profile"
SEVENOS_TERMINAL_MODE="$profile"
EOF
  cat >"$config/profile-isolation.env" <<EOF
SEVENOS_ISOLATION_PRIMARY="$profile"
SEVENOS_ISOLATION_CAPABILITIES=""
SEVENOS_PROFILE_SHIMS="$shims"
EOF
  cat >"$shims/git" <<'EOF'
#!/usr/bin/env bash
printf '[SevenOS] git belongs to forge, but the active runtime is windows.\n' >&2
exit 126
EOF
  chmod +x "$shims/git"

  output="$(
    HOME="$home" \
    SEVENOS_ROOT="$ROOT_DIR" \
    SEVENOS_TERMINAL_MODE="$profile" \
    SEVENOS_PROFILE_SHIMS="$shims" \
    PATH="$shims:$PATH" \
    timeout 6s script -q /dev/null -c \
      "printf 'echo seven-terminal-guard-$profile\nexit\n' | bash --rcfile '$SHELL_RC' -i" \
    2>&1 || true
  )"
  if grep -q "seven-terminal-guard-$profile" <<<"$output" &&
     ! grep -q "belongs to forge" <<<"$output"; then
    status="OK"
  else
    status="MISS"
  fi
  printf '%s\t%s\t%s\n' "$profile" "$status" "$(printf '%s' "$output" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g' | cut -c1-220)"
}

check_json() {
  local rows
  rows="$(for profile in "${PROFILES[@]}"; do run_profile_check "$profile"; done)"
  TERMINAL_GUARD_ROWS="$rows" python - <<'PY'
import json
import os

items = []
for raw in os.environ.get("TERMINAL_GUARD_ROWS", "").splitlines():
    if not raw.strip():
        continue
    profile, state, sample = (raw.split("\t", 2) + [""])[:3]
    items.append({"profile": profile, "state": state, "sample": sample})
print(json.dumps({
    "schema": "sevenos.terminal-guard.v1",
    "ready": all(item["state"] == "OK" for item in items),
    "profiles": items,
}, indent=2))
PY
}

check_human() {
  local failed=0 profile state sample
  printf 'SevenOS Terminal Guard\n\n'
  while IFS=$'\t' read -r profile state sample; do
    printf '  %-8s %s\n' "$profile" "$state"
    [[ "$state" == "OK" ]] || failed=1
  done < <(for profile in "${PROFILES[@]}"; do run_profile_check "$profile"; done)
  return "$failed"
}

case "$ACTION" in
  check|status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      check_json
    else
      check_human
    fi
    ;;
  --json)
    check_json
    ;;
  -h|--help|help)
    printf 'Usage: scripts/terminal-guard.sh [check] [--json]\n'
    ;;
  *)
    log_error "Unknown terminal guard action: $ACTION"
    exit 2
    ;;
esac
