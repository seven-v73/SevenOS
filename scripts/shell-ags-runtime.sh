#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
shift || true

AUR_MANIFEST="$ROOT_DIR/scripts/packages-shell-ags-aur.txt"
RUNTIME_PACKAGE="aylurs-gtk-shell"

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
  HELPER="$helper" RUNTIME="$runtime" PACKAGE="$package" AUTH_BACKEND="$auth_backend" AUR_MANIFEST="$AUR_MANIFEST" python - <<'PY'
import json
import os

helper = os.environ["HELPER"]
runtime = os.environ["RUNTIME"]
package = os.environ["PACKAGE"]
auth_backend = os.environ["AUTH_BACKEND"]
ready = runtime == "OK"
state = "READY" if ready else "AUR_READY" if helper else "NEEDS_AUR_HELPER"
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
    "checks": [
        {"key": "ags-command", "state": runtime},
        {"key": "aylurs-gtk-shell", "state": package},
        {"key": "aur-helper", "state": "OK" if helper else "MISS"},
        {"key": "admin-prompt", "state": "OK" if auth_backend else "MISS"},
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

install_runtime() {
  local helper
  helper="$(helper_state)"

  install_package_file "$ROOT_DIR/scripts/packages-shell-ags.txt"

  if [[ -z "$helper" ]]; then
    log_error "No AUR helper found. Run: ./install.sh aur-helpers --yes"
    return 1
  fi

  log_warn "Seven Shell AGS runtime uses AUR package: $RUNTIME_PACKAGE"
  log_warn "Do not install package 'ags'; that package is Adventure Game Studio."
  install_aur_package_file "$AUR_MANIFEST"
  status_human
}

case "$ACTION" in
  status)
    if [[ "${1:-}" == "--json" ]]; then
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
