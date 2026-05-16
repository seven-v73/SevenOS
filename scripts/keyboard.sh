#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$CONFIG_HOME/hypr/conf/keyboard.conf"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS keyboard controls

Usage:
  seven keyboard status [--json]
  seven keyboard apply

Default:
  layouts: us,fr
  switch:  Alt+Shift

The command only writes ~/.config/hypr/conf/keyboard.conf and reloads Hyprland
when a Hyprland session is active.
EOF
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'
}

status_json() {
  local state="MISS"
  local layouts="unknown"
  local options="unknown"
  [[ -s "$TARGET" ]] && state="OK"
  if [[ -r "$TARGET" ]]; then
    layouts="$(awk -F= '/kb_layout/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$TARGET")"
    options="$(awk -F= '/kb_options/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "$TARGET")"
    [[ -n "$layouts" ]] || layouts="unknown"
    [[ -n "$options" ]] || options="unknown"
  fi
  local ready=false
  if [[ ",$layouts," == *",us,"* && ",$layouts," == *",fr,"* && "$options" == *"grp:alt_shift_toggle"* ]]; then
    ready=true
  fi

  printf '{"schema":"sevenos.keyboard.v1","state":%s,"path":%s,"layouts":%s,"switch":%s,"ready":%s}\n' \
    "$(printf '%s' "$state" | json_string)" \
    "$(printf '%s' "$TARGET" | json_string)" \
    "$(printf '%s' "$layouts" | json_string)" \
    "$(printf '%s' "$options" | json_string)" \
    "$ready"
}

status_human() {
  local payload
  payload="$(status_json)"
  python - "$payload" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
print("SevenOS Keyboard")
print("================")
print(f"state:   {data.get('state')}")
print(f"layouts: {data.get('layouts')}")
print(f"switch:  {data.get('switch')}")
print(f"path:    {data.get('path')}")
print(f"ready:   {data.get('ready')}")
PY
}

apply_keyboard() {
  log_info "Applying SevenOS keyboard layout: us,fr with Alt+Shift toggle"
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$(dirname -- "$TARGET")"
    printf 'write %q\n' "$TARGET"
    printf 'hyprctl reload\n'
    return 0
  fi

  mkdir -p "$(dirname -- "$TARGET")"
  if [[ -e "$TARGET" ]]; then
    cp -a "$TARGET" "$(backup_path "$TARGET")"
  fi
  cat > "$TARGET" <<'EOF'
# SevenOS keyboard override
# English US + French with Alt+Shift layout toggle.

input {
    kb_layout = us,fr
    kb_options = grp:alt_shift_toggle
}
EOF

  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
  log_success "Keyboard layout applied. Use Alt+Shift to switch US/FR."
}

action="${1:-status}"
json_output=0
shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) json_output=1 ;;
  esac
done

case "$action" in
  status)
    [[ "$json_output" -eq 1 ]] && status_json || status_human
    ;;
  apply)
    apply_keyboard
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
