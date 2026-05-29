#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET="${1:-}"
shift || true

if [[ -z "$TARGET" ]]; then
  echo "[SevenOS] Missing target mini OS." >&2
  exit 2
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/profile-switch"
mkdir -p "$STATE_DIR"
WATCH_FILE="$STATE_DIR/${TARGET}.json"

active_profile() {
  local file="$CONFIG_DIR/profile.env"
  if [[ -f "$file" ]]; then
    # shellcheck disable=SC1090
    source "$file"
  fi
  printf '%s\n' "${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_PROFILE:-equinox}}"
}

write_watch() {
  local status="$1"
  local step="$2"
  local message="$3"
  python - "$WATCH_FILE" "$status" "$step" "$message" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.write_text(json.dumps({
    "schema": "sevenos.profile-switch-watch.v1",
    "status": sys.argv[2],
    "step": sys.argv[3],
    "message": sys.argv[4],
}, ensure_ascii=False), encoding="utf-8")
PY
}

SOURCE="$(active_profile)"
write_watch "running" "prepare" "SevenOS prépare le passage vers $TARGET."

if [[ -x "$ROOT_DIR/bin/seven-passage-overlay" ]] && [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  "$ROOT_DIR/bin/seven-passage-overlay" --from "$SOURCE" --to "$TARGET" --watch "$WATCH_FILE" --duration 1200 --max-duration 14000 >/dev/null 2>&1 &
  OVERLAY_PID=$!
else
  OVERLAY_PID=""
fi

write_watch "running" "activate" "Application du mini OS $TARGET."
set +e
"$ROOT_DIR/profiles/profile-manager.sh" activate "$TARGET" "$@"
code=$?
set -e

if [[ "$code" -eq 0 ]]; then
  write_watch "running" "refresh" "Rafraîchissement des surfaces SevenOS."
  if command -v seven-waybar >/dev/null 2>&1; then
    seven-waybar repair >/dev/null 2>&1 || true
  fi
  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
  write_watch "complete" "ready" "Mini OS $TARGET prêt."
else
  write_watch "failed" "error" "Le passage vers $TARGET a échoué."
fi

if [[ -n "${OVERLAY_PID:-}" ]]; then
  wait "$OVERLAY_PID" 2>/dev/null || true
fi

exit "$code"
