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

shadow_hits="$(grep -R -l "box-shadow" "$ROOT_DIR/hyprland" "$ROOT_DIR/hyprland-light" "$ROOT_DIR/seven-hub/gui/src" 2>/dev/null | grep -vFx "$ROOT_DIR/hyprland/waybar/style.css" || true)"
if [[ -n "$shadow_hits" ]]; then
  fail "UI must not use decorative box-shadow outside the SevenOS reference Waybar."
else
  ok "Desktop UI avoids decorative shadows outside the SevenOS reference Waybar"
fi

if grep -R "backdrop-filter" "$ROOT_DIR/hyprland" "$ROOT_DIR/hyprland-light" "$ROOT_DIR/seven-hub/gui/src" >/dev/null; then
  fail "UI must not use backdrop-filter in production Linux surfaces."
else
  ok "No backdrop-filter in production UI"
fi

if grep -R "font-weight:[[:space:]]*[6-9]00" \
  --exclude-dir=font \
  "$ROOT_DIR/hyprland" "$ROOT_DIR/hyprland-light" "$ROOT_DIR/seven-hub/gui/src" >/dev/null; then
  fail "UI font weight above 500 found."
else
  ok "UI font weights stay at 500 or below"
fi

if ! grep -q '@import "../../../identity/tokens.css";' "$ROOT_DIR/seven-hub/gui/src/styles.css"; then
  fail "Seven Hub must import identity/tokens.css."
else
  ok "Seven Hub imports design tokens"
fi

if grep -q -- '--font-display: "SF Pro Display"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--seven-blue: #2F7BFF' "$ROOT_DIR/identity/tokens-light.css" &&
   grep -q -- '--font-interface: "SF Pro Display"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--font-text: "SF Pro Text"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--font-mono: "SF Mono"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--font-brand: "SF Pro Rounded"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q 'SF Pro Display' "$ROOT_DIR/hyprland/gtk-3.0/settings.ini" &&
   grep -q 'SF Pro Display' "$ROOT_DIR/hyprland/gtk-4.0/settings.ini" &&
   grep -q 'font_family SF Mono' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'SF Pro Display' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'SF Pro Rounded' "$ROOT_DIR/hyprland/fontconfig/fonts.conf"; then
  ok "SevenOS typography follows SF Pro Display/Text, SF Mono and SF Pro Rounded roles"
else
  fail "SevenOS typography should follow SF Pro Display/Text, SF Mono and SF Pro Rounded roles"
fi

if [[ -s "$ROOT_DIR/identity/CHARTER_LIGHT.md" ]] &&
   [[ -s "$ROOT_DIR/identity/assets/wallpaper-sevenos-light.svg" ]] &&
   jq -e '."modules-center" == ["custom/spotlight","custom/ai"] and (."modules-right" | index("custom/bluetooth") and index("network") and index("clock"))' "$ROOT_DIR/hyprland-light/waybar/config.jsonc" >/dev/null &&
   grep -q '@define-color seven_blue #2F7BFF' "$ROOT_DIR/hyprland-light/waybar/style.css" &&
   grep -q 'gtk-application-prefer-dark-theme=false' "$ROOT_DIR/hyprland-light/gtk-3.0/settings.ini" &&
   grep -q 'include light.conf' "$ROOT_DIR/hyprland-light/kitty/kitty.conf" &&
   grep -q 'Clarity first' "$ROOT_DIR/identity/CHARTER_LIGHT.md"; then
  ok "SevenOS Light Mode exposes a clarity-first visual system"
else
  fail "SevenOS Light Mode should expose charter, tokens, Waybar, GTK and terminal surfaces"
fi

if jq -e '."modules-left" == ["custom/sevenos","custom/spotlight"] and ."modules-center" == ["custom/workspace-prev","hyprland/workspaces","custom/workspace-next"] and ."modules-right" == ["network","pulseaudio","battery","clock","custom/ai"] and .height == 48 and .spacing == 8 and ."margin-top" == 16 and ."margin-left" == 24 and ."margin-right" == 24 and ."gtk-layer-shell" == true and (."custom/sevenos".format | contains("SevenOS")) and (."custom/spotlight".format | contains("SUPER + SPACE")) and ."custom/workspace-prev"."on-click" == "hyprctl dispatch workspace e-1" and ."custom/workspace-next"."on-click" == "hyprctl dispatch workspace e+1" and ."custom/ai".format == "◉"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar uses the SevenOS public premium floating hierarchy"
else
  fail "Waybar should use SevenOS/search left, workspaces center and essential controls right."
fi

if grep -q '.modules-left,' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '.modules-center,' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '.modules-right' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'border-radius: 28px' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'min-width: 430px' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-workspace-prev' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'box-shadow:' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'border-radius: 999px' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-sevenos' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-spotlight' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-ai' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '@keyframes aiPulse' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#workspaces button.active' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'rgba(34, 38, 76, 0.38)' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'window#waybar' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '@define-color seven_violet' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'layerrule = blur, waybar' "$ROOT_DIR/hyprland/hyprland.conf"; then
  ok "Waybar uses premium liquid glass islands"
else
  fail "Waybar should use premium liquid glass islands"
fi

if [[ -x "$ROOT_DIR/bin/seven-dock" ]] &&
   [[ -x "$ROOT_DIR/bin/seven-dock-native" ]] &&
   grep -q 'dock-shell' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'GtkLayerShell' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'show_context_menu' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock-badge' "$ROOT_DIR/bin/seven-dock-native"; then
  ok "SevenOS exposes a native SevenOS dock surface"
else
  fail "SevenOS should expose a native dock with layer-shell support, badges and context menus"
fi

if grep -q 'class SevenShellPanel' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'border-radius: 28px' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'notification-card' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'SevenQuickSettingsNative' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'build_slider_card' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'icon-action' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'notification-card' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'mini-action' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'SevenNotificationCenterNative' "$ROOT_DIR/bin/seven-notification-center-native" &&
   grep -q 'notification-card' "$ROOT_DIR/bin/seven-notification-center-native" &&
   grep -q 'action-glyph' "$ROOT_DIR/bin/seven-notification-center-native" &&
   ! grep -q 'Notification Status' "$ROOT_DIR/bin/seven-waybar-notifications"; then
  ok "Native shell panel, quick settings and notification center follow SevenOS glass surface language"
else
  fail "Native shell panel, quick settings and notification center should follow SevenOS glass surface language"
fi

if grep -q 'SevenProfileCenterNative' "$ROOT_DIR/bin/seven-profile-center-native" &&
   grep -q 'SevenShieldCenterNative' "$ROOT_DIR/bin/seven-shield-center-native" &&
   grep -q 'SevenWaybarCenterNative' "$ROOT_DIR/bin/seven-waybar-center-native" &&
   grep -q 'profile-root' "$ROOT_DIR/bin/seven-profile-center-native" &&
   grep -q 'shield-root' "$ROOT_DIR/bin/seven-shield-center-native" &&
   grep -q 'center-root' "$ROOT_DIR/bin/seven-waybar-center-native" &&
   grep -q '󰐃' "$ROOT_DIR/bin/seven-waybar-profile" &&
   grep -q '󰒃' "$ROOT_DIR/bin/seven-waybar-security"; then
  ok "Waybar Profile, Shield and system modules expose compact native OS centers"
else
  fail "Waybar Profile, Shield and system modules should expose compact native OS centers"
fi

if [[ -x "$ROOT_DIR/bin/seven-settings" ]] &&
   "$ROOT_DIR/bin/seven-settings-native" --probe >/dev/null 2>&1 &&
   grep -q 'SevenSettingsNative' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings-shell' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'file_wallpaper_button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'import_fonts_button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven fonts apply-default' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven-wallpaper' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven keyboard apply' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven-shield-center-native' "$ROOT_DIR/bin/seven-settings-native"; then
  ok "SevenOS exposes a complete native Settings surface"
else
  fail "SevenOS Settings should expose wallpaper, display, security, profile and device controls"
fi

if [[ -s "$ROOT_DIR/identity/LIQUID_GLASS_OS.md" ]] &&
   grep -q 'Spotlight is the only global search surface' "$ROOT_DIR/identity/LIQUID_GLASS_OS.md" &&
   grep -q 'Dock is a workflow surface' "$ROOT_DIR/identity/LIQUID_GLASS_OS.md" &&
   grep -q 'No flat black-on-black utility surfaces' "$ROOT_DIR/identity/LIQUID_GLASS_OS.md"; then
  ok "SevenOS has an OS-level Liquid Glass direction"
else
  fail "SevenOS should document the OS-level Liquid Glass direction"
fi

if grep -q 'seven-hub-window' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-sidebar' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-nav-item' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-hero' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-metric-card' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-compact-grid' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-tile' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'render_dashboard_compact' "$ROOT_DIR/bin/seven-hub-native" &&
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

if [[ -x "$ROOT_DIR/bin/seven-settings" ]] &&
   [[ -s "$ROOT_DIR/hyprland/rofi/quick-settings.rasi" ]] &&
   [[ -x "$ROOT_DIR/bin/seven-waybar-notifications" ]]; then
  ok "Settings and Notifications have dedicated shell surfaces"
else
  fail "Settings or Notifications dedicated shell surface missing"
fi

if grep -q 'bg: rgba(18, 19, 26, 0.86)' "$ROOT_DIR/hyprland/rofi/hub.rasi" &&
   grep -q 'border-radius: 22px' "$ROOT_DIR/hyprland/rofi/hub.rasi" &&
   grep -q 'min-height: 58px' "$ROOT_DIR/hyprland/rofi/hub.rasi"; then
  ok "Seven Hub fallback uses readable futuristic glass navigation"
else
  fail "Seven Hub fallback should use readable futuristic glass navigation"
fi

if grep -q 'width: 52%' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'border-radius: 30px' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'border-radius: 999px' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'Search apps, files, windows, clipboard, actions' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'element-icon' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'min-height: 54px' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'SevenSpotlightNative' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'category-button' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'Search SevenOS' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'filter_items(items, query, current_mode)' "$ROOT_DIR/bin/seven-spotlight-native" &&
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

if grep -q -- '--seven-blue: #4DA3FF' "$ROOT_DIR/identity/tokens.css" &&
   grep -q 'gtk-application-prefer-dark-theme=true' "$ROOT_DIR/hyprland/gtk-3.0/settings.ini" &&
   grep -q 'gtk-decoration-layout=close,minimize,maximize:' "$ROOT_DIR/hyprland/gtk-4.0/settings.ini" &&
   grep -q 'window.nautilus-window headerbar' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" &&
   grep -q 'SevenFilesNative' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-sidebar' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'include classic.conf' "$ROOT_DIR/hyprland/kitty/kitty.conf" &&
   grep -q 'background #09090B' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'background #09090B' "$ROOT_DIR/hyprland/kitty/dark.conf"; then
  ok "SevenOS default UI is dark, transparent and cinematic with glass accents"
else
  fail "SevenOS default UI should ship dark transparent cinematic glass"
fi

if grep -q 'kente-band' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'Beyond the Desktop' "$ROOT_DIR/identity/CHARTER.md" &&
   grep -q 'gradient-primary' "$ROOT_DIR/seven-hub/gui/src/styles.css"; then
  ok "Seven Hub uses SevenOS v2 structural glow details"
else
  fail "Seven Hub should expose SevenOS v2 structural glow details"
fi

if [[ "$failures" -gt 0 ]]; then
  log_error "Design checks failed: $failures"
  exit 1
fi

log_success "Design coherence checks passed."
