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

if jq -e '."modules-left" == ["custom/sevenos","custom/apps","custom/files"] and ."modules-center" == ["hyprland/workspaces"] and (."modules-right" | index("custom/profile") and index("custom/security") and index("cpu") and index("memory") and index("custom/notifications") and index("clock")) and .spacing == 0' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar uses a macOS-like left/center/right liquid hierarchy"
else
  fail "Waybar should use SevenOS/app/files left, workspaces center, stateful system controls right."
fi

if grep -q 'border-radius: 15px' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'border-radius: 16px' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-profile.ok' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-security.miss' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'window#waybar' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'background: transparent' "$ROOT_DIR/hyprland/waybar/style.css"; then
  ok "Waybar uses liquid glass islands"
else
  fail "Waybar should use liquid glass islands"
fi

if grep -q 'class SevenShellPanel' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'border-radius: 28px' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'rgba(255, 255, 255, 0.72)' "$ROOT_DIR/bin/seven-shell-panel"; then
  ok "Native shell panel follows SevenOS Frost surface language"
else
  fail "Native shell panel should follow SevenOS Frost surface language"
fi

if grep -q 'seven-hub-window' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-sidebar' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-nav-item' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-hero' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-metric-card' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-card' "$ROOT_DIR/bin/seven-hub-native"; then
  ok "Seven Hub Native uses OS-grade glass navigation"
else
  fail "Seven Hub Native should use OS-grade glass navigation"
fi

if [[ -s "$ROOT_DIR/session/sevenos.desktop" ]] &&
   grep -q 'Name=SevenOS' "$ROOT_DIR/session/sevenos.desktop" &&
   [[ -s "$ROOT_DIR/systemd/user/sevenos-session.target" ]]; then
  ok "SevenOS exposes a named desktop session"
else
  fail "SevenOS should expose a named desktop session"
fi

if grep -q 'custom/quick' "$ROOT_DIR/hyprland/waybar/config.jsonc" &&
   grep -q 'custom/notifications' "$ROOT_DIR/hyprland/waybar/config.jsonc" &&
   [[ -s "$ROOT_DIR/hyprland/rofi/quick-settings.rasi" ]]; then
  ok "Quick Settings and Notifications have dedicated shell surfaces"
else
  fail "Quick Settings or Notifications dedicated shell surface missing"
fi

if grep -q 'bg: rgba(246, 251, 254, 0.86)' "$ROOT_DIR/hyprland/rofi/hub.rasi" &&
   grep -q 'border-radius: 22px' "$ROOT_DIR/hyprland/rofi/hub.rasi" &&
   grep -q 'min-height: 58px' "$ROOT_DIR/hyprland/rofi/hub.rasi"; then
  ok "Seven Hub fallback uses readable frosted navigation"
else
  fail "Seven Hub fallback should use readable frosted navigation"
fi

if grep -q 'width: 48%' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'border-radius: 28px' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'border-radius: 999px' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'Search SevenOS' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'element-icon' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'min-height: 52px' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q '@theme "sevenos.rasi"' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   ! grep -Eq 'placeholder: "Search|filename: "search"|inputbar' "$ROOT_DIR/hyprland/rofi/hub.rasi" &&
   ! grep -Eq 'placeholder: "Search|filename: "search"|inputbar' "$ROOT_DIR/hyprland/rofi/quick-settings.rasi" &&
   ! grep -Eq 'placeholder: "Search|filename: "search"' "$ROOT_DIR/hyprland/rofi/sevenos.rasi"; then
  ok "SevenOS Spotlight uses centered readable liquid command surface"
else
  fail "SevenOS Spotlight should use centered readable liquid command surface"
fi

if grep -Fq 'children: [ inputbar, listview ]' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'SevenLaunchpadNative' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'launchpad-tile' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'placeholder: "Search"' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'columns: 7' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'element-icon' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'size: 84px' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'spacing: 58px' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   ! grep -Eq '#[0-9a-fA-F]{8}\b' "$ROOT_DIR/hyprland/rofi/apps.rasi"; then
  ok "Apps overview has SevenOS header, tokenized surfaces and rounded glass tiles"
else
  fail "Apps overview still lacks SevenOS signature depth or tokenized surfaces"
fi

if grep -q -- '--ebene: #eef4f8' "$ROOT_DIR/identity/tokens.css" &&
   grep -q 'gtk-application-prefer-dark-theme=false' "$ROOT_DIR/hyprland/gtk-3.0/settings.ini" &&
   grep -q 'gtk-decoration-layout=close,minimize,maximize:' "$ROOT_DIR/hyprland/gtk-4.0/settings.ini" &&
   grep -q 'window.nautilus-window headerbar' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" &&
   grep -q 'include classic.conf' "$ROOT_DIR/hyprland/kitty/kitty.conf" &&
   grep -q 'background #fbfbfb' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'background #2d333d' "$ROOT_DIR/hyprland/kitty/dark.conf"; then
  ok "SevenOS default UI is transparent minimal with frosted glass accents"
else
  fail "SevenOS default UI should ship transparent minimal glass"
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
