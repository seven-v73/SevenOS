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

if rg -q "font-weight:[[:space:]]*[7-9]00|font:[[:space:]]*[7-9]00" "$ROOT_DIR/bin"/*native "$ROOT_DIR/identity/native" "$ROOT_DIR/scripts/seven_theme.py"; then
  fail "Native SevenOS surfaces must avoid heavy 700+ typography."
else
  ok "Native SevenOS surfaces avoid heavy 700+ typography"
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
   grep -q 'env SEVENOS_TERMINAL_BACKEND=kitty' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'window_logo_path /opt/SevenOS/branding/sddm/sevenos/assets/seven-prism.png' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'SF Pro Display' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'SF Pro Display</family><prefer><family>Inter' "$ROOT_DIR/hyprland/fontconfig/fonts.conf" &&
   grep -q 'SF Pro Rounded' "$ROOT_DIR/hyprland/fontconfig/fonts.conf"; then
  ok "SevenOS typography exposes SF Pro roles through the bundled Inter/JetBrains/Noto core"
else
  fail "SevenOS typography should expose SF Pro roles through the bundled Inter/JetBrains/Noto core"
fi

if [[ -s "$ROOT_DIR/branding/plymouth/sevenos/sevenos.plymouth" ]] &&
   [[ -s "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" ]] &&
   [[ -s "$ROOT_DIR/branding/plymouth/sevenos/seven-prism.png" ]] &&
   grep -q 'Name=SevenOS' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.plymouth" &&
   grep -q 'ModuleName=script' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.plymouth" &&
   grep -q 'Image("seven-prism.png")' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'Image.Text("SevenOS"' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'Preparing SevenOS workspace' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'Synchronizing Prism identity' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'Personalizing active Mini OS' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'Mini OS · Equinox Balance' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'Kernel quiet mode' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'generate_localized_script' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'boot_language' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'boot_profile_title' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'Plymouth.SetRefreshFunction' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'Plymouth.SetQuitFunction' "$ROOT_DIR/branding/plymouth/sevenos/sevenos.script" &&
   grep -q 'seven-prism.png' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'ShowDelay=0' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'update_kernel_cmdline_file' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'kms", "plymouth"' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'doctor) doctor' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'no interactive password prompt' "$ROOT_DIR/scripts/boot-splash.sh" &&
   grep -q 'seven-prism.png' "$ROOT_DIR/archiso/profile/airootfs/root/customize_airootfs.sh" &&
   grep -q 'boot-splash.sh theme' "$ROOT_DIR/archiso/profile/airootfs/root/customize_airootfs.sh" &&
   grep -q 'ShowDelay=0' "$ROOT_DIR/archiso/profile/airootfs/root/customize_airootfs.sh" &&
   grep -q 'choices=("status", "doctor", "apply", "theme")' "$ROOT_DIR/bin/seven"; then
  ok "SevenOS boot splash uses the Seven Prism animated Plymouth contract"
else
  fail "SevenOS boot splash should ship the Prism asset, animated Plymouth script and doctor route"
fi

if [[ -s "$ROOT_DIR/branding/sddm/sevenos/Main.qml" ]] &&
   [[ -s "$ROOT_DIR/branding/sddm/sevenos/theme.conf" ]] &&
   [[ -s "$ROOT_DIR/branding/sddm/sevenos/metadata.desktop" ]] &&
   [[ -s "$ROOT_DIR/branding/sddm/sevenos/assets/seven-prism.png" ]] &&
   grep -q 'Theme-Id=sevenos' "$ROOT_DIR/branding/sddm/sevenos/metadata.desktop" &&
   grep -q 'SevenOS Sign In' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'Connexion SevenOS' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'Qt.locale' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'Hyprland' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'miniOsTitle' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'Prism prêt' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'color: "#141B2D"' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'focusColor: accent2' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'seven-prism.png' "$ROOT_DIR/branding/sddm/sevenos/Main.qml" &&
   grep -q 'generate_theme_config' "$ROOT_DIR/scripts/login-theme.sh" &&
   grep -q 'active_profile_key' "$ROOT_DIR/scripts/login-theme.sh" &&
   grep -q 'active_profile_color' "$ROOT_DIR/scripts/login-theme.sh" &&
   grep -q 'Current=sevenos' "$ROOT_DIR/scripts/login-theme.sh" &&
   grep -q '^sddm$' "$ROOT_DIR/scripts/packages-identity.txt" &&
   grep -q '^plymouth$' "$ROOT_DIR/scripts/packages-identity.txt" &&
   grep -q '^polkit-gnome$' "$ROOT_DIR/scripts/packages-identity.txt" &&
   grep -q '^polkit-kde-agent$' "$ROOT_DIR/scripts/packages-identity.txt" &&
   grep -q '^zenity$' "$ROOT_DIR/scripts/packages-base.txt" &&
   grep -q '^sddm$' "$ROOT_DIR/archiso/profile/packages.x86_64" &&
   grep -q 'systemctl enable sddm.service' "$ROOT_DIR/archiso/profile/airootfs/root/customize_airootfs.sh" &&
   grep -q 'identity-assets.sh' "$ROOT_DIR/scripts/build-iso.sh" &&
   grep -q 'identity-assets.sh' "$ROOT_DIR/scripts/system-install.sh" &&
   grep -q 'scripts/packages-identity.txt' "$ROOT_DIR/scripts/new-device.sh" &&
   grep -q 'login-theme' "$ROOT_DIR/bin/seven" &&
   grep -q 'login-theme.sh apply' "$ROOT_DIR/archiso/profile/airootfs/root/customize_airootfs.sh"; then
  ok "SevenOS login screen exposes the Prism SDDM identity contract"
else
  fail "SevenOS login screen should ship a Prism SDDM theme, doctor route and ISO hook"
fi

if [[ -s "$ROOT_DIR/identity/DESIGN_ENGINE.md" ]] &&
   [[ -s "$ROOT_DIR/identity/design-engine.json" ]] &&
   [[ -s "$ROOT_DIR/identity/design-engine.css" ]] &&
   [[ -s "$ROOT_DIR/identity/PROFILE_THEMES.md" ]] &&
   [[ -s "$ROOT_DIR/profiles/catalog.json" ]] &&
   jq -e '.schema == "sevenos.design-engine.v1" and .modes."seven-mocha".palette.base == "#11111B" and .modes."seven-latte".palette.base == "#EFF1F5" and (.icon_strategy.rule | contains("Papirus")) and .profile_themes.contract == "identity/profile-themes.json" and .profile_themes.catalog == "profiles/catalog.json"' "$ROOT_DIR/identity/design-engine.json" >/dev/null &&
   jq -e '.schema == "sevenos.profile-themes.v1" and .profiles.equinox.short_label == "EQX" and .profiles.baobab.catppuccin_role == "green/yellow" and .profiles.shield.short_label == "SEC" and .profiles.pulse.short_label == "GAME"' "$ROOT_DIR/identity/profile-themes.json" >/dev/null &&
   jq -e '.schema == "sevenos.profiles.catalog.v1" and .default_profile == "equinox" and .profile_model.short_name == "LAPA" and .profiles.forge.mini_os == true and .profiles.atlas.title == "Atlas Explorer" and .profiles.baobab.layers.experience and .isolation_policy.activation and .core_package_files[0] == "scripts/packages-base.txt" and .runtime_optional_package_files[0] == "scripts/packages-runtime-optional.txt" and any(.profiles.baobab.anti_nuisance[]; . == "no dev toolchain") and .profiles.pulse.optional_package_files[0] == "scripts/packages-performance-optional.txt"' "$ROOT_DIR/profiles/catalog.json" >/dev/null &&
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

if [[ -s "$ROOT_DIR/identity/INTERACTION_CONTRACT.md" ]] &&
   [[ -s "$ROOT_DIR/identity/interaction-contract.json" ]] &&
   jq -e '.schema == "sevenos.interaction-contract.v1" and .required_patterns.feedback[0] == "initial_state" and .required_patterns.motion[2] == "reduced" and .public_commands.quality_public == "seven quality mode public"' "$ROOT_DIR/identity/interaction-contract.json" >/dev/null &&
   grep -q 'seven interaction-gate' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'seven accessibility-gate' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'quality.public_mode' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'interaction-contract.sh' "$ROOT_DIR/bin/seven" &&
   grep -q 'keyboard-focus-visible' "$ROOT_DIR/scripts/interaction-contract.sh"; then
  ok "SevenOS exposes the public interaction, accessibility and motion contract"
else
  fail "SevenOS should expose the public interaction, accessibility and motion contract"
fi

if [[ -s "$ROOT_DIR/identity/WORKFLOW_CONTRACT.md" ]] &&
   [[ -s "$ROOT_DIR/identity/workflow-contract.json" ]] &&
   jq -e '.schema == "sevenos.workflow-contract.v1" and .required_workflows.update.command == "seven update" and .required_workflows.quality_public.command == "seven quality mode public" and .public_gate == "seven workflow-gate"' "$ROOT_DIR/identity/workflow-contract.json" >/dev/null &&
   grep -q 'workflow-gate' "$ROOT_DIR/bin/seven" &&
   grep -q 'profile-switch-workflow.sh' "$ROOT_DIR/bin/seven" &&
   grep -q 'seven-passage-overlay' "$ROOT_DIR/scripts/profile-switch-workflow.sh" &&
   grep -q 'quality.workflow_gate' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'quality.public_mode_gui' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven quality mode public --gui' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'seven workflow-gate' "$ROOT_DIR/bin/seven-help"; then
  ok "SevenOS exposes the public workflow contract"
else
  fail "SevenOS should expose the public workflow contract"
fi

if [[ -s "$ROOT_DIR/identity/LAYOUT_CONTRACT.md" ]] &&
   [[ -s "$ROOT_DIR/identity/layout-contract.json" ]] &&
   jq -e '.schema == "sevenos.layout-contract.v1" and .minimum_display.width == 1024 and .public_gate == "seven layout-gate"' "$ROOT_DIR/identity/layout-contract.json" >/dev/null &&
   grep -q 'layout-gate' "$ROOT_DIR/bin/seven" &&
   grep -q 'quality.layout_gate' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven layout-gate' "$ROOT_DIR/bin/seven-help"; then
  ok "SevenOS exposes the public layout and overflow contract"
else
  fail "SevenOS should expose the public layout and overflow contract"
fi

if [[ -s "$ROOT_DIR/identity/PERFORMANCE_CONTRACT.md" ]] &&
   [[ -s "$ROOT_DIR/identity/performance-contract.json" ]] &&
   jq -e '.schema == "sevenos.performance-contract.v1" and .targets.click_feedback_ms == 200 and .public_gate == "seven performance-gate"' "$ROOT_DIR/identity/performance-contract.json" >/dev/null &&
   grep -q 'performance-gate' "$ROOT_DIR/bin/seven" &&
   grep -q 'quality.performance_gate' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven performance-gate' "$ROOT_DIR/bin/seven-help"; then
  ok "SevenOS exposes the public performance and responsiveness contract"
else
  fail "SevenOS should expose the public performance and responsiveness contract"
fi

if [[ -s "$ROOT_DIR/identity/NATIVE_FALLBACK_CONTRACT.md" ]] &&
   [[ -s "$ROOT_DIR/identity/native-fallback-contract.json" ]] &&
   jq -e '.schema == "sevenos.native-fallback-contract.v1" and (.required_routes | length) >= 6 and .public_blocker_policy == "legacy fallback is not a blocker when a native route is probed first"' "$ROOT_DIR/identity/native-fallback-contract.json" >/dev/null &&
   grep -q 'native-fallback-gate' "$ROOT_DIR/bin/seven" &&
   grep -q 'quality.native_fallback_gate' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven native-fallback-gate' "$ROOT_DIR/bin/seven-help"; then
  ok "SevenOS exposes the native-first fallback contract"
else
  fail "SevenOS should expose a native-first fallback contract for public routes"
fi

if [[ -s "$ROOT_DIR/identity/CHARTER_LIGHT.md" ]] &&
   [[ -s "$ROOT_DIR/identity/assets/wallpaper-sevenos-light.svg" ]] &&
   grep -q -- '--comfort-light-bg: #F6F9FD' "$ROOT_DIR/identity/tokens-light.css" &&
   grep -q -- '--comfort-light-panel: #FAFCFF' "$ROOT_DIR/identity/tokens-light.css" &&
   grep -q '"bg": "#F6F9FD"' "$ROOT_DIR/scripts/seven_theme.py" &&
   jq -e '."modules-left" == ["custom/sevenos","custom/recorder","hyprland/window","custom/app-file","custom/app-edit","custom/app-view","custom/app-extra","custom/app-more","custom/app-tools","custom/app-window","custom/app-help"] and ."hyprland/window".format == "{class}" and ."hyprland/window"."max-length" == 18 and ."custom/app-file".exec == "seven-waybar-status app-menu-item file" and ."custom/app-file"."on-click" == "seven-waybar-action app-file" and ."custom/app-edit"."on-click" == "seven-waybar-action app-edit" and ."custom/app-view"."on-click" == "seven-waybar-action app-view" and ."custom/app-extra"."on-click" == "seven-waybar-action app-extra" and ."custom/app-more".exec == "seven-waybar-status app-menu-more" and ."custom/app-more"."on-click" == "seven-waybar-action app-menu" and ."custom/app-tools"."on-click" == "seven-waybar-action app-tools" and ."custom/app-window"."on-click" == "seven-waybar-action app-window" and ."custom/app-help"."on-click" == "seven-waybar-action app-help" and ."custom/sevenos".exec == "seven-waybar-status sevenos" and ."custom/sevenos"."return-type" == "json" and ."custom/sevenos"."on-click-right" == "seven-profile-center-native" and ."custom/sevenos"."on-click-middle" == "seven-spotlight field" and ."modules-center" == ["hyprland/workspaces"] and ."modules-right" == ["custom/profile","custom/media","custom/system-status","custom/wifi","custom/bluetooth","custom/spotlight","clock","custom/control-center"] and .height == 30 and ."gtk-layer-shell" == true and ."custom/system-status".exec == "seven-waybar-status system-status" and ."custom/system-status"."return-type" == "json" and ."custom/spotlight".format == "󰍉" and (."custom/spotlight"."tooltip-format" | contains("Spotlight")) and ."custom/spotlight"."on-click" == "seven-spotlight field" and ."custom/wifi".exec == "seven-waybar-status wifi" and ."custom/bluetooth".exec == "seven-waybar-status bluetooth" and (."custom/recorder".exec | contains("seven-waybar-status") and contains("recorder")) and ."custom/recorder".format == "{}" and ."custom/recorder".interval == 2 and ."custom/control-center".exec == "seven-waybar-status control-center"' "$ROOT_DIR/hyprland-light/waybar/config.jsonc" >/dev/null &&
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

if [[ -s "$ROOT_DIR/identity/wallpaper/dynamic/manifest.json" ]] &&
   [[ "$(python -c 'import json,sys; data=json.load(open(sys.argv[1])); print(data.get("count",0) >= 94 and data.get("mini_os_count",0) == 49)' "$ROOT_DIR/identity/wallpaper/dynamic/manifest.json" 2>/dev/null || printf False)" == "True" ]] &&
   [[ "$(find "$ROOT_DIR/identity/wallpaper/dynamic" -maxdepth 1 -name '*.svg' | wc -l)" -ge 94 ]] &&
   grep -Eq 'collection|pack|dynamic' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -Eq 'collection-list|packs|list' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -q 'set_wallpaper_rotation' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -q 'set_wallpaper_rotation_preset' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -q 'wallpaper_rotation_enabled' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -q '^swww$' "$ROOT_DIR/scripts/packages-base.txt" &&
   grep -q 'wallpaper-choice' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'rotation_selection' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'set_rotation_preset' "$ROOT_DIR/bin/seven-settings-native"; then
  ok "SevenOS exposes 94 dynamic wallpapers including 49 Mini OS wallpapers through Settings and seven-wallpaper"
else
  fail "SevenOS should expose 94 dynamic wallpapers including 49 Mini OS wallpapers through Settings and seven-wallpaper"
fi

if jq -e '."modules-left" == ["custom/sevenos","custom/recorder","hyprland/window","custom/app-file","custom/app-edit","custom/app-view","custom/app-extra","custom/app-more","custom/app-tools","custom/app-window","custom/app-help"] and ."hyprland/window".format == "{class}" and ."hyprland/window"."max-length" == 18 and ."custom/app-file".exec == "seven-waybar-status app-menu-item file" and ."custom/app-file"."on-click" == "seven-waybar-action app-file" and ."custom/app-edit"."on-click" == "seven-waybar-action app-edit" and ."custom/app-view"."on-click" == "seven-waybar-action app-view" and ."custom/app-extra"."on-click" == "seven-waybar-action app-extra" and ."custom/app-more".exec == "seven-waybar-status app-menu-more" and ."custom/app-more"."on-click" == "seven-waybar-action app-menu" and ."custom/app-tools"."on-click" == "seven-waybar-action app-tools" and ."custom/app-window"."on-click" == "seven-waybar-action app-window" and ."custom/app-help"."on-click" == "seven-waybar-action app-help" and ."custom/sevenos".exec == "seven-waybar-status sevenos" and ."custom/sevenos"."return-type" == "json" and ."custom/sevenos"."on-click-right" == "seven-profile-center-native" and ."custom/sevenos"."on-click-middle" == "seven-spotlight field" and ."modules-center" == ["hyprland/workspaces"] and ."modules-right" == ["custom/profile","custom/media","custom/system-status","custom/wifi","custom/bluetooth","custom/spotlight","clock","custom/control-center"] and .height == 30 and .spacing == 4 and ."margin-top" == 0 and ."margin-left" == 0 and ."margin-right" == 0 and ."gtk-layer-shell" == true and ."custom/system-status".exec == "seven-waybar-status system-status" and ."custom/system-status"."return-type" == "json" and ."custom/spotlight".format == "󰍉" and (."custom/spotlight"."tooltip-format" | contains("Spotlight")) and ."custom/spotlight"."on-click" == "seven-spotlight field" and ."hyprland/workspaces".format == "{icon}" and ."hyprland/workspaces"."format-icons"."1" == "1" and (."custom/recorder".exec | contains("seven-waybar-status") and contains("recorder")) and ."custom/recorder".format == "{}" and ."custom/recorder".interval == 2 and ."custom/control-center".exec == "seven-waybar-status control-center" and ."custom/control-center"."return-type" == "json"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
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
   [[ -x "$ROOT_DIR/bin/seven-dock-canvas" ]] &&
   [[ -x "$ROOT_DIR/bin/seven-dock-native" ]] &&
   grep -q 'smooth-neighbor-magnification' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'magnetic-focus' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'smooth-slide-reveal' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'spring-motion' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'direct-native-spotlight' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'centered-icons' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'anchored-window-preview' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'folder-stacks' "$ROOT_DIR/bin/seven-dock-canvas" &&
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
   grep -q 'sevenos/language.env' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'SEVENOS_LANGUAGE LANG LANGUAGE LC_MESSAGES' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'def experience()' "$ROOT_DIR/bin/seven-waybar-status" &&
   grep -q 'Suggestion:' "$ROOT_DIR/bin/seven-waybar-status" &&
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
   grep -Eq 'set_keyboard_interactivity\(window, (True|os\.environ\.get\("SEVENOS_CONTROL_CENTER_KEYBOARD"\) == "1")\)' "$ROOT_DIR/bin/seven-quick-settings-native" &&
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
   grep -q 'prism-node.switching' "$ROOT_DIR/bin/seven-profile-center-native" &&
   grep -q 'Passage en cours' "$ROOT_DIR/bin/seven-profile-center-native" &&
   grep -q 'def draw_prism' "$ROOT_DIR/bin/seven-passage-overlay" &&
   grep -q 'def read_watch_status' "$ROOT_DIR/bin/seven-passage-overlay" &&
   grep -q -- '--watch' "$ROOT_DIR/bin/seven-passage-overlay" &&
   grep -q 'PROFILE_ORDER' "$ROOT_DIR/bin/seven-passage-overlay" &&
   grep -q 'ease_out_cubic' "$ROOT_DIR/bin/seven-passage-overlay" &&
   grep -q 'profile-passage-state.v1' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'SEVENOS_PASSAGE_DURATION:-1550' "$ROOT_DIR/profiles/profile-manager.sh" &&
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
   ( [[ "${SEVENOS_DESIGN_GUI_SMOKE:-0}" != "1" ]] || timeout 14s "$ROOT_DIR/bin/seven-settings-native" --smoke-open general >/dev/null 2>&1 ) &&
   grep -q 'SevenSettingsNative' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings-shell' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'file_wallpaper_button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'import_fonts_button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven fonts apply-default' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven-wallpaper' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'current_theme_mode' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'compact_screen' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'content_width' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'sidebar_width' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'mark_action_running' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'def prism_settings_group' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'def dock_settings_group' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.dock.autohide' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.dock.always_visible' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven-window controls-effect off' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'nav("prism"' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'nav("dock"' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'pages\["prism"\]' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'pages\["dock"\]' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'dock_settings_group(dock_page)' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.jump.prism' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'search_key' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'page_button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'sevenos.settings.state.v1' "$ROOT_DIR/bin/seven-settings-native" &&
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
   python -c 'import py_compile, sys, tempfile; py_compile.compile(sys.argv[1], cfile=tempfile.mktemp(suffix=".pyc"), doraise=True)' "$ROOT_DIR/scripts/seven_theme.py" >/dev/null 2>&1 &&
   grep -q 'def gtk_app_css' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'def surface_css' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'def resolved_theme' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'def wallpaper_state' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'seven-root' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'seven-button' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'seven-primary' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'seven-action-row' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'seven-empty-state' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'seven-status-banner' "$ROOT_DIR/scripts/seven_theme.py" &&
   [[ -s "$ROOT_DIR/identity/native/store.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/reader.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/settings.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/settings-dark.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/files.css" ]] &&
	   grep -q 'theme_preview_card' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'def theme_apply_command' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'def language_apply_command' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'def session_refresh_command' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'def repair_interface_command' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'def refresh_runtime_css' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'preview_mode' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'profile_combo' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'def settings_row' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'def settings_group' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'general_jump_strip' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'general_targets' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'show_command_output' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'should_show_output' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings.action.resources.title' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings.action.software.title' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'SEVENOS_SETTINGS_ACTION' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'SETTINGS_ACTION_LOG' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'show_settings_action_history' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Historique des actions' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings-progress' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'operation_stage' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'action_summary' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'update_status_payload' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'show_update_manager' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'collect_update_items' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'community_command' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'askpass_path' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'SUDO_ASKPASS' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings.update.install_community' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'update-summary-panel' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'update-kind-icon' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'add_update_section' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'update-section-row' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'update-impact' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings.update.impact.community' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'pkexec' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'append_install_line' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'start_pulse' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven-update-admin' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven-askpass' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings.update.activity.download' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings.update.activity.pacman_failed' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'SevenOS Settings update install' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings.update.install' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'set_update_state' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'set_action_state' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings.action.tooltip' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'ui_command = "seven smoke status"' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Résumé prêt dans Paramètres' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'selectors.DefaultSelector' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'SevenOS a arrêté l’attente graphique' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven update apply --yes' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'stdbuf -oL -eL' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'heartbeat_source' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Mise à jour SevenOS' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Installation des besoins essentiels' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'action-step-list' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Action en cours…' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Copier le compte rendu' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven profile requirements' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'mini_os_capability_panel' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven.*mini-os.*activate' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Mode d’utilisation SevenOS' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Entretien SevenOS' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Atlas Explorer' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Sauvegarde rapide' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Animations' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'profile requirements' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings-inline-status' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'settings-jump-strip' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'command-output' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'settings-progress' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'action-step-list' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'action-step-state' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'update-source-grid' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'state-ok' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'update-row' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'update-activity' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'update-summary-chip' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'update-total-value' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'update-badge-community' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'update-impact' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'update-section-title' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'primary-action' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'action-state-running' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'action-state-success' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'action-state-error' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'geteuid() == 0' "$ROOT_DIR/bin/sevenpkg" &&
	   grep -q -- '--noconfirm' "$ROOT_DIR/bin/sevenpkg" &&
	   grep -q 'capability_preview_detail' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings-row .action-button' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'set_transition_duration(140)' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'deep_settings_enabled' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Vérification à la demande' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven-wallpaper.*set' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven-wallpaper profile' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven-wallpaper.*collection-list' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q './install.sh theme current' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven_wallpaper_accent' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q '.settings-row' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q '.settings-group' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q '.action-button.busy' "$ROOT_DIR/identity/native/settings.css" &&
   grep -q 'seven_theme.gtk_app_css("settings"' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_theme.surface_css("settings"' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_theme.gtk_app_css("store"' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'seven_theme.surface_css("store"' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'seven_theme.gtk_app_css("reader"' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'seven_theme.surface_css("reader"' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'seven_theme.gtk_app_css("notes"' "$ROOT_DIR/bin/seven-notes-native" &&
   grep -q 'SevenNotesNative' "$ROOT_DIR/bin/seven-notes-native" &&
   grep -q 'seven_theme.gtk_app_css("tools"' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'SevenToolsNative' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'Gtk.SearchEntry' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'show_tool_details' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'filter_state' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'copy_report' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'tool-blocker' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'on_key_press' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'Gdk.KEY_Escape' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'Ctrl+F' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'category_filter' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'category_label' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q '"battery"' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q '"media"' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q '"tasks"' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'WIDGET_CATEGORIES' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'widget_category_title' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'widget_search_text' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'Gtk.SearchEntry' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'search-row' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'category-count' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'set_weather_location' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'preset_widgets' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'apply_preset' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'merge_preset' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'Compléter' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'BACKUP_FILE' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'backup_config' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'restore_previous_config' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'mark_action' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'last_action_text' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'feedback-row' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'Restaurer' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'move_widget' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'toggle_widgets' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'menu-state' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'Active preset' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'Ordre de l’accueil' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'order-index' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'widget_icon' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'LAYOUTS' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'set_layout' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'focus-stack' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'tasks_widget_card' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q 'mini_os_widget_card' "$ROOT_DIR/bin/seven-widgets-native" &&
   grep -q '"categories": categories' "$ROOT_DIR/scripts/tools.sh" &&
   grep -q 'sevenos.tools.detail.v1' "$ROOT_DIR/scripts/tools.sh" &&
   grep -q 'tools.detail.files' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'quality.ux.fast' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'def handle_ux' "$ROOT_DIR/bin/seven" &&
   grep -q 'seven ux fast --json' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'sevenos.ux-check.v1' "$ROOT_DIR/scripts/ux-check.sh" &&
   grep -q -- '--fast|fast' "$ROOT_DIR/scripts/ux-check.sh" &&
   grep -q 'choices=("open", "gui", "status", "doctor", "plan", "detail", "json")' "$ROOT_DIR/bin/seven" &&
   grep -q '"intent"' "$ROOT_DIR/scripts/tools.sh" &&
   grep -q '"recommendation": recommendation' "$ROOT_DIR/scripts/tools.sh" &&
   grep -q 'tool-intent' "$ROOT_DIR/bin/seven-tools-native" &&
   grep -q 'seven_theme.gtk_app_css("files"' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'seven_theme.surface_css("files"' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'seven_theme.gtk_app_css("control-center"' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'seven_theme.gtk_app_css("actions"' "$ROOT_DIR/bin/seven-actions-native" &&
   grep -q 'seven_theme.gtk_app_css("recorder"' "$ROOT_DIR/bin/seven-recorder-native" &&
   grep -q 'seven_theme.gtk_app_css("profile-center"' "$ROOT_DIR/bin/seven-profile-center-native" &&
   grep -q 'seven_theme.gtk_app_css("notification-center"' "$ROOT_DIR/bin/seven-notification-center-native" &&
   grep -q 'seven_theme.gtk_app_css("waybar-center"' "$ROOT_DIR/bin/seven-waybar-center-native" &&
   grep -q 'seven_theme.gtk_app_css("doctor"' "$ROOT_DIR/bin/seven-doctor-native" &&
   grep -q 'seven_theme.gtk_app_css("shield-center"' "$ROOT_DIR/bin/seven-shield-center-native" &&
   grep -q 'seven_theme.gtk_app_css("window-controls"' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'def window_prism_motion_enabled' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'SEVENOS_WINDOW_CONTROLS_ANIMATION' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'SEVENOS_WINDOW_CONTROLS_EFFECT' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'def electric_prism_colors' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'def prism_items' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'def prism_items_cluster' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'link.add_color_stop_rgba(1, 1, 1, 1' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'controls-effect' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'PRISM_ITEMS_MAX=7' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'Prism items JSON validity' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'controls-item set <daily|dev|clean>' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'controls-item move' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'controls-item custom' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'controls-item' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'settings.prism.items' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'prism-preview-card' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'prism-order-row' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.prism.custom' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'prism-suggestion' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'prism-order-command' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.prism.test' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'command_status_text' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.prism.presets' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'controls-effect toggle' "$ROOT_DIR/bin/seven-help-native" &&
   grep -q 'glint_angle' "$ROOT_DIR/bin/seven-window-controls-native" &&
   grep -q 'seven_theme.gtk_app_css("spotlight"' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'seven_theme.gtk_app_css("launchpad"' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'seven_theme.gtk_app_css("dock"' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'seven_theme.gtk_app_css("home"' "$ROOT_DIR/bin/seven-home-native" &&
   grep -q 'seven_theme.gtk_app_css("terminal"' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'seven_theme.gtk_app_css("hub"' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'compact_screen' "$ROOT_DIR/bin/seven-help-native" &&
   grep -q 'seven_theme.gtk_app_css("baobab"' "$ROOT_DIR/bin/seven-baobab-native" &&
   grep -q 'def cairo_palette' "$ROOT_DIR/bin/seven-app-menu-native" &&
   grep -q 'def cairo_palette' "$ROOT_DIR/bin/seven-mini-context-menu-native" &&
   grep -q 'def cairo_palette' "$ROOT_DIR/bin/seven-system-menu-native" &&
   grep -q 'def cairo_palette' "$ROOT_DIR/bin/seven-media-menu-native" &&
   "$ROOT_DIR/bin/seven-recorder-native" --probe >/dev/null 2>&1; then
  ok "Native GTK surfaces consume the shared Seven Design Engine"
else
  fail "Native GTK surfaces must consume scripts/seven_theme.py"
fi

if ! grep -R -E '#[0-9A-Fa-f]{3,8}|rgba?\(' "$ROOT_DIR/identity/native" >/dev/null 2>&1; then
  ok "Native app CSS uses Seven Design Engine tokens instead of hard-coded colors"
else
  fail "Native app CSS should use @seven_* tokens instead of hard-coded colors"
fi

if grep -q 'pkill -x waybar' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'pkill -x swaync' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'pkill -x hyprpaper' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'sevenos-wallpaper.service' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'pkill -x waybar' "$ROOT_DIR/scripts/update.sh" &&
   grep -q 'pkill -x swaync' "$ROOT_DIR/scripts/update.sh" &&
   grep -q 'pkill -x hyprpaper' "$ROOT_DIR/scripts/update.sh" &&
   grep -q 'sevenos-wallpaper.service' "$ROOT_DIR/scripts/update.sh"; then
  ok "Theme/update actions resync live shell surfaces"
else
  fail "Theme/update actions should resync Waybar, notifications and wallpaper"
fi

if [[ -s "$ROOT_DIR/scripts/theme-engine.sh" ]] &&
   [[ -s "$ROOT_DIR/scripts/theme-session.sh" ]] &&
   "$ROOT_DIR/scripts/theme-engine.sh" doctor >/dev/null 2>&1 &&
   "$ROOT_DIR/scripts/theme-session.sh" doctor >/dev/null 2>&1 &&
   [[ -s "$ROOT_DIR/systemd/user/sevenos-theme-session.service" ]] &&
   grep -q 'sevenos-theme-session.service' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'seven identity theme-doctor' "$ROOT_DIR/scripts/identity.sh"; then
  ok "SevenOS theme runtime doctor is available"
else
  fail "SevenOS theme runtime doctor is incomplete"
fi

if grep -q 'seven-hub-window' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-sidebar' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'hub_width' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'sidebar_width' "$ROOT_DIR/bin/seven-hub-native" &&
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
   grep -q -- '--comfort-dark-bg: #080A12' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--comfort-dark-panel: rgba(13, 17, 29, 0.82)' "$ROOT_DIR/identity/tokens.css" &&
   grep -q '"bg": "#080A12"' "$ROOT_DIR/scripts/seven_theme.py" &&
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
   grep -q 'screen_window_size' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'runtime_preview_visible' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'screen_compact' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'settings_local_css' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'profile_avatar_pack' "$ROOT_DIR/bin/seven-settings-native" &&
   [[ "$(find "$ROOT_DIR/identity/profile-avatars" -maxdepth 1 -name '*.svg' 2>/dev/null | wc -l | tr -d ' ')" -ge 45 ]] &&
   grep -q 'PROFILE_AVATAR_PREFS' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'show_avatar_picker' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'choose_gallery_avatar' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'normalize_gallery_avatar' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'GdkPixbuf' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'avatar-picker-grid' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'avatar-picker-frame' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Gtk.Grid' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'dialog.set_resizable(False)' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'avatar-selected-mark' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'avatar-edit-button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'account-hero-card' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'account-action-strip' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'account-strip-button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'dialog.set_resizable(False)' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'account-dialog-content' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'list_box.set_size_request(-1, 72)' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Final modal override' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q '.settings-dialog.theme-light .update-summary-panel' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q '.account-list row:selected' "$ROOT_DIR/identity/native/settings.css" &&
   grep -q '.settings-dialog.theme-light .account-dialog-content' "$ROOT_DIR/identity/native/settings.css" &&
   grep -q '.settings-dialog scrolledwindow viewport' "$ROOT_DIR/identity/native/settings.css" &&
   grep -q 'linear-gradient(135deg, @seven_panel, @seven_bg)' "$ROOT_DIR/identity/native/settings.css" &&
   grep -q 'settings.users.current_space' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.users.avatar_reset' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'user-avatar-account' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'user-avatar-picture-large' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'user-account-profile-badge' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.users.account_space' "$ROOT_DIR/bin/seven-settings-native" &&
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
   grep -q 'background #09090B' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'Exec=seven-kitty' "$ROOT_DIR/seven-hub/seven-kitty.desktop" &&
   grep -q 'SEVENOS_TERMINAL_NATIVE=0' "$ROOT_DIR/bin/seven-kitty"; then
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

if [[ -x "$ROOT_DIR/bin/seven-identity-native" ]] &&
   grep -q 'SevenOS Signature' "$ROOT_DIR/bin/seven-identity-native" &&
   grep -q 'symbol-seven-prism.svg' "$ROOT_DIR/bin/seven-identity-native" &&
   grep -q 'identity-window' "$ROOT_DIR/bin/seven-identity-native" &&
   grep -q 'Experience Guardrails' "$ROOT_DIR/bin/seven-identity-native" &&
   grep -q 'seven identity open' "$ROOT_DIR/scripts/identity.sh" &&
   grep -q 'identity.open' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'SevenOS Identity' "$ROOT_DIR/scripts/surfaces.sh"; then
  ok "SevenOS identity report is a native Prism-first surface"
else
  fail "SevenOS identity report should be a native Prism-first surface"
fi

if [[ "$failures" -gt 0 ]]; then
  log_error "Design checks failed: $failures"
  exit 1
fi

log_success "Design coherence checks passed."
