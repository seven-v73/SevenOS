#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

GUI_DIR="$ROOT_DIR/seven-hub/gui"

usage() {
  cat <<'EOF'
Seven Hub GUI stack

Usage:
  seven-hub/gui-stack.sh [status|install|dev|build|doctor]

Actions:
  status   Show Tauri tooling state
  install  Install official Tauri foundation packages
  dev      Print the development command
  build    Print the build command
  doctor   Validate GUI scaffold
EOF
}

state() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 && printf OK || printf MISS
}

status() {
  printf 'Seven Hub GUI Stack\n'
  printf '===================\n'
  printf 'rustc:  %s\n' "$(state rustc)"
  printf 'cargo:  %s\n' "$(state cargo)"
  printf 'node:   %s\n' "$(state node)"
  printf 'npm:    %s\n' "$(state npm)"
  printf 'webkit: %s\n' "$(pkg-config --exists webkit2gtk-4.1 2>/dev/null && printf OK || printf MISS)"
}

install_stack() {
  install_package_file "$ROOT_DIR/scripts/packages-hub-gui.txt"
}

doctor() {
  local failures=0
  local path

  status
  printf '\nScaffold files:\n'
  for path in \
    "seven-hub/gui/README.md" \
    "seven-hub/gui/package.json" \
    "seven-hub/gui/package-lock.json" \
    "seven-hub/gui/vite.config.js" \
    "seven-hub/gui/src/index.html" \
    "seven-hub/gui/src/main.js" \
    "seven-hub/gui/src/styles.css" \
    "seven-hub/gui/src-tauri/Cargo.toml" \
    "seven-hub/gui/src-tauri/build.rs" \
    "seven-hub/gui/src-tauri/tauri.conf.json" \
    "seven-hub/gui/src-tauri/src/main.rs"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  if [[ "$failures" -gt 0 ]]; then
    log_error "Seven Hub GUI scaffold has $failures issue(s)."
    return 1
  fi

  log_success "Seven Hub GUI foundation is coherent."
}

action="${1:-status}"
case "$action" in
  status) status ;;
  install) install_stack ;;
  dev) printf 'cd %q && npm install && npm run tauri:dev\n' "$GUI_DIR" ;;
  build) printf 'cd %q && npm install && npm run tauri:build\n' "$GUI_DIR" ;;
  doctor) doctor ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown GUI stack action: $action"; usage; exit 1 ;;
esac
