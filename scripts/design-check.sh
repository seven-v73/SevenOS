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

shadow_hits="$(
  grep -R -l "box-shadow" "$ROOT_DIR/hyprland" "$ROOT_DIR/hyprland-light" "$ROOT_DIR/seven-hub/gui/src" 2>/dev/null |
    grep -vFx "$ROOT_DIR/hyprland/waybar/style.css" |
    grep -vFx "$ROOT_DIR/hyprland-light/waybar/style.css" || true
)"
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

if [[ -s "$ROOT_DIR/identity/DESIGN_ENGINE.md" ]] &&
   [[ -s "$ROOT_DIR/identity/design-engine.json" ]] &&
   [[ -s "$ROOT_DIR/identity/design-engine.css" ]] &&
   [[ -s "$ROOT_DIR/identity/PROFILE_THEMES.md" ]] &&
   [[ -s "$ROOT_DIR/profiles/catalog.json" ]] &&
   jq -e '.schema == "sevenos.design-engine.v1" and .modes."seven-mocha".palette.base == "#11111B" and .modes."seven-latte".palette.base == "#EFF1F5" and (.icon_strategy.rule | contains("Papirus")) and .profile_themes.contract == "identity/profile-themes.json" and .profile_themes.catalog == "profiles/catalog.json"' "$ROOT_DIR/identity/design-engine.json" >/dev/null &&
   jq -e '.schema == "sevenos.profile-themes.v1" and .profiles.equinox.short_label == "EQX" and .profiles.baobab.catppuccin_role == "green/yellow" and .profiles.shield.short_label == "SEC" and .profiles.pulse.short_label == "GAME"' "$ROOT_DIR/identity/profile-themes.json" >/dev/null &&
   jq -e '.schema == "sevenos.profiles.catalog.v1" and .default_profile == "equinox" and .profile_model.short_name == "LAPA" and .profiles.forge.mini_os == true and .profiles.windows.title == "Windows Bridge" and .profiles.baobab.layers.experience and .isolation_policy.activation and .core_package_files[0] == "scripts/packages-base.txt" and .runtime_optional_package_files[0] == "scripts/packages-runtime-optional.txt" and any(.profiles.baobab.anti_nuisance[]; . == "no dev toolchain") and .profiles.pulse.optional_package_files[0] == "scripts/packages-performance-optional.txt"' "$ROOT_DIR/profiles/catalog.json" >/dev/null &&
   grep -q -- '--cat-base: #11111B' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--cat-base: #EFF1F5' "$ROOT_DIR/identity/tokens-light.css" &&
   grep -q 'resolve_icon_theme' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'resolve_gtk_theme' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'resolve_cursor_theme' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'resolve_kvantum_theme' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'Catppuccin-Mocha' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'kvantum.kvconfig' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'catppuccin-gtk-theme-mocha' "$ROOT_DIR/scripts/packages-visual-aur.txt" &&
   grep -q 'catppuccin-cursors-mocha' "$ROOT_DIR/scripts/packages-visual-aur.txt" &&
   grep -q 'kvantum-theme-catppuccin-git' "$ROOT_DIR/scripts/packages-visual-aur.txt" &&
   grep -q 'seven identity visuals' "$ROOT_DIR/scripts/identity.sh" &&
   grep -q 'design_json' "$ROOT_DIR/scripts/identity.sh" &&
   jq -e '.schema == "sevenos.icons.v1" and ([.icons[].name] | index("seven-hub") and index("seven-files") and index("seven-reader") and index("seven-store") and index("seven-ai") and index("seven-settings") and index("seven-spotlight") and index("seven-baobab"))' "$ROOT_DIR/identity/icons/manifest.json" >/dev/null &&
   grep -q 'seven identity icons' "$ROOT_DIR/scripts/identity.sh" &&
   grep -q 'seven-hub.svg' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'Icon=seven-files' "$ROOT_DIR/seven-hub/seven-files.desktop" &&
   grep -q 'Icon=seven-settings' "$ROOT_DIR/seven-hub/seven-settings.desktop" &&
   grep -q 'Icon=seven-hub' "$ROOT_DIR/seven-hub/seven-hub-native.desktop" &&
   grep -q 'Icon=seven-spotlight' "$ROOT_DIR/seven-hub/seven-spotlight.desktop" &&
   grep -q 'Icon=seven-ai' "$ROOT_DIR/seven-hub/seven-ai.desktop" &&
   grep -q 'seven-baobab.svg' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'seven-spotlight.desktop' "$ROOT_DIR/scripts/apply-theme.sh"; then
  ok "Seven Design Engine exposes Catppuccin-inspired Mocha/Latte palettes with resilient icon resolution"
else
  fail "Seven Design Engine should expose Mocha/Latte palettes, optional Catppuccin icons and Papirus fallback"
fi

if [[ -s "$ROOT_DIR/identity/CHARTER_LIGHT.md" ]] &&
   [[ -s "$ROOT_DIR/identity/assets/wallpaper-sevenos-light.svg" ]] &&
   jq -e '."modules-left" == ["custom/sevenos","hyprland/window","custom/app-file","custom/app-edit","custom/app-view","custom/app-extra","custom/app-more","custom/app-tools","custom/app-window","custom/app-help"] and ."hyprland/window".format == "{class}" and ."hyprland/window"."max-length" == 18 and ."custom/app-file".exec == "seven-waybar-status app-menu-item file" and ."custom/app-file"."on-click" == "seven-waybar-action app-file" and ."custom/app-edit"."on-click" == "seven-waybar-action app-edit" and ."custom/app-view"."on-click" == "seven-waybar-action app-view" and ."custom/app-extra"."on-click" == "seven-waybar-action app-extra" and ."custom/app-more".exec == "seven-waybar-status app-menu-more" and ."custom/app-more"."on-click" == "seven-waybar-action app-menu" and ."custom/app-tools"."on-click" == "seven-waybar-action app-tools" and ."custom/app-window"."on-click" == "seven-waybar-action app-window" and ."custom/app-help"."on-click" == "seven-waybar-action app-help" and ."custom/sevenos".exec == "seven-waybar-status sevenos" and ."custom/sevenos"."return-type" == "json" and ."custom/sevenos"."on-click-right" == "seven-profile-center-native" and ."custom/sevenos"."on-click-middle" == "seven-spotlight field" and ."modules-center" == ["hyprland/workspaces"] and ."modules-right" == ["custom/profile","custom/mini-context","custom/experience","custom/media","custom/system-status","tray","custom/spotlight","clock","custom/control-center"] and .height == 28 and ."gtk-layer-shell" == true and ."custom/system-status".exec == "seven-waybar-status system-status" and ."custom/system-status"."return-type" == "json" and ."custom/spotlight".format == "󰍉" and (."custom/spotlight"."tooltip-format" | contains("Spotlight")) and ."custom/spotlight"."on-click" == "seven-spotlight field" and ."custom/wifi".exec == "seven-waybar-status wifi" and ."custom/bluetooth".exec == "seven-waybar-status bluetooth" and .tray."icon-size" == 14 and ."custom/control-center".exec == "seven-waybar-status control-center"' "$ROOT_DIR/hyprland-light/waybar/config.jsonc" >/dev/null &&
   grep -q '@define-color seven_blue #2F7BFF' "$ROOT_DIR/hyprland-light/waybar/style.css" &&
   grep -q 'window#waybar' "$ROOT_DIR/hyprland-light/waybar/style.css" &&
   grep -q '#custom-control-center' "$ROOT_DIR/hyprland-light/waybar/style.css" &&
   grep -q 'gtk-application-prefer-dark-theme=false' "$ROOT_DIR/hyprland-light/gtk-3.0/settings.ini" &&
   grep -q 'include light.conf' "$ROOT_DIR/hyprland-light/kitty/kitty.conf" &&
   grep -q 'Clarity first' "$ROOT_DIR/identity/CHARTER_LIGHT.md"; then
  ok "SevenOS Light Mode exposes a clarity-first visual system"
else
  fail "SevenOS Light Mode should expose charter, tokens, Waybar, GTK and terminal surfaces"
fi

if jq -e '."modules-left" == ["custom/sevenos","hyprland/window","custom/app-file","custom/app-edit","custom/app-view","custom/app-extra","custom/app-more","custom/app-tools","custom/app-window","custom/app-help"] and ."hyprland/window".format == "{class}" and ."hyprland/window"."max-length" == 18 and ."custom/app-file".exec == "seven-waybar-status app-menu-item file" and ."custom/app-file"."on-click" == "seven-waybar-action app-file" and ."custom/app-edit"."on-click" == "seven-waybar-action app-edit" and ."custom/app-view"."on-click" == "seven-waybar-action app-view" and ."custom/app-extra"."on-click" == "seven-waybar-action app-extra" and ."custom/app-more".exec == "seven-waybar-status app-menu-more" and ."custom/app-more"."on-click" == "seven-waybar-action app-menu" and ."custom/app-tools"."on-click" == "seven-waybar-action app-tools" and ."custom/app-window"."on-click" == "seven-waybar-action app-window" and ."custom/app-help"."on-click" == "seven-waybar-action app-help" and ."custom/sevenos".exec == "seven-waybar-status sevenos" and ."custom/sevenos"."return-type" == "json" and ."custom/sevenos"."on-click-right" == "seven-profile-center-native" and ."custom/sevenos"."on-click-middle" == "seven-spotlight field" and ."modules-center" == ["hyprland/workspaces"] and ."modules-right" == ["custom/profile","custom/mini-context","custom/experience","custom/media","custom/system-status","tray","custom/spotlight","clock","custom/control-center"] and .height == 28 and .spacing == 4 and ."margin-top" == 0 and ."margin-left" == 0 and ."margin-right" == 0 and ."gtk-layer-shell" == true and ."custom/system-status".exec == "seven-waybar-status system-status" and ."custom/system-status"."return-type" == "json" and ."custom/spotlight".format == "󰍉" and (."custom/spotlight"."tooltip-format" | contains("Spotlight")) and ."custom/spotlight"."on-click" == "seven-spotlight field" and ."hyprland/workspaces".format == "{icon}" and ."hyprland/workspaces"."format-icons"."1" == "1" and .tray."icon-size" == 14 and ."custom/control-center".exec == "seven-waybar-status control-center" and ."custom/control-center"."return-type" == "json"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar uses the SevenOS public premium floating hierarchy"
else
  fail "Waybar should use SevenOS/search left, workspaces center and essential controls right."
fi

if grep -q '.modules-left,' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '.modules-center,' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '.modules-right' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'border-radius: 0' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'border-bottom: 1px solid' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'adaptive-waybar-layout' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'seven-motion-system' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-profile.profile-equinox' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-profile.profile-baobab' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-profile.profile-shield' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#window' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-app-file' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-workspace-prev' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-wifi' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-bluetooth' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-recorder.recording' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#tray' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-vpn.hidden' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-system-status.hidden' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'box-shadow:' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'border-radius: 6px' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-sevenos' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-spotlight' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-experience' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-experience.recommended' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-control-center' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#workspaces button.active' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'rgba(18, 20, 34, 0.72)' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'window#waybar' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '@define-color seven_violet' "$ROOT_DIR/hyprland/waybar/style.css"; then
  ok "Waybar uses premium liquid glass islands"
else
  fail "Waybar should use premium liquid glass islands"
fi

if [[ -x "$ROOT_DIR/bin/seven-dock" ]] &&
   [[ -x "$ROOT_DIR/bin/seven-dock-native" ]] &&
   grep -q 'dock-shell' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'GtkLayerShell' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock_dimensions' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'PROFILE_PINNED' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock-instance-badge' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'setup_tile_dnd' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock-preview-row' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'spring_open_folder' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'animate_dock_opacity' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'launch-feedback' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'spring-armed' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'visible-on-all-workspaces-until-profile-change' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'show_context_menu' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock-badge' "$ROOT_DIR/bin/seven-dock-native"; then
  ok "SevenOS exposes a native SevenOS dock surface"
else
  fail "SevenOS should expose a native dock with layer-shell support, badges and context menus"
fi

if [[ -x "$ROOT_DIR/scripts/shell-experience.sh" ]] &&
   "$ROOT_DIR/scripts/shell-experience.sh" status --json | python -m json.tool >/dev/null &&
   grep -q 'sevenos.shell-experience.v1' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'seven-motion-system' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'launch_feedback' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'focus_memory' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'workspace_memory' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'warmup_experience' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'recent_events_json' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'recommendation_json' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'sevenos.shell-experience.recommendation.v1' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'sevenos-shell-experience.service' "$ROOT_DIR/systemd/user/sevenos-session.target" &&
   grep -q 'ExecStart=%h/.local/bin/seven experience warmup' "$ROOT_DIR/systemd/user/sevenos-shell-experience.service" &&
   grep -q 'warmup_shell_experience' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'def experience()' "$ROOT_DIR/bin/seven-waybar-status" &&
   grep -q 'Next:' "$ROOT_DIR/bin/seven-waybar-status" &&
   grep -q '"shell_experience"' "$ROOT_DIR/bin/seven-home-native" &&
   grep -q '"recommendation"' "$ROOT_DIR/bin/seven-home-native" &&
   grep -q 'Fluidifier' "$ROOT_DIR/bin/seven-home-native" &&
   grep -q 'experience_event' "$ROOT_DIR/bin/seven-spotlight" &&
   grep -q 'shell_experience' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'experience_focus' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q '"shell_experience"' "$ROOT_DIR/scripts/state.sh" &&
   grep -q 'motion_tokens' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'seven-motion-system' "$ROOT_DIR/identity/design-engine.json"; then
  ok "SevenOS exposes a shared Shell Experience contract"
else
  fail "SevenOS should expose one shell experience contract for motion, focus and feedback"
fi

if grep -q 'class SevenShellPanel' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'border-radius: 28px' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'notification-card' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'SevenQuickSettingsNative' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'build_slider_card' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'build_detail_card' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'detail-card' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'icon-action' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'set_keyboard_interactivity(window, False)' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'control_center_css' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'context_signal' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'SystemSnapshot' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'control-center-{theme_mode}.css' "$ROOT_DIR/bin/seven-quick-settings-native" &&
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
   grep -q 'current_theme_mode' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'region_selector_card' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'default_app_card' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'copy_system_summary' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven keyboard apply' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_theme.gtk_app_css("settings"' "$ROOT_DIR/bin/seven-settings-native" &&
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

if [[ -s "$ROOT_DIR/scripts/seven_theme.py" ]] &&
   python -m py_compile "$ROOT_DIR/scripts/seven_theme.py" >/dev/null 2>&1 &&
   grep -q 'def gtk_app_css' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'def surface_css' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'def resolved_theme' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'def wallpaper_state' "$ROOT_DIR/scripts/seven_theme.py" &&
   [[ -s "$ROOT_DIR/identity/native/store.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/reader.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/settings.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/settings-dark.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/files.css" ]] &&
   grep -q 'theme_preview_card' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'preview_mode' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'profile_combo' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven-wallpaper.*set' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_wallpaper_accent' "$ROOT_DIR/identity/native/settings.css" &&
   grep -q 'seven_theme.gtk_app_css("settings"' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_theme.surface_css("settings"' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_theme.gtk_app_css("store"' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'seven_theme.surface_css("store"' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'seven_theme.gtk_app_css("reader"' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'seven_theme.surface_css("reader"' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'seven_theme.gtk_app_css("files"' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'seven_theme.surface_css("files"' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'seven_theme.gtk_app_css("control-center"' "$ROOT_DIR/bin/seven-quick-settings-native"; then
  ok "Native GTK surfaces consume the shared Seven Design Engine"
else
  fail "Native GTK surfaces must consume scripts/seven_theme.py"
fi

if ! grep -R -E '#[0-9A-Fa-f]{3,8}|rgba?\(' "$ROOT_DIR/identity/native" >/dev/null 2>&1; then
  ok "Native app CSS uses Seven Design Engine tokens instead of hard-coded colors"
else
  fail "Native app CSS should use @seven_* tokens instead of hard-coded colors"
fi

if [[ -s "$ROOT_DIR/scripts/theme-engine.sh" ]] &&
   "$ROOT_DIR/scripts/theme-engine.sh" doctor >/dev/null 2>&1 &&
   grep -q 'seven identity theme-doctor' "$ROOT_DIR/scripts/identity.sh"; then
  ok "SevenOS theme runtime doctor is available"
else
  fail "SevenOS theme runtime doctor is incomplete"
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
   [[ -s "$ROOT_DIR/hyprland/rofi/app-menu.rasi" ]] &&
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
   grep -q 'current_theme_mode' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'spotlight_css' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'CACHE_FILE' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'LOCK_FILE' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'fcntl.LOCK_EX' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'fuzzy_score' "$ROOT_DIR/bin/seven-spotlight-native" &&
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
   grep -q 'current_theme_mode' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'CACHE_FILE' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'fuzzy_score' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'launchpad-filter' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'menu_for_app' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'record_recent' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'close_existing_launchpad' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'closewindow' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'LOCK_FILE' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'fcntl.LOCK_EX' "$ROOT_DIR/bin/seven-launchpad-native" &&
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
   grep -q 'operation-progress' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'drop-target' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'security-pill' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'location-entry' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'status-flash' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'toolbar-button.pressed' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'rubberband' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'media-inline' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'spring-armed' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'hover-preview' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'current_grid_columns' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'render_chunk' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'setup_file_tile_dnd' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'mounted_locations' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-tabbar' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-tab.active' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-split' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'split-header' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'operation-queue' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'empty-state' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'render_tabs' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'render_split' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'file_matches_query' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'FAVORITES_CACHE' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'render_favorite_rows' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Add to Favorites' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'show_tab_menu' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'show_breadcrumb_menu' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Open in New Tab' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Open in Split' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'New File' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'properties_dialog' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Keep Both' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Connect to Server' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'SevenTerminalNative' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'terminal-tool' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'terminal-searchbar' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'terminal-status' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'show_native_palette' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'PROFILE_ROLES' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'profile_role' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'Gtk.Notebook' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'Seven Reader' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'book-spread' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'paper-page' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'flip-active' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'SevenAI Reading Companion' "$ROOT_DIR/bin/seven-reader-native" &&
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
