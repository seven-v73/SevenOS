#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
shift || true
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
    --yes|-y) export SEVENOS_YES=1 ;;
    -h|--help|help) ACTION="help" ;;
    *) ;;
  esac
done

AUR_MANIFEST="$ROOT_DIR/scripts/packages-shell-ags-aur.txt"
RUNTIME_PACKAGE="aylurs-gtk-shell"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/shell"
REPORT_FILE="$STATE_DIR/ags-runtime-report.json"

helper_state() {
  if command -v paru >/dev/null 2>&1; then
    printf 'paru'
  elif command -v yay >/dev/null 2>&1; then
    printf 'yay'
  else
    printf ''
  fi
}

runtime_state() {
  command -v ags >/dev/null 2>&1 && printf OK || printf MISS
}

package_state() {
  pacman -Q "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

status_json() {
  local helper runtime package auth_backend
  helper="$(helper_state)"
  runtime="$(runtime_state)"
  package="$(package_state "$RUNTIME_PACKAGE")"
  auth_backend="$(privileged_backend)"
  HELPER="$helper" RUNTIME="$runtime" PACKAGE="$package" AUTH_BACKEND="$auth_backend" AUR_MANIFEST="$AUR_MANIFEST" REPORT_FILE="$REPORT_FILE" python - <<'PY'
import json
import os
from pathlib import Path

helper = os.environ["HELPER"]
runtime = os.environ["RUNTIME"]
package = os.environ["PACKAGE"]
auth_backend = os.environ["AUTH_BACKEND"]
ready = runtime == "OK"
state = "READY" if ready else "AUR_READY" if helper else "NEEDS_AUR_HELPER"
report = Path(os.environ["REPORT_FILE"])
next_steps = []
if not helper:
    next_steps.append({
        "command": "./install.sh aur-helpers --yes",
        "reason": "Install yay/paru before installing the AGS runtime from AUR.",
    })
if not ready:
    next_steps.append({
        "command": "./install.sh shell-ags-runtime --yes",
        "reason": "Install Aylur's Gtk Shell runtime after reviewing the AUR route.",
    })

print(json.dumps({
    "schema": "sevenos.shell-ags-runtime.v1",
    "state": state,
    "ready": ready,
    "runtime_command": "ags",
    "aur_package": "aylurs-gtk-shell",
    "wrong_package_warning": "The AUR package named ags is Adventure Game Studio; Seven Shell uses aylurs-gtk-shell.",
    "helper": helper or "",
    "admin_prompt": auth_backend or "",
    "install_mode": "graphical-admin-prompt" if auth_backend == "pkexec" else "sudo" if auth_backend == "sudo" else "missing-admin-prompt",
    "report": str(report),
    "report_available": report.exists(),
    "safe_install_command": "./install.sh shell-ags-runtime --yes",
    "terminal_install_command": "seven-terminal forge -- bash -lc './install.sh shell-ags-runtime --yes; read -r'",
    "readiness": "native-runtime-ready" if ready else "installable-with-aur-helper" if helper else "needs-aur-helper",
    "checks": [
        {"key": "ags-command", "state": runtime},
        {"key": "aylurs-gtk-shell", "state": package},
        {"key": "aur-helper", "state": "OK" if helper else "MISS"},
        {"key": "admin-prompt", "state": "OK" if auth_backend else "MISS"},
        {"key": "wrong-ags-package-guard", "state": "OK"},
    ],
    "manifest": os.environ["AUR_MANIFEST"],
    "next": next_steps,
}, indent=2))
PY
}

status_human() {
  STATUS_JSON="$(status_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["STATUS_JSON"])
print("Seven Shell AGS Runtime")
print("=======================")
print(f"State:   {data['state']}")
print(f"Helper:  {data.get('helper') or 'missing'}")
print(f"Package: {data['aur_package']}")
print(f"Command: {data['runtime_command']} ({'ready' if data['ready'] else 'missing'})")
print()
print(data["wrong_package_warning"])
if data.get("next"):
    print()
    print("Next:")
    for item in data["next"]:
        print(f"  {item['command']}")
        print(f"    {item['reason']}")
PY
}

write_report() {
  local status="$1"
  local message="$2"
  mkdir -p "$STATE_DIR"
  SHELL_AGS_STATUS="$status" SHELL_AGS_MESSAGE="$message" SHELL_AGS_JSON="$(status_json)" SHELL_AGS_REPORT="$REPORT_FILE" python - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

state = json.loads(os.environ.get("SHELL_AGS_JSON", "{}") or "{}")
report = {
    "schema": "sevenos.shell-ags-runtime-report.v1",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "status": os.environ.get("SHELL_AGS_STATUS", "unknown"),
    "message": os.environ.get("SHELL_AGS_MESSAGE", ""),
    "state": state.get("state", "unknown"),
    "ready": state.get("ready", False),
    "helper": state.get("helper", ""),
    "aur_package": state.get("aur_package", "aylurs-gtk-shell"),
    "wrong_package_warning": state.get("wrong_package_warning", ""),
    "next": state.get("next", []),
    "checks": state.get("checks", []),
}
target = Path(os.environ["SHELL_AGS_REPORT"])
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(target)
PY
}

notify_shell_runtime() {
  local message="$1"
  if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1; then
    notify-send "Seven Shell" "$message" >/dev/null 2>&1 || true
  fi
}

open_install_terminal() {
  local command="./install.sh shell-ags-runtime --yes"
  if is_dry_run; then
    printf 'seven-terminal forge -- bash -lc %q\n' "$command; read -r"
    return 0
  fi
  if command -v seven-terminal >/dev/null 2>&1; then
    setsid -f seven-terminal forge -- bash -lc "cd '$ROOT_DIR' && $command; printf '\nPress Enter to close...'; read -r" >/dev/null 2>&1 || true
  elif command -v kitty >/dev/null 2>&1; then
    setsid -f kitty --title "Seven Shell AGS Runtime" bash -lc "cd '$ROOT_DIR' && $command; printf '\nPress Enter to close...'; read -r" >/dev/null 2>&1 || true
  else
    log_error "No SevenOS terminal surface available."
    return 1
  fi
}

install_runtime() {
  local helper
  helper="$(helper_state)"

  install_package_file "$ROOT_DIR/scripts/packages-shell-ags.txt"

  if [[ -z "$helper" ]]; then
    log_error "No AUR helper found. Run: ./install.sh aur-helpers --yes"
    write_report "blocked" "No AUR helper was found. Install yay or paru first." >/dev/null || true
    return 1
  fi
  if [[ ! -f "$AUR_MANIFEST" ]]; then
    log_error "AUR package manifest not found: $AUR_MANIFEST"
    write_report "blocked" "AGS AUR manifest is missing from the SevenOS tree." >/dev/null || true
    return 1
  fi

  log_warn "Seven Shell AGS runtime uses AUR package: $RUNTIME_PACKAGE"
  log_warn "Do not install package 'ags'; that package is Adventure Game Studio."
  notify_shell_runtime "Installing Aylur's Gtk Shell runtime."
  if install_aur_package_file "$AUR_MANIFEST"; then
    if is_dry_run; then
      write_report "dry-run" "AGS runtime install plan completed without changing packages." >/dev/null || true
      notify_shell_runtime "AGS runtime dry-run completed."
    else
      write_report "success" "AGS runtime install route completed." >/dev/null || true
      notify_shell_runtime "AGS runtime route completed."
    fi
  else
    write_report "failed" "AGS runtime install route failed. Check AUR helper, sudo and package build logs." >/dev/null || true
    notify_shell_runtime "AGS runtime install failed. Open Help for recovery steps."
    return 1
  fi
  status_human
}

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" == "1" ]]; then
      status_json
    else
      status_human
    fi
    ;;
  install)
    install_runtime
    ;;
  plan)
    status_json
    ;;
  report)
    if [[ -s "$REPORT_FILE" ]]; then
      cat "$REPORT_FILE"
    else
      write_report "status" "No previous AGS runtime install attempt was recorded." >/dev/null
      cat "$REPORT_FILE"
    fi
    ;;
  open|gui)
    open_install_terminal
    ;;
  --json|json)
    status_json
    ;;
  -h|--help|help)
    status_human
    ;;
  *)
    log_error "Unknown AGS runtime action: $ACTION"
    status_human >&2
    exit 1
    ;;
esac
