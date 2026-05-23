#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

usage() {
  cat <<'EOF'
SevenOS Shield Wrappers

Usage:
  seven shield wrappers [--json]
  seven shield wrappers install

Creates compatibility launchers for cyber GUI tools that can be awkward on
Wayland/Hyprland: BurpSuite, Autopsy, Ghidra, Wireshark, BloodHound and ZAP.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|wrappers) ACTION="status" ;;
    install) ACTION="install" ;;
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown wrappers option: $1"; usage; exit 1 ;;
  esac
  shift
done

wrapper_specs_json() {
  python - <<'PY'
import json
print(json.dumps({
    "schema": "sevenos.shield-wrappers.v1",
    "wrappers": [
        {"name": "seven-burpsuite", "tool": "burpsuite", "profile": "java-xwayland", "install": "seven shield optional-tools install --yes"},
        {"name": "seven-autopsy", "tool": "autopsy", "profile": "browser-service", "install": "seven shield optional-tools install --yes"},
        {"name": "seven-ghidra", "tool": "ghidra", "profile": "java-xwayland", "install": "seven profile install shield"},
        {"name": "seven-wireshark", "tool": "wireshark", "profile": "qt-stable", "install": "seven profile install shield"},
        {"name": "seven-zaproxy", "tool": "zaproxy", "profile": "java-xwayland", "install": "seven profile install shield"},
        {"name": "seven-bloodhound", "tool": "bloodhound", "profile": "electron-xwayland", "install": "seven shield toolchain install bloodhound --yes"},
    ],
}, indent=2))
PY
}

status_json() {
  BIN_DIR="$BIN_DIR" SPECS="$(wrapper_specs_json)" python - <<'PY'
import json
import os
import shutil
from pathlib import Path

specs = json.loads(os.environ["SPECS"])["wrappers"]
bin_dir = Path(os.environ["BIN_DIR"])
items = []
for item in specs:
    path = bin_dir / item["name"]
    tool_state = "OK" if shutil.which(item["tool"]) else "MISS"
    items.append({
        **item,
        "path": str(path),
        "state": "OK" if path.is_file() and os.access(path, os.X_OK) else "MISS",
        "tool_state": tool_state,
    })
print(json.dumps({
    "schema": "sevenos.shield-wrappers-status.v1",
    "state": "OK" if all(item["state"] == "OK" for item in items) else "PART",
    "bin_dir": str(bin_dir),
    "wrappers": items,
    "install_command": "seven shield wrappers install",
}, indent=2))
PY
}

write_wrapper() {
  local name="$1" tool="$2" profile="$3" install="$4" path="$BIN_DIR/$name"
  mkdir -p "$BIN_DIR"
  cat >"$path" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

tool="$tool"
install_hint="$install"

if ! command -v "\$tool" >/dev/null 2>&1; then
  printf 'SevenOS Shield: %s is not installed.\\n' "\$tool" >&2
  printf 'Install path: %s\\n' "\$install_hint" >&2
  exit 127
fi

export SEVENOS_SHIELD_TOOL="\$tool"
export SEVENOS_SHIELD_WRAPPER="$name"
export _JAVA_AWT_WM_NONREPARENTING=1
export JDK_JAVA_OPTIONS="\${JDK_JAVA_OPTIONS:-} -Dsun.java2d.uiScale=1"
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export ELECTRON_OZONE_PLATFORM_HINT=x11

case "$profile" in
  qt-stable)
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    ;;
  electron-xwayland)
    export OZONE_PLATFORM=x11
    ;;
  browser-service)
    ;;
esac

exec "\$tool" "\$@"
EOF
  chmod +x "$path"
}

install_wrappers() {
  wrapper_specs_json | python -c 'import json,sys; data=json.load(sys.stdin); [print("{name}\t{tool}\t{profile}\t{install}".format(**item)) for item in data["wrappers"]]' |
  while IFS=$'\t' read -r name tool profile install; do
    write_wrapper "$name" "$tool" "$profile" "$install"
  done
  "$ROOT_DIR/scripts/events.sh" log --source shield --type wrappers --state OK --message "Shield GUI compatibility wrappers installed" --command "seven shield wrappers install" >/dev/null || true
}

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      status_json
    else
      status_json | python -c 'import json,sys
data=json.load(sys.stdin)
print("SevenOS Shield Wrappers")
print("=======================")
print("State: {}".format(data.get("state")))
for item in data.get("wrappers", []):
    print("  {state:<4} {name:<18} tool={tool_state:<4} {tool}".format(**item))
print()
print("Install: {}".format(data.get("install_command")))'
    fi
    ;;
  install)
    install_wrappers
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_json; else log_success "Shield wrappers installed in $BIN_DIR"; fi
    ;;
esac
