#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0
YES=0

OFFICIAL_FILE="$ROOT_DIR/scripts/packages-cybersecurity-optional.txt"
AUR_FILE="$ROOT_DIR/scripts/packages-cybersecurity-aur.txt"

usage() {
  cat <<'EOF'
SevenOS Shield Optional Tools

Usage:
  seven shield optional-tools [--json]
  seven shield optional-tools install [--yes]

Optional tools keep Shield stable by default while making advanced cyber
workflows easy to enable intentionally. Official packages are installed through
pacman; AUR packages are delegated to SevenStore/yay/paru with user review.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|optional-tools) ACTION="status" ;;
    install) ACTION="install" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown optional-tools option: $1"; usage; exit 1 ;;
  esac
  shift
done

read_packages() {
  local file="$1"
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file"
}

package_state() {
  local package="$1"
  package_is_satisfied "$package" && printf OK || printf MISS
}

aur_state() {
  local package="$1"
  if command -v "$package" >/dev/null 2>&1 || pacman -Qq "$package" >/dev/null 2>&1; then
    printf OK
  else
    printf MISS
  fi
}

status_json() {
  OFFICIAL_FILE="$OFFICIAL_FILE" AUR_FILE="$AUR_FILE" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

official_file = Path(os.environ["OFFICIAL_FILE"])
aur_file = Path(os.environ["AUR_FILE"])

def packages(path):
    if not path.is_file():
        return []
    rows = []
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            rows.append(line)
    return rows

def pacman_ok(package):
    return package in installed

def command_ok(package):
    return package in commands

try:
    installed = set(subprocess.check_output(["pacman", "-Qq"], text=True).splitlines())
except Exception:
    installed = set()

commands = set()
for folder in os.environ.get("PATH", "").split(os.pathsep):
    path = Path(folder)
    if path.is_dir():
        try:
            commands.update(item.name for item in path.iterdir() if item.is_file() and os.access(item, os.X_OK))
        except OSError:
            pass

official = [{"name": item, "source": "pacman", "state": "OK" if pacman_ok(item) else "MISS"} for item in packages(official_file)]
aur = [{"name": item, "source": "aur", "state": "OK" if pacman_ok(item) or command_ok(item) else "MISS"} for item in packages(aur_file)]
missing = [item for item in official + aur if item["state"] != "OK"]
print(json.dumps({
    "schema": "sevenos.shield-optional-tools.v1",
    "state": "OK" if not missing else "OPTIONAL",
    "official": official,
    "aur": aur,
    "missing": missing,
    "install_command": "seven shield optional-tools install --yes",
    "policy": "not installed automatically; user-reviewed advanced tooling",
}, indent=2))
PY
}

status_human() {
  status_json | python -c 'import json,sys
data=json.load(sys.stdin)
print("SevenOS Shield Optional Tools")
print("=============================")
print("State: {}".format(data.get("state")))
for section in ("official","aur"):
    print()
    print(section.upper())
    for item in data.get(section, []):
        print("  {state:<4} {name:<18} {source}".format(**item))
print()
print("Install intentionally: {}".format(data.get("install_command")))'
}

install_tools() {
  if [[ "$YES" -ne 1 && "${SEVENOS_YES:-0}" != "1" ]]; then
    log_error "Optional Shield tools require explicit consent."
    log_info "Run: seven shield optional-tools install --yes"
    exit 1
  fi

  if [[ -s "$OFFICIAL_FILE" ]]; then
    install_package_file "$OFFICIAL_FILE"
  fi

  if [[ -s "$AUR_FILE" ]]; then
    while IFS= read -r package; do
      [[ -n "$package" ]] || continue
      if package_is_satisfied "$package" || command -v "$package" >/dev/null 2>&1; then
        continue
      fi
      "$ROOT_DIR/scripts/store.sh" install-app aur "$package"
    done < <(read_packages "$AUR_FILE")
  fi
}

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_json; else status_human; fi
    ;;
  install)
    install_tools
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_json; else status_human; fi
    ;;
esac
