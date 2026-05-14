#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

failures=0

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}

ok() {
  printf '[OK] %s\n' "$*"
}

log_info "Running SevenOS design coherence checks..."

if grep -R "box-shadow" "$ROOT_DIR/hyprland" "$ROOT_DIR/seven-hub/gui/src" >/dev/null; then
  fail "UI must not use decorative box-shadow."
else
  ok "No decorative box-shadow in desktop UI"
fi

if grep -R "backdrop-filter" "$ROOT_DIR/hyprland" "$ROOT_DIR/seven-hub/gui/src" >/dev/null; then
  fail "UI must not use backdrop-filter in production Linux surfaces."
else
  ok "No backdrop-filter in production UI"
fi

if grep -R "font-weight:[[:space:]]*[6-9]00" "$ROOT_DIR/hyprland" "$ROOT_DIR/seven-hub/gui/src" >/dev/null; then
  fail "UI font weight above 500 found."
else
  ok "UI font weights stay at 500 or below"
fi

if ! grep -q '@import "../../../identity/tokens.css";' "$ROOT_DIR/seven-hub/gui/src/styles.css"; then
  fail "Seven Hub must import identity/tokens.css."
else
  ok "Seven Hub imports design tokens"
fi

if grep -q 'modules-left.*custom/apps' "$ROOT_DIR/hyprland/waybar/config.jsonc"; then
  fail "Waybar left side should stay reserved for system identity and workspaces."
else
  ok "Waybar has a clearer left/center/right hierarchy"
fi

if grep -q 'custom/quick' "$ROOT_DIR/hyprland/waybar/config.jsonc" &&
   [[ -s "$ROOT_DIR/hyprland/rofi/quick-settings.rasi" ]]; then
  ok "Quick Settings has a dedicated visual surface"
else
  fail "Quick Settings dedicated Rofi surface missing"
fi

if grep -q 'content: "SevenOS Apps"' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'background-color: @surface-3' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   ! grep -Eq '#[0-9a-fA-F]{8}\b' "$ROOT_DIR/hyprland/rofi/apps.rasi"; then
  ok "Apps overview has SevenOS header, tokenized surfaces and raised tiles"
else
  fail "Apps overview still lacks SevenOS signature depth or tokenized surfaces"
fi

if grep -q -- '--ebene: #f7f1e5' "$ROOT_DIR/identity/tokens.css" &&
   grep -q 'gtk-application-prefer-dark-theme=false' "$ROOT_DIR/hyprland/gtk-3.0/settings.ini" &&
   grep -q 'background #f7f1e5' "$ROOT_DIR/hyprland/kitty/kitty.conf"; then
  ok "SevenOS default UI is light liquid glass, not dark"
else
  fail "SevenOS default UI should not ship a dark theme"
fi

if grep -q 'kente-band' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'section-eyebrow' "$ROOT_DIR/seven-hub/gui/src/styles.css"; then
  ok "Seven Hub uses African-first structural details"
else
  fail "Seven Hub should expose structural African-first details"
fi

if [[ "$failures" -gt 0 ]]; then
  log_error "Design checks failed: $failures"
  exit 1
fi

log_success "Design coherence checks passed."
