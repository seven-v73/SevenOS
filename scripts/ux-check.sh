#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
JSON_MODE=0
FAST_MODE="${SEVENOS_UX_FAST:-0}"
for arg in "$@"; do
  case "$arg" in
    --json|json)
      JSON_MODE=1
      ;;
    --fast|fast)
      FAST_MODE=1
      ;;
  esac
done
source "$ROOT_DIR/scripts/lib.sh"

failures=0
export PYENV_DISABLE_REHASH="${PYENV_DISABLE_REHASH:-1}"

emit_line() {
  if [[ "$JSON_MODE" == "1" ]]; then
    printf '%s\n' "$*" >&2
  else
    printf '%s\n' "$*"
  fi
}

ok() {
  emit_line "[OK] $*"
}

warn() {
  emit_line "[WARN] $*"
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  [[ -s "$ROOT_DIR/$path" ]] && ok "$path" || fail "$path missing or empty"
}

require_executable() {
  local path="$1"
  [[ -x "$ROOT_DIR/$path" ]] && ok "$path executable" || fail "$path not executable"
}

package_manifest_contains() {
  local package="$1"
  local file="$2"

  if grep -Eq "^[[:space:]]*$package([[:space:]]*(#.*)?)?$" "$ROOT_DIR/$file"; then
    ok "$file includes $package"
  else
    fail "$file missing $package"
  fi
}

capture_with_timeout() {
  local seconds="$1"
  shift
  timeout "${seconds}s" "$@" 2>/dev/null || true
}

finish_checks() {
  local state="ready"
  [[ "$failures" -gt 0 ]] && state="blocked"
  if [[ "$JSON_MODE" == "1" ]]; then
    python3 - "$state" "$failures" "$FAST_MODE" <<'PY'
import json
import sys

state = sys.argv[1]
failures = int(sys.argv[2])
fast = sys.argv[3] == "1"
print(json.dumps({
    "schema": "sevenos.ux-check.v1",
    "state": state,
    "mode": "fast" if fast else "full",
    "failures": failures,
}, ensure_ascii=False, indent=2))
PY
  elif [[ "$failures" -gt 0 ]]; then
    log_error "UX checks failed: $failures"
  else
    log_success "UX coherence checks passed."
  fi
  exit "$([[ "$failures" -gt 0 ]] && echo 1 || echo 0)"
}

if [[ "$JSON_MODE" == "1" ]]; then
  printf '[SevenOS] Running SevenOS UX coherence checks...\n' >&2
else
  log_info "Running SevenOS UX coherence checks..."
fi

require_file "docs/VISION.md"
require_file "docs/ARCHITECTURE.md"
require_file "docs/HYBRID_OS_ARCHITECTURE.md"
require_file "docs/SYSTEM_EXPERIENCE_LAYER.md"
require_file "docs/CYBERSPACE.md"
require_file "docs/UX_PRINCIPLES.md"
require_file "docs/VOCABULARY.md"
require_file "docs/PHASE_GATE.md"
require_file "docs/ECOSYSTEM.md"
require_file "docs/FUTURE_FEATURES.md"
require_file "docs/STACK_STRATEGY.md"
require_file "docs/PRODUCTIZATION.md"
require_file "docs/TEST_MACHINE.md"
require_file "docs/PRE_PUSH.md"
require_file "docs/PRIMARY_PC.md"
require_file "docs/MIGRATE_FROM_ML4W.md"
require_file "docs/SEVEN_READER.md"
require_file "docs/SEVEN_STORE.md"
require_file "docs/SMART_WINDOW_SYSTEM.md"
require_file "docs/HYPRLAND_LUA_ENGINE.md"
require_file "docs/DISTRIBUTION_AUTONOMY.md"
require_file "seven-core/README.md"
require_file "seven-core/bus-schema.json"
require_file "seven-core/daemon/Cargo.toml"
require_file "seven-core/daemon/src/main.rs"
require_file "seven-core/bus-c/README.md"
require_file "seven-core/bus-c/Makefile"
require_file "seven-core/bus-c/src/sevenbus_probe.c"
require_file "systemd/user/seven-daemon.service"
require_file "systemd/user/seven-context-observer.service"
require_file "sevenos.dotinst"
require_file "installer/calamares/README.md"
require_file "installer/calamares/settings.conf"
require_file "installer/calamares/modules/sevenos.conf"
require_file "installer/calamares/branding/sevenos/branding.desc"
require_file "archiso/profile/airootfs/usr/share/applications/seven-installer.desktop"
require_file "seven-hub/gui/README.md"
require_file "seven-hub/gui/package.json"
require_file "seven-hub/gui/package-lock.json"
require_file "seven-hub/gui/vite.config.js"
require_file "seven-hub/gui/src/index.html"
require_file "seven-hub/gui/src/main.js"
require_file "seven-hub/gui/src/styles.css"
require_file "seven-hub/gui/src-tauri/Cargo.toml"
require_file "seven-hub/gui/src-tauri/build.rs"
require_file "seven-hub/gui/src-tauri/icons/icon.png"
require_file "seven-hub/gui/src-tauri/tauri.conf.json"
require_file "seven-hub/gui/src-tauri/src/main.rs"
require_file "seven-hub/native/README.md"
require_file "seven-hub/seven-hub-native.desktop"
require_file "seven-hub/seven-wallpaper.desktop"
require_file "seven-hub/seven-spotlight.desktop"
require_file "seven-hub/seven-ai.desktop"
require_file "scripts/flatpak-apps.txt"
require_file "seven-shell/README.md"
require_file "seven-shell/ags/README.md"
require_file "seven-shell/ags/package.json"
require_file "seven-shell/ags/tsconfig.json"
require_file "seven-shell/ags/src/contracts.ts"
require_file "seven-shell/ags/src/config.ts"
require_file "seven-shell/ags/src/dock.ts"
require_file "branding/shell/terminal-country.sh"
require_file "branding/shell/terminal-bashrc"
require_file "branding/shell/terminal-zsh/.zshrc"
require_file "branding/motd"
require_file "branding/issue"
require_file "branding/sevenos-release"
require_file "archiso/profile/airootfs/etc/motd"
require_file "archiso/profile/airootfs/etc/issue"
require_file "archiso/profile/airootfs/etc/sevenos-release"
require_file "identity/countries/africa.tsv"
require_file "identity/STYLE.md"
require_file "identity/LIQUID_GLASS_OS.md"
require_file "identity/AFRICAN_FIRST.md"
require_file "identity/DESIGN_ENGINE.md"
require_file "identity/PROFILE_THEMES.md"
require_file "identity/profile-themes.json"
require_file "profiles/catalog.json"
require_file "docs/PROFILE_ISOLATION.md"
require_file "docs/PULSE_MINI_OS.md"
require_file "docs/MINI_OS_REQUIREMENTS.md"
require_file "scripts/profile-isolation.sh"
require_file "bin/seven-profile-run"
require_file "identity/tokens.css"
require_file "identity/tokens-light.css"
require_file "identity/control-center-dark.css"
require_file "identity/control-center-light.css"
require_file "identity/design-engine.json"
require_file "identity/design-engine.css"
require_file "identity/icons/manifest.json"
require_file "identity/icons/seven-hub.svg"
require_file "identity/icons/seven-files.svg"
require_file "identity/icons/seven-reader.svg"
require_file "identity/icons/seven-store.svg"
require_file "identity/icons/seven-settings.svg"
require_file "identity/icons/seven-spotlight.svg"
require_file "identity/icons/seven-ai.svg"
require_file "identity/icons/seven-security.svg"
require_file "identity/icons/seven-studio.svg"
require_file "scripts/packages-visual-aur.txt"
require_file "scripts/packages-culture-optional.txt"
require_file "scripts/packages-performance-optional.txt"
require_file "scripts/packages-runtime-optional.txt"
require_file "scripts/packages-hypr-ecosystem.txt"
require_file "scripts/packages-hypr-ecosystem-aur.txt"
require_file "identity/accent-packs.json"
require_file "identity/components/kente-divider.svg"
require_file "identity/components/adinkra-status-ok.svg"
require_file "identity/components/baobab-system-mark.svg"
require_file "identity/components/griot-doc-mark.svg"
require_file "identity/components/forge-profile-mark.svg"
require_file "identity/components/shield-profile-mark.svg"
require_file "identity/patterns/kente.svg"
require_file "identity/patterns/motif-concentric.svg"
require_file "identity/patterns/motif-diamond.svg"
require_file "identity/patterns/motif-grid.svg"
require_file "identity/patterns/motif-triangle.svg"
require_file "identity/patterns/motif-stripe.svg"
require_file "identity/patterns/motif-cross.svg"
require_file "hyprland/rofi/apps.rasi"
require_file "hyprland/rofi/app-menu.rasi"
require_file "hyprland/rofi/hub.rasi"
require_file "hyprland/rofi/spotlight.rasi"
require_file "hyprland/rofi/quick-settings.rasi"
require_file "hyprland/rofi/power.rasi"
require_file "hyprland/rofi/prompt.rasi"
require_file "hyprland/mako/config"
require_file "hyprland/swaync/config.json"
require_file "hyprland/swaync/style.css"
require_file "hyprland/wlogout/layout"
require_file "hyprland/wlogout/style.css"
require_file "hyprland/hypridle.conf"
require_file "hyprland/hyprlock.conf"
require_file "hyprland/conf/sevenos-dynamic.conf"
require_file "hyprland/conf/sevenos-windows.conf"
require_file "hyprland/conf/sevenos-lua-generated.conf"
require_file "hyprland/lua/init.lua"
require_file "hyprland/lua/core/audit.lua"
require_file "hyprland/lua/core/emit.lua"
require_file "hyprland/lua/core/profiles.lua"
require_file "hyprland/lua/rules/animations.lua"
require_file "hyprland/lua/rules/windows.lua"
require_file "hyprland/lua/rules/keybinds.lua"
require_file "hyprland/lua/profiles/equinox.lua"
require_file "hyprland/lua/profiles/forge.lua"
require_file "hyprland/lua/profiles/shield.lua"
require_file "hyprland/lua/profiles/studio.lua"
require_file "hyprland/lua/profiles/atlas.lua"
require_file "hyprland/lua/profiles/pulse.lua"
require_file "hyprland/lua/profiles/baobab.lua"
require_file "hyprland/lua/profile_runtime.json"
require_file "systemd/user/sevenos-hyprsunset.service"
require_file "systemd/user/sevenos-hypr-lua-events.service"
require_file "systemd/user/sevenos-polkit-agent.service"
require_file "systemd/user/sevenos-shell-experience.service"
require_file "hyprland/kitty/kitty.conf"
require_file "hyprland/kitty/classic.conf"
require_file "hyprland/kitty/dark.conf"
require_file "hyprland/gtk-3.0/gtk.css"
require_file "hyprland/gtk-4.0/gtk.css"
require_file "hyprland/conf/custom.conf"
require_file "hyprland/conf/keyboard.conf"
require_file "hyprland/conf/monitor.conf"
require_file "hyprland/waybar/config.jsonc"
require_file "hyprland/gtk-3.0/settings.ini"
require_file "hyprland/gtk-4.0/settings.ini"
require_file "hyprland/qt5ct/qt5ct.conf"
require_file "hyprland/qt6ct/qt6ct.conf"
require_file "hyprland/fontconfig/fonts.conf"
require_file "seven-hub/seven-files.desktop"
require_file "seven-hub/seven-reader.desktop"
require_file "seven-hub/seven-notes.desktop"
require_file "seven-hub/seven-tools.desktop"
require_file "seven-hub/seven-store.desktop"
require_file "seven-hub/seven-terminal.desktop"

require_executable "bin/seven"
require_executable "bin/sevenpkg"
require_executable "seven-hub/bin/seven-hub"
require_executable "seven-hub/bin/seven-control-center"
require_executable "bin/seven-country"
require_executable "bin/seven-language"
require_executable "bin/seven-daemon"
require_executable "bin/sevenbus-probe"
require_executable "bin/seven-apps"
require_executable "bin/seven-launchpad-native"
require_executable "bin/seven-dock"
require_executable "bin/seven-dock-canvas"
require_executable "bin/seven-dock-native"
require_executable "bin/seven-files"
require_executable "bin/seven-files-native"
require_executable "bin/seven-reader"
require_executable "bin/seven-reader-native"
require_executable "bin/seven-notes"
require_executable "bin/seven-notes-native"
require_executable "bin/seven-tools"
require_executable "bin/seven-tools-native"
require_executable "bin/seven-store"
require_executable "bin/seven-store-native"
require_executable "bin/seven-help"
require_executable "bin/seven-help-native"
require_executable "bin/seven-overview"
require_executable "bin/seven-quick-settings"
require_executable "bin/seven-quick-settings-native"
require_executable "bin/seven-recorder"
require_executable "bin/seven-screenshot"
require_executable "bin/seven-shell-panel"
require_executable "bin/seven-shell-preview"
require_executable "bin/seven-terminal"
require_executable "bin/seven-terminal-native"
require_executable "bin/seven-terminal-palette"
require_executable "bin/seven-terminal-shell"
require_executable "scripts/terminal-guard.sh"
require_executable "bin/seven-spotlight"
require_executable "bin/seven-spotlight-native"
require_executable "bin/seven-notification-center-native"
require_executable "bin/seven-profile-center-native"
require_executable "bin/seven-shield-center-native"
require_executable "bin/seven-waybar-center-native"
require_executable "bin/seven-session"
require_executable "bin/seven-session-status"
require_executable "bin/seven-notifications"
require_executable "bin/seven-idle"
require_executable "bin/seven-wallpaper"
require_executable "bin/seven-power"
require_executable "bin/seven-welcome"
require_executable "bin/seven-hub-native"
require_executable "bin/seven-action-runner"
require_executable "bin/seven-installer"
require_executable "bin/seven-waybar-action"
require_executable "bin/seven_waybar_app_profiles.py"
require_executable "bin/seven-app-menu-native"
require_executable "bin/seven-waybar-notifications"
require_executable "bin/seven-waybar-profile"
require_executable "bin/seven-waybar-security"
require_executable "bin/seven-waybar-language"
require_executable "bin/seven-waybar"
require_executable "bin/seven-workspace"
require_executable "bin/seven-window"
require_executable "bin/seven-window-controls-native"
require_executable "bin/seven-profile-theme"
require_executable "bin/hyprsysteminfo"
require_executable "bin/seven-bluetooth"
require_executable "bin/seven-pulse"
require_executable "bin/seven-mini-doctor"
require_executable "scripts/phase-gate.sh"
require_executable "scripts/architecture.sh"
require_executable "scripts/state.sh"
require_executable "scripts/actions.sh"
require_executable "scripts/tools.sh"
require_executable "scripts/hub.sh"
require_executable "scripts/about.sh"
require_executable "scripts/lifecycle.sh"
require_executable "scripts/update.sh"
require_executable "scripts/recovery.sh"
require_executable "scripts/health.sh"
require_executable "scripts/support.sh"
require_executable "scripts/product.sh"
require_executable "scripts/foundations.sh"
require_executable "scripts/platform.sh"
require_executable "scripts/channel.sh"
require_executable "scripts/mask.sh"
require_executable "scripts/surfaces.sh"
require_executable "scripts/routes.sh"
require_executable "scripts/distribution.sh"
require_executable "profiles/profile-manager.sh"
require_executable "scripts/installer-stack.sh"
require_executable "scripts/store.sh"
require_executable "scripts/box.sh"
require_executable "scripts/cloud.sh"
require_executable "scripts/flow.sh"
require_executable "scripts/cluster.sh"
require_executable "scripts/flatpak.sh"
require_executable "scripts/ecosystem.sh"
require_executable "scripts/stack.sh"
require_executable "scripts/shell.sh"
require_executable "scripts/core.sh"
require_executable "scripts/identity.sh"
require_executable "scripts/experience.sh"
require_executable "scripts/adaptive-ui.sh"
require_executable "scripts/control-plane.sh"
require_executable "scripts/daily-driver.sh"
require_executable "scripts/events.sh"
require_executable "scripts/insights.sh"
require_executable "scripts/ai.sh"
require_executable "security/shield-status.sh"
require_executable "security/shield-control.sh"
require_executable "security/shield-workspace.sh"
require_executable "security/cyberspace.sh"
require_executable "scripts/manifest.sh"
require_executable "scripts/package-plan.sh"
require_executable "scripts/migrate.sh"
require_executable "scripts/migrate-from-ml4w.sh"
require_executable "scripts/keyboard.sh"
require_executable "seven-hub/gui-stack.sh"
require_executable "scripts/repair.sh"
require_executable "scripts/system-repair.sh"
require_executable "scripts/post-install.sh"
require_executable "scripts/design-check.sh"
require_executable "scripts/visual-packages.sh"
require_executable "scripts/hypr-ecosystem.sh"
require_executable "scripts/hypr-lua.sh"
require_executable "scripts/hypr-lua-events.sh"
require_executable "scripts/install-glaze-local.sh"
require_executable "scripts/install-hyprsysteminfo.sh"
require_executable "scripts/wallpaper-theme.sh"
require_executable "scripts/smart-window.sh"
require_executable "scripts/fonts.sh"
require_executable "scripts/network.sh"
require_executable "scripts/system-profile.sh"

package_manifest_contains "mako" "scripts/packages-base.txt"
package_manifest_contains "swaync" "scripts/packages-base.txt"
package_manifest_contains "libnotify" "scripts/packages-base.txt"
package_manifest_contains "swaylock" "scripts/packages-base.txt"
package_manifest_contains "swayidle" "scripts/packages-base.txt"
package_manifest_contains "hypridle" "scripts/packages-base.txt"
package_manifest_contains "hyprlock" "scripts/packages-base.txt"
package_manifest_contains "hyprpaper" "scripts/packages-base.txt"
package_manifest_contains "socat" "scripts/packages-base.txt"
package_manifest_contains "hyprpicker" "scripts/packages-hypr-ecosystem.txt"
package_manifest_contains "hyprsunset" "scripts/packages-hypr-ecosystem.txt"
package_manifest_contains "matugen" "scripts/packages-hypr-ecosystem.txt"
package_manifest_contains "glaze" "scripts/packages-hypr-ecosystem.txt"
package_manifest_contains "wallust" "scripts/packages-hypr-ecosystem-aur.txt"
package_manifest_contains "hyprsysteminfo" "scripts/packages-hypr-ecosystem-aur.txt"
package_manifest_contains "criu" "scripts/packages-runtime-optional.txt"
package_manifest_contains "wlogout" "scripts/packages-visual-aur.txt"
package_manifest_contains "librsvg" "scripts/packages-base.txt"
package_manifest_contains "fontconfig" "scripts/packages-base.txt"
package_manifest_contains "7zip" "scripts/packages-base.txt"
package_manifest_contains "inter-font" "scripts/packages-base.txt"
package_manifest_contains "ttf-jetbrains-mono-nerd" "scripts/packages-base.txt"
package_manifest_contains "noto-fonts" "scripts/packages-base.txt"
package_manifest_contains "noto-fonts-extra" "scripts/packages-base.txt"
package_manifest_contains "noto-fonts-cjk" "scripts/packages-base.txt"
package_manifest_contains "noto-fonts-emoji" "scripts/packages-base.txt"
package_manifest_contains "kitty" "scripts/packages-base.txt"
package_manifest_contains "python-gobject" "scripts/packages-base.txt"
package_manifest_contains "vte3" "scripts/packages-base.txt"
package_manifest_contains "nautilus" "scripts/packages-base.txt"
package_manifest_contains "gvfs" "scripts/packages-base.txt"
package_manifest_contains "gvfs-mtp" "scripts/packages-base.txt"
package_manifest_contains "gvfs-smb" "scripts/packages-base.txt"
package_manifest_contains "file-roller" "scripts/packages-base.txt"
package_manifest_contains "sushi" "scripts/packages-base.txt"
package_manifest_contains "ffmpegthumbnailer" "scripts/packages-base.txt"
package_manifest_contains "poppler" "scripts/packages-base.txt"
package_manifest_contains "xdg-user-dirs" "scripts/packages-base.txt"
package_manifest_contains "xdg-utils" "scripts/packages-base.txt"
package_manifest_contains "desktop-file-utils" "scripts/packages-base.txt"
package_manifest_contains "adw-gtk-theme" "scripts/packages-base.txt"
package_manifest_contains "qt5ct" "scripts/packages-base.txt"
package_manifest_contains "qt6ct" "scripts/packages-base.txt"
package_manifest_contains "kvantum" "scripts/packages-base.txt"
package_manifest_contains "kvantum-qt5" "scripts/packages-base.txt"
package_manifest_contains "nwg-look" "scripts/packages-base.txt"
package_manifest_contains "sassc" "scripts/packages-base.txt"
package_manifest_contains "flatpak" "scripts/packages-base.txt"
package_manifest_contains "btop" "scripts/packages-base.txt"
package_manifest_contains "pavucontrol" "scripts/packages-base.txt"
package_manifest_contains "networkmanager" "scripts/packages-base.txt"
package_manifest_contains "networkmanager" "scripts/packages-network.txt"
package_manifest_contains "network-manager-applet" "scripts/packages-base.txt"
package_manifest_contains "network-manager-applet" "scripts/packages-network.txt"
package_manifest_contains "nm-connection-editor" "scripts/packages-base.txt"
package_manifest_contains "nm-connection-editor" "scripts/packages-network.txt"
package_manifest_contains "wpa_supplicant" "scripts/packages-base.txt"
package_manifest_contains "wpa_supplicant" "scripts/packages-network.txt"
package_manifest_contains "iwd" "scripts/packages-base.txt"
package_manifest_contains "iwd" "scripts/packages-network.txt"
package_manifest_contains "iw" "scripts/packages-base.txt"
package_manifest_contains "iw" "scripts/packages-network.txt"
package_manifest_contains "wireless-regdb" "scripts/packages-base.txt"
package_manifest_contains "wireless-regdb" "scripts/packages-network.txt"
package_manifest_contains "networkmanager-openvpn" "scripts/packages-base.txt"
package_manifest_contains "networkmanager-openvpn" "scripts/packages-network.txt"
package_manifest_contains "modemmanager" "scripts/packages-base.txt"
package_manifest_contains "modemmanager" "scripts/packages-network.txt"
package_manifest_contains "usb_modeswitch" "scripts/packages-base.txt"
package_manifest_contains "usb_modeswitch" "scripts/packages-network.txt"
package_manifest_contains "mobile-broadband-provider-info" "scripts/packages-base.txt"
package_manifest_contains "mobile-broadband-provider-info" "scripts/packages-network.txt"
package_manifest_contains "bluez" "scripts/packages-base.txt"
package_manifest_contains "bluez-utils" "scripts/packages-base.txt"
package_manifest_contains "blueman" "scripts/packages-base.txt"
package_manifest_contains "foliate" "scripts/packages-culture.txt"
package_manifest_contains "translate-shell" "scripts/packages-culture.txt"
package_manifest_contains "gamescope" "scripts/packages-performance-optional.txt"
package_manifest_contains "mangohud" "scripts/packages-performance-optional.txt"
package_manifest_contains "archinstall" "scripts/packages-installer.txt"
package_manifest_contains "rust" "scripts/packages-hub-gui.txt"
package_manifest_contains "nodejs" "scripts/packages-hub-gui.txt"
package_manifest_contains "npm" "scripts/packages-hub-gui.txt"
package_manifest_contains "webkit2gtk-4.1" "scripts/packages-hub-gui.txt"
package_manifest_contains "gtk4" "scripts/packages-hub-gui.txt"
package_manifest_contains "libadwaita" "scripts/packages-hub-gui.txt"
package_manifest_contains "python-gobject" "scripts/packages-hub-gui.txt"
package_manifest_contains "gjs" "scripts/packages-shell-ags.txt"
package_manifest_contains "typescript" "scripts/packages-shell-ags.txt"
package_manifest_contains "gtk4" "scripts/packages-shell-ags.txt"
package_manifest_contains "libadwaita" "scripts/packages-shell-ags.txt"

if [[ "$FAST_MODE" == "1" ]]; then
  tools_json="$(capture_with_timeout 12 env SEVENOS_ROOT="$ROOT_DIR" "$ROOT_DIR/scripts/tools.sh" doctor --json)"
  if python -m json.tool >/dev/null <<<"$tools_json" &&
     grep -q '"schema": "sevenos.tools.v1"' <<<"$tools_json" &&
     grep -q '"state": "ready"' <<<"$tools_json"; then
    ok "SevenOS Tools quick contract is ready"
  else
    fail "SevenOS Tools quick contract should be ready"
  fi

  design_log="$(mktemp)"
  if timeout 35s env SEVENOS_ROOT="$ROOT_DIR" "$ROOT_DIR/scripts/design-check.sh" >"$design_log" 2>&1; then
    ok "Design coherence quick gate passed"
  else
    cat "$design_log" >&2
    fail "Design coherence quick gate should pass"
  fi
  rm -f "$design_log"
  finish_checks
fi

if jq -e '."custom/sevenos"."on-click" == "seven-waybar-action sevenos-menu"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar SevenOS click opens system menu"
else
  fail "Waybar SevenOS click does not open system menu"
fi

if jq -e '."custom/sevenos".exec == "seven-waybar-status sevenos" and ."custom/sevenos"."return-type" == "json" and ."custom/sevenos".tooltip == true' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar SevenOS brand stays simple and public-facing"
else
  fail "Waybar SevenOS brand should stay simple and public-facing"
fi

if jq -e '.height == 30 and .spacing == 4 and ."margin-top" == 0 and ."margin-left" == 0 and ."margin-right" == 0 and ."gtk-layer-shell" == true and ."modules-left" == ["custom/sevenos","custom/recorder","hyprland/window","custom/app-file","custom/app-edit","custom/app-view","custom/app-extra","custom/app-more","custom/app-tools","custom/app-window","custom/app-help"] and ."hyprland/window".format == "{class}" and ."hyprland/window"."max-length" == 18 and ."custom/app-file".exec == "seven-waybar-status app-menu-item file" and ."custom/app-file"."on-click" == "seven-waybar-action app-file" and ."custom/app-edit"."on-click" == "seven-waybar-action app-edit" and ."custom/app-view"."on-click" == "seven-waybar-action app-view" and ."custom/app-extra"."on-click" == "seven-waybar-action app-extra" and ."custom/app-more".exec == "seven-waybar-status app-menu-more" and ."custom/app-more"."on-click" == "seven-waybar-action app-menu" and ."custom/app-tools"."on-click" == "seven-waybar-action app-tools" and ."custom/app-window"."on-click" == "seven-waybar-action app-window" and ."custom/app-help"."on-click" == "seven-waybar-action app-help" and ."custom/sevenos".exec == "seven-waybar-status sevenos" and ."custom/sevenos"."return-type" == "json" and ."custom/sevenos"."on-click-right" == "seven-profile-center-native" and ."custom/sevenos"."on-click-middle" == "seven-spotlight field" and ."modules-center" == ["hyprland/workspaces"] and ."modules-right" == ["custom/profile","custom/media","custom/system-status","custom/wifi","custom/bluetooth","custom/spotlight","clock","custom/control-center"] and ."custom/system-status".exec == "seven-waybar-status system-status" and ."custom/system-status"."return-type" == "json" and ."custom/system-status"."on-click" == "seven-quick-settings" and ."custom/spotlight".format == "󰍉" and (."custom/spotlight"."tooltip-format" | contains("Spotlight")) and ."custom/spotlight"."on-click" == "seven-spotlight field" and ."hyprland/workspaces".format == "{icon}" and ."hyprland/workspaces"."format-icons"."1" == "1" and .tray."icon-size" == 14 and ."custom/control-center".exec == "seven-waybar-status control-center" and ."custom/control-center"."return-type" == "json" and ."custom/control-center"."on-click" == "seven-quick-settings" and ."custom/control-center"."on-click-right" == "seven-settings" and ."custom/wifi".exec == "seven-waybar-status wifi" and ."custom/bluetooth".exec == "seven-waybar-status bluetooth" and ."custom/media".exec == "seven-waybar-status media" and ."custom/vpn".exec == "seven-waybar-status vpn" and (."custom/recorder".exec | contains("seven-waybar-status") and contains("recorder")) and ."custom/recorder".format == "{}" and ."custom/recorder".interval == 2 and .pulseaudio.format == "󰕾" and (.battery.format | contains("{capacity}%")) and (. | has("cpu") | not) and (. | has("memory") | not)' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar exposes premium SevenOS search, spaces and essential controls"
else
  fail "Waybar premium search, workspace or essential control layout missing"
fi

waybar_limits_json="$(SEVENOS_ROOT="$ROOT_DIR" XDG_CONFIG_HOME="$(mktemp -d)" "$ROOT_DIR/bin/seven-waybar" limits --json)"
waybar_doctor_json="$(SEVENOS_ROOT="$ROOT_DIR" XDG_CONFIG_HOME="$(mktemp -d)" "$ROOT_DIR/bin/seven-waybar" doctor --json)"
if python -m json.tool <<<"$waybar_limits_json" >/dev/null &&
   python -m json.tool <<<"$waybar_doctor_json" >/dev/null &&
   python -c 'import json,sys; data=json.load(sys.stdin); checks={item["id"]: item["state"] for item in data.get("checks", [])}; required={"module-count","polling-budget","json-contracts","no-min-width-transition","recorder-fixed-width","workspace-fixed-width","profile-fixed-width","app-menu-fixed-slots","app-menu-hidden-collapse"}; raise SystemExit(0 if data.get("state")=="OK" and required <= set(checks) and all(checks[item]=="OK" for item in required) else 1)' <<<"$waybar_limits_json" &&
   python -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data.get("schema")=="sevenos.waybar.doctor.v1" and data.get("limits", {}).get("state")=="OK" else 1)' <<<"$waybar_doctor_json" &&
   grep -q 'seven-waybar limits --json' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'seven-waybar limits --json' "$ROOT_DIR/bin/seven-help-native" &&
   grep -q 'seven-waybar doctor --json' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'seven-waybar doctor --json' "$ROOT_DIR/bin/seven-help-native" &&
   grep -q 'min-width: 58px' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-app-file' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q 'min-width: 42px' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-app-extra.hidden' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#workspaces button' "$ROOT_DIR/hyprland/waybar/style.css" &&
   grep -q '#custom-recorder.idle' "$ROOT_DIR/hyprland/waybar/style.css" &&
   ! grep -q 'min-width 180ms' "$ROOT_DIR/hyprland/waybar/style.css"; then
  ok "Waybar dynamic limits keep the navigation bar stable and fluid"
else
  fail "Waybar dynamic limits should keep width, polling and JSON modules stable"
fi

if grep -q '@theme "sevenos.rasi"' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'seven-blue: #4DA3FF' "$ROOT_DIR/hyprland/rofi/sevenos.rasi" &&
   grep -q 'fullscreen: true' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'SevenLaunchpadNative' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'from seven_i18n import tr_text' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'current_theme_mode' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'icon_theme_name' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'CACHE_FILE' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'read_cached_apps' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'refresh_apps_async' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'dedupe_apps' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'launchpad_doctor_payload' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'MINI_OS_WORLDS' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'launchpad-world-card' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'refresh_world_cards' "$ROOT_DIR/bin/seven-launchpad-native" &&
	   grep -q 'RECENTS_FILE' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'LOCAL_ICON_FILES' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'app_icon_image' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'seven-baobab' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'seven-baobab.svg' "$ROOT_DIR/identity/icons/manifest.json" &&
   grep -q 'enter_modal_submap' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'leave_modal_submap' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'window.fullscreen()' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'window.set_modal(True)' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'window.set_accept_focus(True)' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'launchpad-stage' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'stage.put(root, 0, 0)' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'stage.move(root, max(0, (width - panel_width) // 2), max(0, (height - panel_height) // 2))' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'stage.set_size_request(width, height)' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'root.set_halign(Gtk.Align.CENTER)' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'root.set_valign(Gtk.Align.CENTER)' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'apply_responsive_layout' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'configure-event' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'windowrule = match:class ^(SevenLaunchpadNative)$, fullscreen on' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'windowrule = match:class ^(seven-launchpad-native)$, fullscreen on' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'windowrule = match:title ^(SevenOS Launchpad)$, fullscreen on' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'submap = sevenos-launchpad' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'submap = sevenos-launchpad' "$ROOT_DIR/hyprland/conf/sevenos-lua-generated.conf" &&
   grep -q 'PREFS_FILE' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'fuzzy_score' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'launchpad-filter' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'menu_for_app' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'close_existing_launchpad' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'acquire_launchpad_lock' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'LOCK_FILE' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'fcntl.LOCK_EX' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'close_existing_launchpad' "$ROOT_DIR/bin/seven-apps" &&
   grep -q 'closewindow' "$ROOT_DIR/bin/seven-apps" &&
   grep -q 'flow.set_max_children_per_line(columns)' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'set_pixel_size(76)' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'columns: 7' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'element-icon' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'size: 84px' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'placeholder: "Search"' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'spacing: 58px' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   ! grep -RE '#[0-9a-fA-F]{8}\b' "$ROOT_DIR/hyprland/rofi" >/dev/null &&
   grep -q 'gtk-application-prefer-dark-theme=true' "$ROOT_DIR/hyprland/gtk-3.0/settings.ini" &&
   grep -q 'icon_theme=Papirus' "$ROOT_DIR/hyprland/qt6ct/qt6ct.conf"; then
  ok "App launcher and toolkit themes use futuristic dark glass SevenOS identity"
else
  fail "Theme coherence is incomplete across launcher and toolkits"
fi

if grep -q 'bind = $mod, E, exec, seven-files' "$ROOT_DIR/hyprland/conf/sevenos-lua-generated.conf" &&
   grep -q 'seven-files menu' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua"; then
  ok "Hyprland exposes Seven Files shortcuts"
else
  fail "Seven Files shortcuts missing"
fi

if grep -q 'gtk-decoration-layout=close,minimize,maximize:' "$ROOT_DIR/hyprland/gtk-4.0/settings.ini" &&
   grep -q 'window.nautilus-window headerbar' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" &&
   grep -q 'placessidebar row:selected' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" &&
   grep -q 'SevenFilesNative' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-sidebar' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'traffic-row' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'draw_dot_symbol' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'activate_dot' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'minimize_window' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'toggle_zoom_or_tile' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-preview' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-statusbar' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'open_quicklook_preview' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'inline_media_player' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gst.ElementFactory.make("playbin"' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gst.ElementFactory.make("gtksink"' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'media-inline' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'seek_simple' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'show_context_menu' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Set as Wallpaper' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'selected-children-changed' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'set_max_children_per_line(4)' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Click selects · Double-click opens' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'set_homogeneous(True)' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'EllipsizeMode.MIDDLE' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'file-tile-box' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'copy_items' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'paste_items' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'publish_file_clipboard' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'write_clipboard_cache' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'text/uri-list' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'read_system_file_clipboard' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'x-special/gnome-copied-files' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'compress_paths' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'ask_archive_options' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'ARCHIVE_FORMATS' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'tarfile.open' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Compress' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'new_from_file_at_scale' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'VIDEO_SUFFIXES' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'DOCUMENT_SUFFIXES' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'TEXT_SUFFIXES' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'read_docx_preview' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'ffmpegthumbnailer' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'pdftoppm' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'SevenQuickLook' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'read_theme_mode' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'read_icon_theme' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'read_active_profile' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'READER_SUFFIXES' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'open_in_reader' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'global_search' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'build_global_index' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'GLOBAL_INDEX_DB' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'sqlite3.connect' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'refresh_global_index' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'INDEX_LIMIT' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'run_background' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'operation_progress_update' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'operation_cancel_requested' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'OPERATION_CANCELLED' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'show_ai_result' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'tag-pill' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'inspector-card' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'adapt_layout' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'theme_css' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'seven_theme.gtk_app_css("files"' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'search_entry = Gtk.Entry()' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'EntryIconPosition.SECONDARY' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'search_render_state' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'location-entry' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'show_location_entry' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'commit_location_entry' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'press_feedback' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'release_feedback' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'flash_tile' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'status-flash' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'CLICK_FEEDBACK_MS' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'sort_entries' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'breadcrumb-button' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'SelectionMode.MULTIPLE' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gtk.Overlay' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'rubberband' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'on_flow_motion' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'select_children_in_rect' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'rects_intersect' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'SPRING_OPEN_DELAY_MS' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'schedule_spring_open' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'cancel_spring_open' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'spring-armed' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'HOVER_PREVIEW_DELAY_MS' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'schedule_hover_preview' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'hover-preview' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'current_grid_columns' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'RENDER_CHUNK_SIZE' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'render_chunk' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'selection_anchor' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'selected_paths' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'setup_file_tile_dnd' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'setup_current_drop_target' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'on_file_drop' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'on_sidebar_drop' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'drag_source_set' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'drag_dest_set' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'URI_LIST_TARGET' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'tag_paths' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'sevenai_selected' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'mounted_locations' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gio.VolumeMonitor.get' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'navigate_uri_or_path' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'TRASH_INFO_DIR' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Restore from Trash' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'trashinfo' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'THUMB_CACHE' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'thumbnail_cache_path' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'RENDER_LIMIT' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'safe_open_path' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'is_risky_file' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Copy SHA256' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'AUDIO_SUFFIXES' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'set_view_mode' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'list-view' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'compact-view' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'create_folder' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'rename_path' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'duplicate_path' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'trash_path' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_space' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_Delete' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_F2' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_a' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_f' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_l' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_h' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_i' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_t' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_w' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_d' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-tabbar' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'render_tabs' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'new_tab' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'close_tab' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'show_history_menu' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'files-split' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'render_split' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'copy_selected_to_split' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'operation-queue' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'operation_history' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'file_matches_query' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'empty-state' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'add_empty_state' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'type:image' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Batch Rename' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'profile_action' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'FAVORITES_CACHE' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'favorite_paths' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'render_favorite_rows' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Add to Favorites' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'show_tab_menu' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Duplicate Tab' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Open in New Tab' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Open in Split' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'open_path_in_split' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'show_breadcrumb_menu' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'create_file' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'New File' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_n' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'properties_dialog' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'human_mode' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'ask_conflict_policy' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'destination_for_policy' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Keep Both' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Connect to Server' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'seven://connect-server' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'PREFS_CACHE' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'RECENTS_CACHE' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'RECENTS_SENTINEL' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'toggle_hidden' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'recent_paths' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'remember_recent' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'move_keyboard_selection' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'Gdk.KEY_Left' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'flow.connect("key-press-event", on_key)' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q '_2BUTTON_PRESS' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK' "$ROOT_DIR/bin/seven-files-native" &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-files" open "$HOME" | grep -q 'native Seven Files surface' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-files" reader | grep -q 'Seven Reader immersive library' &&
   grep -q 'normalize_target' "$ROOT_DIR/bin/seven-files" &&
   grep -q 'configure_nautilus_preferences' "$ROOT_DIR/bin/seven-files" &&
   grep -q 'Exec=seven-files open %U' "$ROOT_DIR/seven-hub/seven-files.desktop" &&
   grep -q 'MimeType=inode/directory' "$ROOT_DIR/seven-hub/seven-files.desktop" &&
   grep -q 'xdg-mime default seven-files.desktop inode/directory' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'default-folder-viewer' "$ROOT_DIR/bin/seven-files" &&
   grep -q 'nautilus --new-window' "$ROOT_DIR/bin/seven-files" &&
   grep -q 'screen_window_size' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'runtime_sidebar_visible' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'runtime_preview_visible' "$ROOT_DIR/bin/seven-files-native" &&
   grep -q 'windowrule = match:class ^(SevenFilesNative)$, float on, center on, size 700 500' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'windowrule = match:title ^(Seven Files)$, float on, center on, size 700 500' "$ROOT_DIR/hyprland/lua/rules/windows.lua"; then
  ok "Seven Files is shaped as a native SevenOS file surface"
else
  fail "Seven Files shell integration is incomplete"
fi

if [[ -x "$ROOT_DIR/bin/seven-power" ]] && grep -q 'seven-power' "$ROOT_DIR/bin/seven-waybar-action"; then
  ok "SevenOS power controls remain available outside the minimal Waybar"
else
  fail "SevenOS power controls should remain available outside the minimal Waybar"
fi

if grep -q 'SevenReaderNative' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'SUPPORTED_SUFFIXES' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'pdf_page_png' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'epub_text' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'cbz_pages' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'book-spread' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'paper-page' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'reader-search' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'ANNOTATIONS_PATH' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'search_document' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'toggle_bookmark' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'add_note_dialog' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'reader-sidebar' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'toggle_focus' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'preload_pages' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'progress_scale' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'adjust_zoom' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'flip-active' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'SevenAI Reading Companion' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'Exec=seven-reader open %F' "$ROOT_DIR/seven-hub/seven-reader.desktop" &&
   grep -q 'MimeType=application/pdf;application/epub+zip;text/markdown;text/plain;application/vnd.comicbook+zip;application/x-cbz;' "$ROOT_DIR/seven-hub/seven-reader.desktop" &&
   grep -q 'xdg-mime default seven-reader.desktop application/pdf' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'install_user_command "$ROOT_DIR/bin/seven-reader" seven-reader' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'reader.open' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'windowrule = match:class ^(SevenReaderNative)$, float on, center on, size 1220 760' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-files" read "$ROOT_DIR/README.md" | grep -q 'Seven Reader immersive surface' &&
   "$ROOT_DIR/bin/seven-reader-native" --json | python -m json.tool >/dev/null; then
  ok "Seven Reader is integrated as an immersive native reading surface"
else
  fail "Seven Reader integration is incomplete"
fi

store_browser_json="$("$ROOT_DIR/scripts/store.sh" search browser --json)"
store_navigator_json="$("$ROOT_DIR/scripts/store.sh" search navigateur --json)"
store_music_json="$("$ROOT_DIR/scripts/store.sh" search musique --json)"
store_games_json="$("$ROOT_DIR/scripts/store.sh" search jeux --json)"
store_pacman_profile_plan="$("$ROOT_DIR/scripts/store.sh" install-app pacman firefox --profile forge --dry-run)"
store_pacman_profile_plan_json="$("$ROOT_DIR/scripts/store.sh" plan-app pacman firefox --profile forge --json)"
store_aur_profile_plan="$("$ROOT_DIR/scripts/store.sh" install-app aur visual-studio-bin --profile forge --dry-run)"
store_aur_profile_plan_json="$("$ROOT_DIR/scripts/store.sh" plan-app aur visual-studio-bin --profile forge --json)"

if grep -q 'SevenStoreNative' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'sevenos.package-engine.v1' "$ROOT_DIR/scripts/store.sh" &&
   grep -q 'plan-app)' "$ROOT_DIR/scripts/store.sh" &&
   grep -q ' plan-app ' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'CURATED_APPS' "$ROOT_DIR/scripts/store.sh" &&
   grep -q 'curated_results' "$ROOT_DIR/scripts/store.sh" &&
   grep -q '"suggestions"' "$ROOT_DIR/scripts/store.sh" &&
   grep -q 'Exec=seven-store open' "$ROOT_DIR/seven-hub/seven-store.desktop" &&
   grep -q 'Icon=seven-store' "$ROOT_DIR/seven-hub/seven-store.desktop" &&
   grep -q 'launch_environment' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'launch_desktop_exec' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'on_tile_click' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'Install on system' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'Install for' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'Install on Equinox' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'profile_first' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'Browser' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'install_command_for' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'record_profile_app' "$ROOT_DIR/scripts/store.sh" &&
   grep -q '"curated": true' <<<"$store_browser_json" &&
   grep -q '"beginner_visible": true' <<<"$store_browser_json" &&
   grep -q '"expanded_query": "browser"' <<<"$store_navigator_json" &&
   grep -q '"name": "Firefox"' <<<"$store_navigator_json" &&
   grep -Eq '"name": "VLC"|"name": "Spotify"' <<<"$store_music_json" &&
   grep -Eq '"name": "Steam"|"name": "Lutris"' <<<"$store_games_json" &&
   grep -q 'profile: forge' <<<"$store_pacman_profile_plan" &&
   grep -q 'profile-rootfs' <<<"$store_pacman_profile_plan_json" &&
   grep -q 'sevenpkg forge install firefox --source pacman' <<<"$store_pacman_profile_plan" &&
   grep -q 'sevenpkg forge helper paru' <<<"$store_aur_profile_plan" &&
   grep -q 'sevenpkg forge install visual-studio-bin --source aur' <<<"$store_aur_profile_plan" &&
   grep -Eq '"source"[[:space:]]*:[[:space:]]*"(paru|yay|aur)"' <<<"$store_aur_profile_plan_json" &&
   grep -q 'install_user_command "$ROOT_DIR/bin/seven-store" seven-store' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'install_user_command "$ROOT_DIR/bin/seven-store-native" seven-store-native' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'write_command_wrapper "$BIN_HOME/seven-store" "$ROOT_DIR/bin/seven-store"' "$ROOT_DIR/seven-hub/install.sh" &&
   "$ROOT_DIR/bin/seven-store-native" --probe >/dev/null &&
   "$ROOT_DIR/bin/seven-store-native" --json | python -m json.tool >/dev/null; then
  ok "SevenStore is launchpad-accessible as a native AppCenter"
else
  fail "SevenStore Launchpad integration is incomplete"
fi

if grep -q 'bind = $mod, D, exec, $dock' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q '$dock = seven-dock toggle' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'SevenDockCanvas|SevenDockNative' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   ! grep -q 'SevenDockNative.*size 540 82' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'seven-dock-canvas' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'SEVENOS_DOCK_RENDERER=canvas|native' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'smooth-neighbor-magnification' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'magnetic-focus' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'smooth-slide-reveal' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'spring-motion' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'direct-native-spotlight' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q '"command": \["seven-spotlight-native", "--mode", "all"\]' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'centered-icons' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'anchored-window-preview' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'scroll-window-cycle' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'folder-stacks' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'drag-reorder' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'restart|repair|reopen' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'limits|doctor' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'active_profile()' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'scope=closing-on-profile-change' "$ROOT_DIR/bin/seven-dock" &&
   ! grep -q 'SEVENOS_DOCK_FORCE_WINDOW=1' "$ROOT_DIR/bin/seven-dock" &&
   grep -q '"reserve_space": false' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'from seven_i18n import tr_text' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'set_namespace(window, "sevenos-dock")' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'GtkLayerShell.Layer.OVERLAY' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'SEVENOS_DOCK_FORCE_WINDOW' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'GtkLayerShell.set_exclusive_zone(window, dock_height + DOCK_MARGIN if reserve_space else 0)' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q '"reserve_space": True' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q '"exclusive_zone": height + DOCK_MARGIN if reserve_space else 0' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'place_hyprland_window' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock_dimensions' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock_limits_payload' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'PROFILE_PINNED' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'CLASS_TILE_HINTS' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'hyprland_clients' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'clients_by_tile' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'focus_tile_window' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'tile_groups' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock-instance-badge' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'on_tile_key' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'setup_tile_dnd' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'DOCK_TILE_TARGET' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'URI_LIST_TARGET' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'move_tile_to_target' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'handle_file_drop' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'file-drop-open' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'hover-window-preview' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'show_window_preview' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'dock-preview-row' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'spring-loaded-folders' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'animated-autohide' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'press-launch-feedback' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'drag-target-feedback' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'DOCK_FADE_STEP_MS' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'animate_dock_opacity' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'flash_tile' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'animate_launch_feedback' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'launch-feedback' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'drag-target' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'spring-armed' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'SPRING_LOADED_DELAY_MS' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'spring_open_folder' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'drag-motion' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'move_pinned' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'window.set_opacity(0.18 if autohide else 1.0)' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'active_profile_key' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'write_dock_state' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'enforce_profile_scope' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'visible-on-all-workspaces-until-profile-change' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'window.set_accept_focus(False)' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'monitor_width - DOCK_MARGIN \* 2' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'if not dock.get("pinned")' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'movewindowpixel' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'window.present()' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'set_anchor(window, GtkLayerShell.Edge.LEFT, True)' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'pin)' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'unpin)' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'autohide)' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'effect <magnetic|gentle|none>' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'autohide_delay' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'settings-dock-controls' "$ROOT_DIR/bin/seven-dock-canvas" &&
   grep -q 'def dock_settings_group' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'show_context_menu' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'process_running' "$ROOT_DIR/bin/seven-dock-native" &&
   "$ROOT_DIR/bin/seven-dock" limits | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-dock" toggle | grep -q 'DRY-RUN > Dock >'; then
  ok "SevenOS Dock toggles with Super+D and exposes workflow actions"
else
  fail "SevenOS Dock should toggle with Super+D and expose workflow actions"
fi

if jq -e '."custom/sevenos"."on-click" == "seven-waybar-action sevenos-menu" and ."custom/sevenos"."on-click-right" == "seven-profile-center-native" and ."custom/sevenos"."on-click-middle" == "seven-spotlight field" and ."hyprland/window".format == "{class}" and ."hyprland/window"."max-length" == 18 and ."custom/app-file"."on-click" == "seven-waybar-action app-file" and ."custom/app-edit"."on-click" == "seven-waybar-action app-edit" and ."custom/app-view"."on-click" == "seven-waybar-action app-view" and ."custom/app-extra"."on-click" == "seven-waybar-action app-extra" and ."custom/app-more".exec == "seven-waybar-status app-menu-more" and ."custom/app-more"."on-click" == "seven-waybar-action app-menu" and ."custom/app-tools"."on-click" == "seven-waybar-action app-tools" and ."custom/app-window"."on-click" == "seven-waybar-action app-window" and ."custom/app-help"."on-click" == "seven-waybar-action app-help" and ."custom/system-status".exec == "seven-waybar-status system-status" and ."custom/system-status"."on-click" == "seven-quick-settings" and ."custom/system-status"."on-click-right" == "seven-settings" and ."custom/profile".exec == "seven-waybar-status profile" and ."custom/mini-context".exec == "seven-waybar-status mini-context" and ."custom/mini-context"."on-click" == "seven-waybar-action mini-context" and ."custom/experience".exec == "seven-waybar-status experience" and ."custom/experience"."return-type" == "json" and ."custom/experience"."on-click" == "seven experience warmup" and ."custom/experience"."on-click-right" == "seven experience events" and ."custom/experience"."on-click-middle" == "seven experience recommend" and ."custom/wifi"."on-click" == "seven-quick-settings wifi" and ."custom/wifi"."on-click-right" == "seven-quick-settings" and ."custom/wifi"."on-click-middle" == "seven-wifi toggle" and ."custom/wifi"."return-type" == "json" and ."custom/bluetooth"."on-click" == "seven-quick-settings bluetooth" and ."custom/bluetooth"."on-click-middle" == "seven-bluetooth toggle" and ."custom/bluetooth"."return-type" == "json" and .pulseaudio."on-click" == "seven-quick-settings audio" and .pulseaudio."on-click-right" == "seven-quick-settings" and .pulseaudio."on-click-middle" == "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" and .pulseaudio."on-scroll-up" == "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" and .pulseaudio."on-scroll-down" == "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" and .pulseaudio.format == "󰕾" and .pulseaudio.tooltip == false and .battery."on-click" == "seven-quick-settings power" and .battery."on-click-right" == "seven-quick-settings" and (.battery.format | contains("{capacity}%")) and .battery.tooltip == false and ."custom/vpn"."return-type" == "json" and ."custom/recorder"."return-type" == "json" and (."custom/recorder"."on-click" | contains("seven-recorder area")) and (."custom/recorder"."on-click-right" | contains("seven-recorder panel")) and (."custom/recorder"."on-click-middle" | contains("seven-recorder full")) and .clock.tooltip == false and .clock."on-click" == "seven-quick-settings time" and ."custom/control-center"."on-click" == "seven-quick-settings" and ."custom/control-center"."on-click-right" == "seven-settings" and ."custom/spotlight"."on-click" == "seven-spotlight field"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar modules expose actionable controls"
else
  fail "Waybar still has decorative modules without actions"
fi

if grep -q 'ExecStartPre=-/usr/bin/pkill -x waybar' "$ROOT_DIR/systemd/user/sevenos-waybar.service" &&
   grep -q 'sevenos-waybar.service' "$ROOT_DIR/bin/seven-waybar" &&
   grep -q 'pkill -u "$USER" -x waybar' "$ROOT_DIR/bin/seven-waybar"; then
  ok "SevenOS Waybar is singleton-managed"
else
  fail "SevenOS Waybar should be singleton-managed"
fi

wifi_menu_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-wifi" menu)"
wifi_connect_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-wifi" connect)"
if [[ -x "$ROOT_DIR/bin/seven-wifi" ]] &&
   grep -q 'network_label_rows' "$ROOT_DIR/bin/seven-wifi" &&
   grep -q 'connect_to_ssid' "$ROOT_DIR/bin/seven-wifi" &&
   grep -q 'DRY-RUN > Wi-Fi > Open panel' <<<"$wifi_menu_output" &&
   grep -q 'DRY-RUN > Wi-Fi > Connect' <<<"$wifi_connect_output" &&
   grep -q 'Turn Wi-Fi On / Off' <<<"$wifi_menu_output" &&
   grep -q 'Nearby Wi-Fi' <<<"$wifi_menu_output" &&
   "$ROOT_DIR/bin/seven-wifi" status-json | python -m json.tool >/dev/null; then
  ok "Waybar network module exposes a real Wi-Fi workflow"
else
  fail "Waybar network module should expose a real Wi-Fi workflow"
fi

if [[ -x "$ROOT_DIR/bin/seven-bluetooth" ]] &&
   "$ROOT_DIR/bin/seven-bluetooth" status-json | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven-waybar-status" bluetooth | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven-waybar-status" wifi | python -m json.tool >/dev/null &&
   timeout 8s "$ROOT_DIR/bin/seven-waybar-status" ai | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven-waybar-status" experience | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven-waybar-status" recorder | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven-waybar-status" vpn | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-bluetooth" toggle | grep -q 'DRY-RUN > Bluetooth > power' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-bluetooth" scan | grep -q 'DRY-RUN > Bluetooth > scan nearby devices' &&
   grep -q 'bluetooth_state' "$ROOT_DIR/bin/seven-waybar-center-native"; then
  ok "Waybar Bluetooth module exposes toggle, status and pairing workflow"
else
  fail "Waybar Bluetooth module should expose status, toggle and pairing workflow"
fi

notifications_menu_output="$(SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-notifications" menu)"
notifications_menu_fr="$(SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-notifications" menu)"
notifications_toggle_output="$(SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-notifications" toggle-dnd)"
if grep -q 'DRY-RUN > Notifications > Open panel' <<<"$notifications_menu_output" &&
   grep -Eq 'Aucune notification|Notification' <<<"$notifications_menu_fr" &&
   grep -q 'DRY-RUN > Notifications > Toggle Do Not Disturb' <<<"$notifications_toggle_output"; then
  ok "SevenOS notifications helper exposes menu and Do Not Disturb controls"
else
  fail "SevenOS notifications helper should expose menu and Do Not Disturb controls"
fi

profile_theme_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-profile-theme" apply)"
if SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-waybar-profile" | grep -Eq 'Equinox|Baobab|Forge|Shield|Studio|Windows|Pulse|Profiles|Profile' &&
   "$ROOT_DIR/bin/seven-waybar-status" profile | python -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("alt") and "profile-" in d.get("class","") else 1)' &&
   grep -Eq 'render (profile|[a-z]+ concept) Waybar|project Baobab Waybar' <<<"$profile_theme_output" &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-waybar-security" json | grep -q '󰒃' &&
   "$ROOT_DIR/bin/seven-profile-center-native" --probe >/dev/null 2>&1 &&
   "$ROOT_DIR/bin/seven-shield-center-native" --probe >/dev/null 2>&1 &&
   grep -q 'SevenProfileCenterNative' "$ROOT_DIR/bin/seven-profile-center-native" &&
   grep -q 'from seven_i18n import language_code, tr_text' "$ROOT_DIR/bin/seven-profile-center-native" &&
   grep -q 'SevenShieldCenterNative' "$ROOT_DIR/bin/seven-shield-center-native" &&
   grep -q 'Profile Center' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-profile-center-native' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-shield-center-native' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-waybar-center-native network' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-waybar-center-native bluetooth' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-waybar-center-native audio' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-media-menu-native' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-mini-context-menu-native' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-waybar-center-native power' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'native_panel seven-app-menu-native file' "$ROOT_DIR/bin/seven-waybar-action" &&
   "$ROOT_DIR/bin/seven-app-menu-native" --probe >/dev/null 2>&1 &&
   "$ROOT_DIR/bin/seven-media-menu-native" --probe >/dev/null 2>&1 &&
   "$ROOT_DIR/bin/seven-mini-context-menu-native" --probe >/dev/null 2>&1 &&
   "$ROOT_DIR/bin/seven-waybar-center-native" --probe >/dev/null 2>&1 &&
   grep -q 'SevenWaybarCenterNative' "$ROOT_DIR/bin/seven-waybar-center-native" &&
   grep -q 'SEVENOS_WAYBAR_CENTER_LEGACY' "$ROOT_DIR/bin/seven-waybar-center-native" &&
   grep -q 'seven-quick-settings-native' "$ROOT_DIR/bin/seven-waybar-center-native" &&
   grep -q 'Workspace' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'Settings' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'seven profile activate forge' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'clean_selection' "$ROOT_DIR/bin/seven-waybar-action" &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-action" system | grep -q 'DRY-RUN > System > Open panel'; then
  ok "Waybar profile indicator uses live SevenOS profile state"
else
  fail "Waybar profile indicator should use live SevenOS profile state"
fi

spotlight_cache="$(mktemp -d)"
spotlight_dry="$(XDG_CACHE_HOME="$spotlight_cache" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-spotlight" open)"
XDG_CACHE_HOME="$spotlight_cache" "$ROOT_DIR/bin/seven-spotlight" index >/dev/null
spotlight_catalog="$(XDG_CACHE_HOME="$spotlight_cache" "$ROOT_DIR/bin/seven-spotlight" catalog)"
if grep -q 'DRY-RUN > Spotlight > Open command center' <<<"$spotlight_dry" &&
   grep -q '/apps · Applications' <<<"$spotlight_catalog" &&
   grep -q '/files · Files' <<<"$spotlight_catalog" &&
   grep -q '/settings · Settings' <<<"$spotlight_catalog" &&
   grep -q '/system · System Actions' <<<"$spotlight_catalog" &&
   grep -q '/web · Web & Intelligence' <<<"$spotlight_catalog" &&
   grep -q '/clipboard · Clipboard' <<<"$spotlight_catalog" &&
   grep -q '/windows · Windows' <<<"$spotlight_catalog" &&
   grep -q '/history · Search History' <<<"$spotlight_catalog" &&
   [[ "$(XDG_CACHE_HOME="$spotlight_cache" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-spotlight" open apps | awk -F': ' '/entries:/ {print $2}')" -gt 0 ]] &&
   [[ "$(XDG_CACHE_HOME="$spotlight_cache" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-spotlight" open files | awk -F': ' '/entries:/ {print $2}')" -gt 0 ]] &&
   [[ "$(XDG_CACHE_HOME="$spotlight_cache" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-spotlight" open settings | awk -F': ' '/entries:/ {print $2}')" -gt 0 ]] &&
   [[ "$(XDG_CACHE_HOME="$spotlight_cache" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-spotlight" open system | awk -F': ' '/entries:/ {print $2}')" -gt 0 ]] &&
   [[ "$(XDG_CACHE_HOME="$spotlight_cache" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-spotlight" open web | awk -F': ' '/entries:/ {print $2}')" -gt 0 ]] &&
   grep -q 'Desktop · Open Seven Hub' <<<"$spotlight_catalog" &&
   grep -q 'App · ' <<<"$spotlight_catalog" &&
   grep -q 'Files · Home' <<<"$spotlight_catalog" &&
   grep -q 'Indexed · ' <<<"$spotlight_catalog" &&
   grep -q 'Mini OS · Baobab Immersion OS' <<<"$spotlight_catalog" &&
   grep -q 'Mini OS · Forge DevOps' <<<"$spotlight_catalog" &&
   grep -q 'Settings · Network' <<<"$spotlight_catalog" &&
   grep -q 'Mail · Open mail client' <<<"$spotlight_catalog" &&
   grep -q 'Contacts · Open address book' <<<"$spotlight_catalog" &&
   grep -q 'Calendar · Open events' <<<"$spotlight_catalog" &&
   grep -q 'Calculator · Type an expression' <<<"$spotlight_catalog" &&
   grep -q 'Converter · Type value and unit' <<<"$spotlight_catalog" &&
   grep -q 'Dictionary · Type "define word"' <<<"$spotlight_catalog" &&
   grep -q 'Web · Search the web' <<<"$spotlight_catalog" &&
   grep -q 'Quick Action · Start 5 minute timer' <<<"$spotlight_catalog" &&
   grep -q 'Quick Action · Record audio' <<<"$spotlight_catalog" &&
   grep -q 'Quick Action · Record screen' <<<"$spotlight_catalog" &&
   grep -q 'Ask · Prepare Cyber workspace' <<<"$spotlight_catalog" &&
   [[ "$("$ROOT_DIR/bin/seven-spotlight" eval '42*7')" == "42*7 = 294" ]] &&
   [[ "$("$ROOT_DIR/bin/seven-spotlight" eval '10 km to mi')" == "10 km = 6.21371 mi" ]] &&
   [[ "$("$ROOT_DIR/bin/seven-spotlight" eval '15% of 240')" == "15% of 240 = 36" ]] &&
   grep -q 'Search apps, files, windows, clipboard, actions' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'border-radius: 999px' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -q 'SevenSpotlightNative' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'category-button' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'category-label' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'current_theme_mode' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'spotlight_css' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'CACHE_FILE' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'read_cached_catalog' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'refresh_catalog_async' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'LOCK_FILE' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'fcntl.LOCK_EX' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'fuzzy_score' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'selected_index' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'result_box.set_visible(bool(matches))' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'seven-spotlight-native' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -Fq 'children: [ inputbar, message, listview ]' "$ROOT_DIR/hyprland/rofi/spotlight.rasi" &&
   grep -Fq 'children: [ inputbar, listview ]' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -Fq 'children: [ message, listview ]' "$ROOT_DIR/hyprland/rofi/hub.rasi" &&
   grep -Fq 'children: [ message, listview ]' "$ROOT_DIR/hyprland/rofi/quick-settings.rasi" &&
   ! grep -Eq 'inputbar|placeholder: "Search|filename: "search"' "$ROOT_DIR/hyprland/rofi/hub.rasi" &&
   ! grep -Eq 'inputbar|placeholder: "Search|filename: "search"' "$ROOT_DIR/hyprland/rofi/quick-settings.rasi" &&
   ! grep -Eq 'placeholder: "Search|filename: "search"' "$ROOT_DIR/hyprland/rofi/sevenos.rasi"; then
  ok "SevenOS Spotlight indexes apps, actions and contextual intents"
else
  fail "SevenOS Spotlight should index apps, actions and contextual intents"
fi
rm -rf "$spotlight_cache"

profile_activate_dry="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/profiles/profile-manager.sh" activate forge)"
profile_status_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile status --json)"
profile_apps_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile apps --json)"
profile_gaps_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile gaps --json)"
profile_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile plan --json)"
profile_health_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile health --json)"
profile_aliases_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile aliases --json)"
profile_migration_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile migrate-aliases --json)"
profile_guide_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile guide)"
profile_open_dry="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/profiles/profile-manager.sh" open forge)"
profile_bootstrap_dry="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/profiles/profile-manager.sh" bootstrap forge)"
if grep -q 'profile.json' <<<"$profile_activate_dry" &&
   grep -q 'seven profile migrate-aliases --apply' <<<"$profile_activate_dry" &&
   grep -q '"apps"' <<<"$profile_status_json" &&
   grep -q '"role"' <<<"$profile_status_json" &&
   grep -q '"principle"' <<<"$profile_status_json" &&
   grep -q '"story"' <<<"$profile_status_json" &&
   grep -q '"bootstrap_state"' <<<"$profile_status_json" &&
   grep -q '"runtime"' <<<"$profile_status_json" &&
   grep -q '"lifecycle"' <<<"$profile_status_json" &&
   grep -q '"manifest"' <<<"$profile_status_json" &&
   grep -q '"launcher"' <<<"$profile_status_json" &&
   grep -q 'CHECKLIST.md' <<<"$profile_bootstrap_dry" &&
   grep -q 'launch.sh' <<<"$profile_bootstrap_dry" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.profile-gaps.v1"' <<<"$profile_gaps_json" &&
   grep -q '"missing_packages"' <<<"$profile_gaps_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.profile-plan.v1"' <<<"$profile_plan_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.profile-health.v1"' <<<"$profile_health_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.profile-aliases.v1"' <<<"$profile_aliases_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.profile-migration.v1"' <<<"$profile_migration_json" &&
   grep -q '"isolation_ready"' <<<"$profile_health_json" &&
   grep -q '"alias_migration_pending"[[:space:]]*:[[:space:]]*0' <<<"$profile_health_json" &&
   grep -q '"redirects_to"[[:space:]]*:[[:space:]]*"forge"' <<<"$profile_aliases_json" &&
   grep -q '"pending"[[:space:]]*:[[:space:]]*0' <<<"$profile_migration_json" &&
   PROFILE_STATUS_JSON="$profile_status_json" python -c 'import json,os,sys; data=json.loads(os.environ["PROFILE_STATUS_JSON"]); keys=[item.get("key") for item in data]; raise SystemExit(0 if len(keys)==7 and "horizon" not in keys and "forge" in keys else 1)' &&
   grep -q '"next"' <<<"$profile_plan_json" &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile current --json | python -m json.tool >/dev/null &&
   grep -q '"command"' <<<"$profile_apps_json" &&
   grep -q 'Recommended actions' <<<"$profile_guide_output" &&
   grep -q 'seven-files open' <<<"$profile_open_dry"; then
  ok "SevenOS profile activation creates live workspaces, app readiness and next actions"
else
  fail "SevenOS profile activation should create workspaces, app readiness and next actions"
fi

actions_json="$("$ROOT_DIR/scripts/actions.sh" --json)"
actions_dry_run="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/actions.sh" run apps.open)"
actions_apps="$("$ROOT_DIR/scripts/actions.sh" category Apps)"
state_json="$(SEVENOS_UPDATE_FAST=1 SEVENOS_HEALTH_FAST=1 SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" state --json)"
if grep -q '"schema": "sevenos.actions.v1"' <<<"$actions_json" &&
   grep -q 'seven-overview apps' <<<"$actions_dry_run" &&
   grep -q 'sevenpkg.status' <<<"$actions_apps" &&
   grep -q 'welcome.plan' <<<"$actions_json" &&
   grep -q 'migrate.ml4w.plan' <<<"$actions_json" &&
   grep -q 'migrate.ml4w.switch' <<<"$actions_json" &&
   grep -q 'keyboard.status' <<<"$actions_json" &&
   grep -q 'keyboard.apply' <<<"$actions_json" &&
   grep -q 'session.status' <<<"$actions_json" &&
   grep -q 'identity.status' <<<"$actions_json" &&
   grep -q 'identity.plan' <<<"$actions_json" &&
   grep -q 'identity.design' <<<"$actions_json" &&
   grep -q 'identity.icons' <<<"$actions_json" &&
   grep -q 'identity.packs' <<<"$actions_json" &&
   grep -q '"design"' <<<"$state_json" &&
   grep -q '"icons"' <<<"$state_json" &&
   grep -q 'identity.current' <<<"$actions_json" &&
   grep -q 'security.dashboard' <<<"$actions_json" &&
   grep -q 'security.mode' <<<"$actions_json" &&
   grep -q 'security.hud' <<<"$actions_json" &&
   grep -q 'security.context.recon' <<<"$actions_json" &&
   grep -q 'security.bootstrap' <<<"$actions_json" &&
   grep -q 'security.workspace' <<<"$actions_json" &&
   grep -q 'security.scope' <<<"$actions_json" &&
   grep -q 'security.report' <<<"$actions_json" &&
   grep -q 'security.lab.forensics' <<<"$actions_json" &&
   grep -q 'daily.status' <<<"$actions_json" &&
   grep -q 'daily.apply' <<<"$actions_json" &&
   grep -q 'primary.status' <<<"$actions_json" &&
   grep -q 'primary.apply' <<<"$actions_json" &&
   grep -q 'ai.focus' <<<"$actions_json" &&
   grep -q 'ai.agent' <<<"$actions_json" &&
   grep -q 'ai.apps' <<<"$actions_json" &&
   grep -q 'ai.context' <<<"$actions_json" &&
   grep -q 'ai.memory' <<<"$actions_json" &&
   grep -q 'ai.theme.light' <<<"$actions_json" &&
   grep -q 'ai.workspace' <<<"$actions_json" &&
   grep -q 'ai.shortcuts' <<<"$actions_json" &&
   grep -q 'ai.knowledge' <<<"$actions_json" &&
   grep -q 'ai.llm' <<<"$actions_json" &&
   grep -q 'ai.provider' <<<"$actions_json" &&
   grep -q 'ai.diagnose' <<<"$actions_json" &&
   grep -q 'ai.playbook.wifi' <<<"$actions_json" &&
   grep -q 'ai.research' <<<"$actions_json" &&
   grep -q 'experience.status' <<<"$actions_json" &&
   grep -q 'experience.apply' <<<"$actions_json" &&
   grep -q 'experience.doctor' <<<"$actions_json" &&
   grep -q 'experience.warmup' <<<"$actions_json" &&
   grep -q 'experience.events' <<<"$actions_json" &&
   grep -q 'experience.recommend' <<<"$actions_json" &&
   grep -q 'sevenos.shell-experience.v1' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'launch_feedback' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'workspace_feedback' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'warmup_experience' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'recent_events_json' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'recommendation_json' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'sevenos.shell-experience.recommendation.v1' "$ROOT_DIR/scripts/shell-experience.sh" &&
   grep -q 'def experience()' "$ROOT_DIR/bin/seven-waybar-status" &&
   grep -q 'Next:' "$ROOT_DIR/bin/seven-waybar-status" &&
   grep -Fq 'seven-waybar-status [sevenos|wifi|bluetooth|vpn|recorder|ai|control-center|system-status|media|profile|mini-context|app-menu|app-menu-item|app-menu-more|experience]' "$ROOT_DIR/bin/seven-waybar-status" &&
   grep -q 'app-menu-item' "$ROOT_DIR/bin/seven-waybar-status" &&
   grep -q '"shell_experience"' "$ROOT_DIR/bin/seven-home-native" &&
   grep -q '"recommendation"' "$ROOT_DIR/bin/seven-home-native" &&
   grep -q 'Fluidifier' "$ROOT_DIR/bin/seven-home-native" &&
   grep -q 'seven experience status' "$ROOT_DIR/scripts/experience.sh" &&
   grep -q 'experience_workspace' "$ROOT_DIR/bin/seven-workspace" &&
   grep -q 'experience_event' "$ROOT_DIR/bin/seven-dock" &&
   grep -q 'shell-experience.sh" launch' "$ROOT_DIR/bin/seven-apps" &&
   grep -q 'experience_event' "$ROOT_DIR/bin/seven-spotlight" &&
   grep -q 'shell_experience' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'experience_focus' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q '"shell_experience"' "$ROOT_DIR/scripts/state.sh" &&
   grep -q 'improve.daily' <<<"$actions_json" &&
   grep -q 'profile.bootstrap.active' <<<"$actions_json" &&
   grep -q 'profile.bootstrap.all' <<<"$actions_json" &&
   grep -q 'runtime.status' <<<"$actions_json" &&
   grep -q 'runtime.plan' <<<"$actions_json" &&
   grep -q 'runtime.capabilities' <<<"$actions_json" &&
   grep -q 'core.status' <<<"$actions_json" &&
   grep -q 'core.bus' <<<"$actions_json" &&
   grep -q 'core.snapshot' <<<"$actions_json" &&
   grep -q 'core.health' <<<"$actions_json" &&
   grep -q 'core.profiles' <<<"$actions_json" &&
   grep -q 'core.observe' <<<"$actions_json" &&
   grep -q 'core.install-service' <<<"$actions_json" &&
   grep -q '"actions"' <<<"$state_json"; then
  ok "SevenOS exposes a shared action registry for Hub and shell surfaces"
else
  fail "SevenOS action registry should expose machine-readable UI actions"
fi

ai_intent_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json intent "open settings")"
ai_wifi_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json "mon wifi ne marche pas")"
ai_apps_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json apps)"
ai_theme_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json "mets le thème light")"
ai_workspace_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json intent "workspace 2")"
ai_stop_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json intent "stop blender")"
ai_stop_fr_text="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 SEVENAI_LANG=fr "$ROOT_DIR/bin/seven" ai "stop blender")"
ai_stop_en_text="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 SEVENAI_LANG=en "$ROOT_DIR/bin/seven" ai "stop blender")"
ai_llm_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json llm)"
ai_provider_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json provider "mon wifi ne marche pas")"
ai_diagnose_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json diagnose system)"
ai_playbook_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json playbook wifi_repair)"
ai_research_json="$(capture_with_timeout 8 env SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json research "Hyprland")"
if python -m json.tool >/dev/null <<<"$ai_intent_json" &&
   python -m json.tool >/dev/null <<<"$ai_wifi_json" &&
   python -m json.tool >/dev/null <<<"$ai_apps_json" &&
   python -m json.tool >/dev/null <<<"$ai_theme_json" &&
   python -m json.tool >/dev/null <<<"$ai_workspace_json" &&
   python -m json.tool >/dev/null <<<"$ai_stop_json" &&
   python -m json.tool >/dev/null <<<"$ai_llm_json" &&
   python -m json.tool >/dev/null <<<"$ai_provider_json" &&
   python -m json.tool >/dev/null <<<"$ai_diagnose_json" &&
   python -m json.tool >/dev/null <<<"$ai_playbook_json" &&
   python -m json.tool >/dev/null <<<"$ai_research_json" &&
   grep -q '"intent": "OPEN_APP"' <<<"$ai_intent_json" &&
   grep -q '"intent": "REPAIR_NETWORK"' <<<"$ai_wifi_json" &&
   grep -q '"schema": "sevenos.ai.apps.v1"' <<<"$ai_apps_json" &&
   grep -q '"intent": "SET_THEME"' <<<"$ai_theme_json" &&
   grep -q '"intent": "SWITCH_WORKSPACE"' <<<"$ai_workspace_json" &&
   grep -q '"intent": "KILL_PROCESS"' <<<"$ai_stop_json" &&
   grep -q 'arrêter blender' <<<"$ai_stop_fr_text" &&
   grep -q 'stop blender' <<<"$ai_stop_en_text" &&
   grep -q '"schema": "sevenos.ai.llm-contract.v1"' <<<"$ai_llm_json" &&
   grep -q '"schema": "sevenos.ai.provider.local.v1"' <<<"$ai_provider_json" &&
   grep -q '"schema": "sevenos.ai.diagnostics.v1"' <<<"$ai_diagnose_json" &&
   grep -q '"schema": "sevenos.ai.playbook.v1"' <<<"$ai_playbook_json" &&
   grep -q '"schema": "sevenos.ai.research.v1"' <<<"$ai_research_json"; then
  ok "SevenAI parses intents, uses local provider, diagnostics, playbooks and research cache"
else
  fail "SevenAI should parse intents and expose local provider, diagnostics, playbooks and research JSON"
fi

flatpak_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" flatpak status --json)"
primary_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" primary --json)"
if python -m json.tool >/dev/null <<<"$flatpak_json" &&
   grep -q '"schema": "sevenos.flatpak.v1"' <<<"$flatpak_json" &&
   grep -q '"apps"' <<<"$flatpak_json"; then
  ok "SevenOS Flatpak bridge exposes a Hub-ready JSON contract"
else
  fail "SevenOS Flatpak bridge should expose machine-readable app readiness"
fi

if python -m json.tool >/dev/null <<<"$primary_json" &&
   grep -q '"schema": "sevenos.primary-pc.v1"' <<<"$primary_json" &&
   grep -q '"next_actions"' <<<"$primary_json"; then
  ok "SevenOS exposes a primary-PC readiness gate"
else
  fail "SevenOS should expose one primary-PC readiness contract"
fi

core_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core status --json)"
core_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core plan --json)"
core_bus_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core bus --json)"
core_snapshot_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core snapshot --json)"
core_health_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core health --json)"
core_profiles_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core profiles --json)"
core_observe_json="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/core.sh" observe --json)"
shell_status_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shell status --json)"
if grep -q '"schema": "sevenos.core.v1"' <<<"$core_json" &&
   grep -Eq '"state": "(FOUNDATION|READY_FOR_DAEMON|RUNTIME_READY)"' <<<"$core_json" &&
   grep -q '"schema": "sevenos.core-plan.v1"' <<<"$core_plan_json" &&
   grep -q '"schema": "sevenos.bus.v1"' <<<"$core_bus_json" &&
   grep -q '"schema":"sevenos.daemon.snapshot.v1"' <<<"$core_snapshot_json" &&
   grep -q '"invalid_event_count"' <<<"$core_snapshot_json" &&
   grep -q '"schema":"sevenos.daemon.health.v1"' <<<"$core_health_json" &&
   grep -q '"runtime"' <<<"$core_health_json" &&
   grep -q '"schema":"sevenos.daemon.profiles.v1"' <<<"$core_profiles_json" &&
   grep -q '"writer":"seven-daemon"' <<<"$core_profiles_json" &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" shield --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" shield-plan --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" cyberspace --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" cyberspace-plan --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" server --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" server-plan --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" windows --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" windows-plan --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" installer --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" installer-plan --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" packages --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" packages-plan --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" insights --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" phase-gate --json | python -m json.tool >/dev/null &&
   grep -q '"schema": "sevenos.context.emit.v1"' <<<"$core_observe_json" &&
   grep -q '"runtime_health":' <<<"$shell_status_json" &&
   grep -q '"seven core health --json"' <<<"$shell_status_json" &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" snapshot --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" health --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" profiles --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" events --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" summary --json | python -m json.tool >/dev/null &&
   XDG_STATE_HOME="$(mktemp -d)" "$ROOT_DIR/bin/seven-daemon" emit --source ux --type preview --message "ux event" --json | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/sevenbus-probe" --json | python -m json.tool >/dev/null &&
   grep -q 'serde_json' "$ROOT_DIR/seven-core/daemon/Cargo.toml" &&
   grep -q 'Typed SevenBus reader' <<<"$core_json" &&
   grep -q 'Rust event list reader' <<<"$core_json" &&
   grep -q '"shield_engine"' <<<"$core_json" &&
   grep -q '"server_engine"' <<<"$core_json" &&
   grep -q '"windows_engine"' <<<"$core_json" &&
   grep -q '"installer_engine"' <<<"$core_json" &&
   grep -q '"packages_engine"' <<<"$core_json" &&
   grep -q '"insights_engine"' <<<"$core_json" &&
   grep -q '"phase_gate_engine"' <<<"$core_json" &&
   grep -q 'C SevenBus probe' <<<"$core_json" &&
   grep -q 'seven-daemon emit' "$ROOT_DIR/scripts/events.sh" &&
   grep -Fq '"$ROOT_DIR/bin/seven-daemon" events' "$ROOT_DIR/scripts/events.sh" &&
   grep -q 'ExecStart=%h/.local/bin/seven-daemon serve' "$ROOT_DIR/systemd/user/seven-daemon.service" &&
   grep -q 'ExecStart=%h/.local/bin/seven-daemon observe-loop' "$ROOT_DIR/systemd/user/seven-context-observer.service" &&
   grep -q 'Wants=seven-daemon.service' "$ROOT_DIR/systemd/user/sevenos-session.target" &&
   grep -q 'seven-context-observer.service' "$ROOT_DIR/systemd/user/sevenos-session.target" &&
   grep -q 'sevenos-polkit-agent.service' "$ROOT_DIR/systemd/user/sevenos-session.target" &&
   grep -q 'sevenos-shell-experience.service' "$ROOT_DIR/systemd/user/sevenos-session.target" &&
   grep -q 'ExecStart=%h/.local/bin/seven experience warmup' "$ROOT_DIR/systemd/user/sevenos-shell-experience.service" &&
   grep -q 'polkit-gnome-authentication-agent' "$ROOT_DIR/systemd/user/sevenos-polkit-agent.service" &&
   grep -q '"core"' <<<"$state_json" &&
   grep -q 'SevenBus' "$ROOT_DIR/seven-core/README.md" &&
   grep -q 'sevenos.daemon.v1' "$ROOT_DIR/seven-core/daemon/src/main.rs"; then
  ok "Seven Core exposes a real system experience layer contract"
else
  fail "Seven Core should expose status, plan, bus schema and daemon scaffold"
fi

if grep -q 'exec-once = seven-session' "$ROOT_DIR/hyprland/hyprland.conf"; then
  ok "Hyprland starts SevenOS session"
else
  fail "Hyprland should start seven-session"
fi

if grep -q 'source = ~/.config/hypr/conf/monitor.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'source = ~/.config/hypr/conf/keyboard.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'source = ~/.config/hypr/conf/sevenos-windows.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'source = ~/.config/hypr/conf/sevenos-lua-generated.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'source = ~/.config/hypr/conf/custom.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'install_preserved_config_file' "$ROOT_DIR/scripts/apply-theme.sh"; then
  ok "Hyprland exposes protected user override files"
else
  fail "Hyprland protected override files are missing"
fi

hypr_lua_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" hypr lua status --json)"
hypr_lua_audit="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" hypr lua audit --json)"
hypr_lua_plan="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" hypr lua plan pulse --json)"
hypr_lua_events="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/hypr-lua-events.sh" status --json)"
if command -v lua >/dev/null 2>&1 &&
   python -m json.tool <<<"$hypr_lua_json" >/dev/null &&
   python -m json.tool <<<"$hypr_lua_audit" >/dev/null &&
   python -m json.tool <<<"$hypr_lua_plan" >/dev/null &&
   python -m json.tool <<<"$hypr_lua_events" >/dev/null &&
   grep -q '"schema":"sevenos.hypr-lua.v1"' <<<"$hypr_lua_json" &&
   grep -q '"schema":"sevenos.hypr-lua.config-map.v1"' <<<"$hypr_lua_audit" &&
   grep -q '"schema":"sevenos.hypr-lua.profile-runtime.v1"' <<<"$hypr_lua_plan" &&
   grep -q '"schema":"sevenos.hypr-lua.events.v1"' <<<"$hypr_lua_events" &&
   grep -q '"binds":0' <<<"$hypr_lua_audit" &&
   grep -q '"windowrules":0' <<<"$hypr_lua_audit" &&
   grep -q '"animations":0' <<<"$hypr_lua_audit" &&
   grep -q '"semantic_windowrule_conflicts":0' <<<"$hypr_lua_audit" &&
   grep -q '"realtime_ready":' <<<"$hypr_lua_events" &&
   grep -q '"transport":' <<<"$hypr_lua_events" &&
   grep -q '"bind_duplicates":0' <<<"$hypr_lua_audit" &&
   grep -q '"windowrule_duplicates":0' <<<"$hypr_lua_audit" &&
   grep -q '"profile":"pulse"' <<<"$hypr_lua_plan" &&
   grep -q 'Lua intent -> generated Hyprland conf' "$ROOT_DIR/docs/HYPRLAND_LUA_ENGINE.md" &&
   grep -q 'safe by default' "$ROOT_DIR/docs/HYPRLAND_LUA_ENGINE.md" &&
   grep -q 'Phase 2 Output' "$ROOT_DIR/docs/HYPRLAND_LUA_ENGINE.md" &&
   grep -q 'Phase 3 Output' "$ROOT_DIR/docs/HYPRLAND_LUA_ENGINE.md" &&
   grep -q 'sevenos-lua-generated.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'copy_config_file "$ROOT_DIR/hyprland/conf/sevenos-lua-generated.conf"' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'lua-intent-to-hyprland-conf' "$ROOT_DIR/hyprland/lua/init.lua" &&
   grep -q 'profile-runtime.v1' "$ROOT_DIR/hyprland/lua/init.lua" &&
   grep -q 'SEVENOS_ACTIVE_PROFILE' "$ROOT_DIR/hyprland/lua/init.lua" &&
   grep -q 'rules.keybinds' "$ROOT_DIR/hyprland/lua/init.lua" &&
   grep -q 'rules.animations' "$ROOT_DIR/hyprland/lua/init.lua" &&
   grep -q 'rules.windows' "$ROOT_DIR/hyprland/lua/init.lua" &&
   grep -q 'sevenos.hypr-lua.config-map.v1' "$ROOT_DIR/hyprland/lua/core/audit.lua" &&
   grep -q 'bind_duplicates' "$ROOT_DIR/hyprland/lua/core/audit.lua" &&
   grep -q 'semantic_windowrule_conflicts' "$ROOT_DIR/hyprland/lua/core/audit.lua" &&
   grep -q 'Profile: ' "$ROOT_DIR/hyprland/lua/core/emit.lua" &&
   grep -q 'Profile environment' "$ROOT_DIR/hyprland/lua/core/emit.lua" &&
   grep -q 'Common animation rules' "$ROOT_DIR/hyprland/lua/core/emit.lua" &&
   grep -q 'Common keybinds' "$ROOT_DIR/hyprland/lua/core/emit.lua" &&
   grep -q 'Common window rules' "$ROOT_DIR/hyprland/lua/core/emit.lua" &&
   grep -q 'animation = workspaces' "$ROOT_DIR/hyprland/lua/rules/animations.lua" &&
   grep -q 'animation = specialWorkspace' "$ROOT_DIR/hyprland/lua/rules/animations.lua" &&
   grep -q 'seven-workspace switch 1' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'seven-hypr-lua-events' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'sevenos-hypr-lua-events.service' "$ROOT_DIR/systemd/user/sevenos-session.target" &&
   grep -q 'sevenos.hypr-lua.event.v1' "$ROOT_DIR/scripts/hypr-lua-events.sh" &&
   grep -q 'nc -U' "$ROOT_DIR/scripts/hypr-lua-events.sh" &&
   grep -q 'current.json' "$ROOT_DIR/scripts/hypr-lua-events.sh" &&
   grep -q 'handle_event' "$ROOT_DIR/scripts/hypr-lua-events.sh" &&
   grep -q 'poll_watch' "$ROOT_DIR/scripts/hypr-lua-events.sh" &&
   grep -q 'SevenTerminalClassic' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'SevenQuickSettingsNative' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'workspace = special:seven' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -Fq 'scripts/hypr-lua.sh" apply "$key"' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'seven hypr lua apply %q' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'windowrule = match:class ^(steam)$' "$ROOT_DIR/hyprland/lua/profiles/pulse.lua" &&
   grep -q 'env = SEVENOS_HYPR_PROFILE,pulse' "$ROOT_DIR/hyprland/lua/profiles/pulse.lua" &&
   [[ -s "$ROOT_DIR/hyprland/lua/config_map.json" ]]; then
  ok "SevenOS Hypr Lua Engine audits and generates a safe programmable desktop layer"
else
  fail "SevenOS Hypr Lua Engine should expose audit, generated conf and safe fallback"
fi

if grep -q 'source = ~/.config/hypr/conf/sevenos-theme-env.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   [[ -s "$ROOT_DIR/hyprland/conf/sevenos-theme-env.conf" ]] &&
   grep -q 'env = GTK_THEME' "$ROOT_DIR/hyprland/conf/sevenos-theme-env.conf" &&
   grep -q 'env = QT_QPA_PLATFORMTHEME,qt6ct' "$ROOT_DIR/hyprland/conf/sevenos-theme-env.conf"; then
  ok "Hyprland exports dynamic GTK and Qt theme hints"
else
  fail "Hyprland missing GTK/Qt theme environment"
fi

if grep -q '$terminal = seven-terminal' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bind = $mod, Return, exec, $terminal' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod SHIFT, Return, exec, seven-terminal profile' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod CTRL, Return, exec, seven-terminal menu' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'windowrule = match:class ^(SevenTerminalClassic)$, float on, center on, size 760 480' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'windowrule = match:class ^(SevenTerminalDark)$, float on, center on, size 760 480' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'bind = $mod, SPACE, exec, $spotlight' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q '$spotlight = seven-spotlight' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bindr = $mod, SUPER_L, exec, $launcher' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bindr = $mod, SUPER_R, exec, $launcher' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod, A, exec, $launcher' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod, D, exec, $dock' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod, TAB, exec, $overview' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod, N, exec, $quicksettings' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod, C, exec, seven shield mode' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod CTRL, C, exec, seven shield hud' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod, E, exec, seven-files' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod CTRL, E, exec, seven-files profile' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
  grep -q 'seven-overview apps' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bind = $mod, H, exec, seven-help' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod SHIFT, H, exec, seven-hub' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   ! grep -q 'bind = $mod, SPACE, exec, seven hub' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua"; then
  ok "Hyprland exposes Spotlight, Apps, Help and CyberSpace shortcuts"
else
  fail "Hyprland discoverable Spotlight, desktop and CyberSpace shortcuts missing"
fi

if grep -q 'bind = , Print, exec, seven-screenshot area save' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod, Print, exec, seven-screenshot full save' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod SHIFT, S, exec, seven-screenshot area edit' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod CTRL, S, exec, seven-screenshot area copy' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'seven-recorder area' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'seven-recorder full' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'bind = $mod ALT, R, exec, hyprctl reload' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'Screenshot Save' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'Record Area' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'wf-recorder' "$ROOT_DIR/scripts/packages-base.txt" &&
   grep -q 'slurp -d' "$ROOT_DIR/bin/seven-recorder" &&
   grep -q 'wl-copy' "$ROOT_DIR/bin/seven-recorder" &&
   grep -q 'seven-recorder-native' "$ROOT_DIR/scripts/install-cli.sh" &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" recorder status | grep -q 'SevenOS Recorder:' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-recorder" panel | grep -q 'DRY-RUN > SevenOS Recorder > panel' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-recorder" area | grep -q 'DRY-RUN > SevenOS Recorder > area' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-recorder" full | grep -q 'DRY-RUN > SevenOS Recorder > full'; then
  ok "SevenOS screenshots and screen recordings use native helpers"
else
  fail "SevenOS screenshot and recorder shortcuts should use native helpers"
fi

overview_search_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-overview" search)"
quick_settings_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-quick-settings")"
apps_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-apps" open)"
if grep -Eq 'rounding = (26|28)' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'animation = specialWorkspace' "$ROOT_DIR/hyprland/lua/rules/animations.lua" &&
   grep -q 'workspace = special:seven' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'windowrule = match:title ^(Open File)' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   [[ "$overview_search_output" == *"DRY-RUN > Spotlight > Open command center"* ]] &&
   [[ "$apps_output" == *"seven-apps catalog"* ]] &&
   [[ "$apps_output" == *"desktop icon metadata"* ]] &&
   [[ "$quick_settings_output" == *"DRY-RUN > Quick Settings > Open panel"* ]] &&
   grep -q 'clean_selection' "$ROOT_DIR/bin/seven-quick-settings" &&
   grep -q 'clean_selection' "$ROOT_DIR/bin/seven-power"; then
  ok "SevenOS Shell exposes GNOME-like overview, quick settings and polished window rules"
else
  fail "SevenOS Shell GNOME-like interface layer is incomplete"
fi

window_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-window" status --json)"
window_dry="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-window" smart-maximize)"
if python -m json.tool <<<"$window_json" >/dev/null &&
   grep -q '"schema": "sevenos.smart-window.v1"' <<<"$window_json" &&
   grep -q 'SevenDecor' "$ROOT_DIR/docs/SMART_WINDOW_SYSTEM.md" &&
   grep -q 'Traffic-Light Logic' "$ROOT_DIR/docs/SMART_WINDOW_SYSTEM.md" &&
   grep -q 'Decoration Coverage' "$ROOT_DIR/docs/SMART_WINDOW_SYSTEM.md" &&
   grep -q 'seven-window toggle-float' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'seven-window smart-maximize' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'seven-window layout-menu' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'seven-window controls' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua" &&
   grep -q 'SevenWindowControlsNative' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q 'seven-window-controls-native' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'seven-window controls' "$ROOT_DIR/docs/SMART_WINDOW_SYSTEM.md" &&
   "$ROOT_DIR/bin/seven-window-controls-native" --probe >/dev/null &&
   grep -q 'copy_config_file "$ROOT_DIR/hyprland/conf/sevenos-windows.conf"' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'Seven Smart Window System' "$ROOT_DIR/hyprland/conf/sevenos-windows.conf" &&
   grep -q 'layerrule = blur on, match:namespace waybar' "$ROOT_DIR/hyprland/conf/sevenos-windows.conf" &&
   ! grep -q 'layerrule = blur, waybar' "$ROOT_DIR/hyprland/conf/sevenos-windows.conf" &&
   grep -q 'blueman-manager' "$ROOT_DIR/hyprland/conf/sevenos-windows.conf" &&
   grep -q 'mpv' "$ROOT_DIR/hyprland/conf/sevenos-windows.conf" &&
   grep -q 'SevenDecor phase 1' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" &&
   grep -q 'button.titlebutton.close' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" &&
   grep -q 'button.titlebutton.minimize' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" &&
   grep -q 'button.titlebutton.maximize' "$ROOT_DIR/hyprland/gtk-4.0/gtk.css" &&
   grep -q 'write_mode' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'layout_menu' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'decor_status_json' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'decor_apply' "$ROOT_DIR/scripts/smart-window.sh" &&
   grep -q 'DRY-RUN > hyprctl' <<<"$window_dry"; then
  ok "Seven Smart Window System exposes visual window modes and Hyprland-backed layout actions"
else
  fail "Seven Smart Window System should expose modes, traffic-light actions and Hyprland rules"
fi

if grep -q 'seven-notifications' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'seven-idle' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'warmup_shell_experience' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'start_once waybar' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'seven-wallpaper' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'systemctl --user start sevenos-session.target' "$ROOT_DIR/bin/seven-session"; then
  ok "SevenOS session supervises desktop components"
else
  fail "seven-session should supervise desktop components"
fi

session_status_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-session-status")"
session_status_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" session status --json)"
if [[ -s "$ROOT_DIR/systemd/user/sevenos-session.target" ]] &&
   [[ -s "$ROOT_DIR/systemd/user/seven-daemon.service" ]] &&
   [[ -s "$ROOT_DIR/systemd/user/seven-context-observer.service" ]] &&
   [[ -s "$ROOT_DIR/systemd/user/sevenos-waybar.service" ]] &&
   [[ -s "$ROOT_DIR/systemd/user/sevenos-notifications.service" ]] &&
   [[ -s "$ROOT_DIR/systemd/user/sevenos-wallpaper.service" ]] &&
   [[ -s "$ROOT_DIR/systemd/user/sevenos-shell-experience.service" ]] &&
   [[ -s "$ROOT_DIR/session/sevenos.desktop" ]] &&
   grep -q 'configure_user_session_services' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'sevenos-shell-experience.service' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'seven-notifications' "$ROOT_DIR/systemd/user/sevenos-notifications.service" &&
   grep -q 'seven-idle' "$ROOT_DIR/systemd/user/sevenos-idle.service" &&
   grep -q 'sevenos-shell-experience' "$ROOT_DIR/bin/seven-session-status" &&
   grep -q 'SevenOS Session Status' <<<"$session_status_output" &&
   grep -q '"schema": "sevenos.session.v1"' <<<"$session_status_json"; then
  ok "SevenOS declares an installable session and user service layer"
else
  fail "SevenOS should declare an installable session and user service layer"
fi

if grep -Eq '^[[:space:]]*pseudotile[[:space:]]*=|togglesplit' "$ROOT_DIR/hyprland/hyprland.conf"; then
  fail "Hyprland config contains options removed in Hyprland 0.55"
else
  ok "Hyprland config avoids removed 0.55 options"
fi

if grep -q 'wallpaper-sevenos-active.png' "$ROOT_DIR/hyprland/hyprpaper.conf"; then
  ok "Hyprpaper uses the active SevenOS wallpaper target"
else
  fail "Hyprpaper should use the active SevenOS wallpaper target"
fi

if [[ -s "$ROOT_DIR/hyprland/hypridle.conf" ]] &&
   [[ -s "$ROOT_DIR/hyprland/hyprlock.conf" ]] &&
   [[ -s "$ROOT_DIR/hyprland/conf/sevenos-dynamic.conf" ]] &&
   [[ -s "$ROOT_DIR/systemd/user/sevenos-hyprsunset.service" ]] &&
   [[ -s "$ROOT_DIR/hyprland/swaync/config.json" ]] &&
   [[ -s "$ROOT_DIR/hyprland/swaync/style.css" ]] &&
   [[ -s "$ROOT_DIR/hyprland/wlogout/layout" ]] &&
   [[ -s "$ROOT_DIR/hyprland/wlogout/style.css" ]] &&
   grep -q 'hyprlock' "$ROOT_DIR/bin/seven-power" &&
   grep -q 'wlogout' "$ROOT_DIR/bin/seven-power" &&
   grep -q 'theme_source_or_common swaync' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'theme_source_or_common wlogout' "$ROOT_DIR/scripts/apply-theme.sh" &&
   [[ -s "$ROOT_DIR/hyprland-light/swaync/style.css" ]] &&
   [[ -s "$ROOT_DIR/hyprland-light/wlogout/style.css" ]] &&
   [[ -s "$ROOT_DIR/hyprland-light/hyprlock.conf" ]] &&
   grep -q 'hypridle.conf' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'hyprlock.conf' "$ROOT_DIR/scripts/apply-theme.sh"; then
  ok "SevenOS integrates swaync, wlogout, hypridle, hyprlock and Hyprpaper as modern system surfaces"
else
  fail "SevenOS modern notification, power, idle, lock or wallpaper integration is incomplete"
fi

if grep -q 'matugen' "$ROOT_DIR/scripts/wallpaper-theme.sh" &&
   grep -q 'wallust' "$ROOT_DIR/scripts/wallpaper-theme.sh" &&
   grep -q 'install-glaze-local.sh' "$ROOT_DIR/scripts/hypr-ecosystem.sh" &&
   grep -q 'install-hyprsysteminfo.sh' "$ROOT_DIR/scripts/hypr-ecosystem.sh" &&
   grep -q 'sevenos-dynamic.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'sevenos-hyprsunset.service' "$ROOT_DIR/systemd/user/sevenos-session.target" &&
   grep -q 'hyprsysteminfo' "$ROOT_DIR/hyprland/lua/rules/keybinds.lua"; then
  ok "SevenOS Hypr ecosystem exposes dynamic wallpaper theming, warm light and system info hooks"
else
  fail "SevenOS Hypr ecosystem should connect wallpaper colors, hyprsunset and system info hooks"
fi

if grep -q '^Type=simple' "$ROOT_DIR/systemd/user/sevenos-wallpaper.service" &&
   grep -q 'seven-wallpaper serve' "$ROOT_DIR/systemd/user/sevenos-wallpaper.service" &&
   grep -q 'systemd_wallpaper_available' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -q 'set_custom_wallpaper' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -q 'ACTIVE_WALLPAPER' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -q 'hyprctl hyprpaper wallpaper' "$ROOT_DIR/bin/seven-wallpaper" &&
   grep -q 'wallpaper|set-wallpaper' "$ROOT_DIR/bin/seven-files" &&
   grep -q 'Set as SevenOS Wallpaper' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'remove SevenOS wallpaper from image MIME defaults' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'Exec=seven-wallpaper set %f' "$ROOT_DIR/seven-hub/seven-wallpaper.desktop" &&
   ! grep -q '^MimeType=image/' "$ROOT_DIR/seven-hub/seven-wallpaper.desktop"; then
  ok "Wallpaper runtime supports explicit file-manager wallpaper selection without hijacking image open"
else
  fail "Wallpaper runtime should keep Hyprpaper alive and avoid becoming the default image opener"
fi

if grep -q 'include classic.conf' "$ROOT_DIR/hyprland/kitty/kitty.conf" &&
   grep -q 'background_opacity 0.90' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'initial_window_width 88c' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'initial_window_height 24c' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'window_padding_width 12' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'font_size 11.0' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'adjust_line_height 110%' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'remember_window_size no' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'background_blur 14' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'active_tab_background #12131A' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'cursor #00D4FF' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'background #09090B' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'copy_on_select clipboard' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'map ctrl+shift+c copy_to_clipboard' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'map ctrl+shift+v paste_from_clipboard' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'tab_bar_min_tabs 1' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'tab_title_template "  {title}  "' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'map ctrl+shift+s launch --type=overlay --stdin-source=@screen_scrollback fzf' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'map ctrl+shift+space launch --type=overlay --cwd=current seven-terminal-palette' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'map ctrl+shift+w close_window' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'map ctrl+shift+f launch --type=background hyprctl dispatch fullscreen 1' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'env SEVENOS_TERMINAL_CLASSIC=1' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'env SEVENOS_TERMINAL_PROMPT=1' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'forge | cyber | focus | admin | atlas' "$ROOT_DIR/bin/seven-terminal" &&
   grep -q 'profile_overrides' "$ROOT_DIR/bin/seven-terminal" &&
   grep -q 'SevenTerminalForge' "$ROOT_DIR/bin/seven-terminal" &&
   grep -q 'seven-terminal-palette' "$ROOT_DIR/bin/seven-terminal-palette" &&
   grep -q 'Explain Last Command' "$ROOT_DIR/bin/seven-terminal-palette" &&
   grep -q 'SevenTerminalNative' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q '"light": {' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q '"forge": {' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q '"cyber": {' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q '"focus": {' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q '"admin": {' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q '"forge": {' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'SF Mono 11' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'set_cell_height_scale(1.10)' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'seven-terminal-frame' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'traffic.close' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'traffic.min' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'traffic.max' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'draw_traffic_symbol' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'activate_traffic' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'terminal_key_press' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'copy_terminal_selection' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'paste_clipboard' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'show_terminal_menu' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'Gtk.Notebook' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'new_tab' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'split_terminal' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'terminal-searchbar' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'search_set_regex' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'show_native_palette' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'PROFILE_ROLES' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'profile_role' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'profile_actions' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'terminal-status' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'install_matchers' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'seven_zoom_in' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'terminal_state_file' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'restore_session' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'terminal_log_path' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'minimize_window' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'toggle_zoom_or_tile' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'kitty-default' "$ROOT_DIR/bin/seven-terminal" &&
   grep -q 'SEVENOS_TERMINAL_NATIVE' "$ROOT_DIR/bin/seven-terminal" &&
   grep -q 'terminal_log_path' "$ROOT_DIR/bin/seven-terminal" &&
   grep -q 'Avoid post-launch' "$ROOT_DIR/bin/seven-terminal" &&
   grep -q 'Exec=seven-terminal' "$ROOT_DIR/seven-hub/seven-terminal.desktop" &&
   grep -q 'terminal: "seven-terminal";' "$ROOT_DIR/hyprland/rofi/config.rasi" &&
   grep -q 'env = TERMINAL,seven-terminal' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'env = SEVENOS_TERMINAL,seven-terminal' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'seven-terminal.desktop' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'TERMINAL=seven-terminal' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'xdg-terminals.list' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'seven-terminal focus -- bash -lc' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'seven-terminal focus -- bash -lc' "$ROOT_DIR/bin/seven-quick-settings" &&
   grep -q 'seven-terminal focus -- bash -lc' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q '"seven-terminal", "focus", "--", "bash", "-lc"' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'terminal_cmd" focus' "$ROOT_DIR/seven-hub/bin/seven-hub" &&
   grep -q '"seven-terminal", "focus"' "$ROOT_DIR/seven-hub/bin/seven-control-center" &&
   grep -q 'terminal.open' "$ROOT_DIR/scripts/actions.sh" &&
   grep -Fq 'windowrule = match:class ^(SevenTerminalNative)$, float on, center on, size 760 480' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -Fq 'windowrule = match:title ^(Seven Terminal · .*)$, float on, center on, size 760 480' "$ROOT_DIR/hyprland/lua/rules/windows.lua" &&
   grep -q '__sevenos_real_command' "$ROOT_DIR/branding/shell/terminal-bashrc" &&
   grep -q '__sevenos_git()' "$ROOT_DIR/branding/shell/terminal-bashrc" &&
   grep -q '__sevenos_git_branch' "$ROOT_DIR/branding/shell/terminal-bashrc" &&
   grep -q '__sevenos_git_branch' "$ROOT_DIR/branding/shell/terminal-zsh/.zshrc" &&
   grep -q '__sevenos_terminal_mode' "$ROOT_DIR/branding/shell/terminal-bashrc" &&
   grep -q '__sevenos_command_warning' "$ROOT_DIR/branding/shell/terminal-bashrc" &&
   grep -q '__sevenos_command_warning' "$ROOT_DIR/branding/shell/terminal-zsh/.zshrc" &&
   grep -q '__sevenos_runtime_context' "$ROOT_DIR/branding/shell/terminal-zsh/.zshrc" &&
   grep -q '__sevenos_duration' "$ROOT_DIR/branding/shell/terminal-bashrc" &&
   grep -q 'exec zsh -di' "$ROOT_DIR/bin/seven-terminal-shell" &&
   grep -q 'background #09090B' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'copy_on_select clipboard' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'map ctrl+shift+c copy_to_clipboard' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'map ctrl+shift+v paste_from_clipboard' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'initial_window_width 88c' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'initial_window_height 24c' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'wayland_titlebar_color #12131A' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'map ctrl+shift+u kitten hints' "$ROOT_DIR/hyprland/kitty/dark.conf" &&
   grep -q 'background #E9EEF7' "$ROOT_DIR/hyprland-light/kitty/light.conf" &&
   grep -q 'font_size 11.0' "$ROOT_DIR/hyprland-light/kitty/light.conf" &&
   grep -q 'scrollback_lines 20000' "$ROOT_DIR/hyprland-light/kitty/light.conf" &&
   grep -q 'map ctrl+shift+space launch --type=overlay --cwd=current seven-terminal-palette' "$ROOT_DIR/hyprland-light/kitty/light.conf" &&
   grep -q 'env SEVENOS_TERMINAL_LIGHT=1' "$ROOT_DIR/hyprland-light/kitty/light.conf" &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" classic | grep -q 'DRY-RUN > Terminal > Open classic' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" forge | grep -q 'DRY-RUN > Terminal > Open forge' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" cyber | grep -q 'DRY-RUN > Terminal > Open cyber' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" focus | grep -q 'DRY-RUN > Terminal > Open focus' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" admin | grep -q 'DRY-RUN > Terminal > Open admin' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" atlas | grep -q 'DRY-RUN > Terminal > Open atlas' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal-palette" | grep -Eq 'Explain Last Command|Expliquer la dernière commande' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" dark | grep -q 'DRY-RUN > Terminal > Open dark' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" light | grep -q 'DRY-RUN > Terminal > Open light' &&
   XDG_CONFIG_HOME="$(mktemp -d)" SEVENOS_DRY_RUN=1 SEVENOS_ACTIVE_PROFILE=shield SEVENOS_THEME_MODE=dark "$ROOT_DIR/bin/seven-terminal" | grep -q 'DRY-RUN > Terminal > Open cyber' &&
   XDG_CONFIG_HOME="$(mktemp -d)" SEVENOS_DRY_RUN=1 SEVENOS_ACTIVE_PROFILE=forge SEVENOS_THEME_MODE=dark "$ROOT_DIR/bin/seven-terminal" | grep -q 'DRY-RUN > Terminal > Open forge' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-terminal" menu | grep -q 'DRY-RUN > Terminal > Open profile chooser'; then
  ok "Kitty exposes SevenOS classic, dark and light SevenOS terminal profiles"
else
  fail "Kitty palette is not aligned with SevenOS identity"
fi

if grep -q -- '--seven-blue: #4DA3FF' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--seven-blue: #2F7BFF' "$ROOT_DIR/identity/tokens-light.css" &&
   grep -q -- '--font-display: "SF Pro Display"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--font-interface: "SF Pro Display"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--font-text: "SF Pro Text"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--font-mono: "SF Mono"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--font-brand: "SF Pro Rounded"' "$ROOT_DIR/identity/tokens.css" &&
   grep -q 'gtk-font-name=SF Pro Display 10' "$ROOT_DIR/hyprland/gtk-3.0/settings.ini" &&
   grep -q 'general="SF Pro Display,10' "$ROOT_DIR/hyprland/qt5ct/qt5ct.conf" &&
   grep -q 'fixed="SF Mono,10' "$ROOT_DIR/hyprland/qt5ct/qt5ct.conf" &&
   grep -q 'font=SF Pro Display 10.5' "$ROOT_DIR/hyprland/mako/config" &&
   grep -q 'font_family SF Mono' "$ROOT_DIR/hyprland/kitty/classic.conf" &&
   grep -q 'SF Pro Display</family><prefer><family>Inter' "$ROOT_DIR/hyprland/fontconfig/fonts.conf" &&
   grep -q 'SF Pro Rounded' "$ROOT_DIR/hyprland/fontconfig/fonts.conf" &&
   grep -q 'SevenOS Cyber' "$ROOT_DIR/hyprland/fontconfig/fonts.conf" &&
   grep -q 'apply-default' "$ROOT_DIR/scripts/fonts.sh" &&
   grep -q 'import_fonts_button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'current_theme_mode' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'compact_screen' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'content_width' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'mark_action_running' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'search_key' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'page_button' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'sevenos.settings.state.v1' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_theme.gtk_app_css("settings"' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_theme.surface_css("settings"' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven_theme.gtk_app_css("store"' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'seven_theme.surface_css("store"' "$ROOT_DIR/bin/seven-store-native" &&
   grep -q 'seven_theme.gtk_app_css("reader"' "$ROOT_DIR/bin/seven-reader-native" &&
   grep -q 'seven_theme.surface_css("reader"' "$ROOT_DIR/bin/seven-reader-native" &&
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
   grep -q 'seven_theme.gtk_app_css("spotlight"' "$ROOT_DIR/bin/seven-spotlight-native" &&
   grep -q 'seven_theme.gtk_app_css("launchpad"' "$ROOT_DIR/bin/seven-launchpad-native" &&
   grep -q 'seven_theme.gtk_app_css("dock"' "$ROOT_DIR/bin/seven-dock-native" &&
   grep -q 'seven_theme.gtk_app_css("home"' "$ROOT_DIR/bin/seven-home-native" &&
   grep -q 'seven_theme.gtk_app_css("terminal"' "$ROOT_DIR/bin/seven-terminal-native" &&
   grep -q 'seven_theme.gtk_app_css("hub"' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'hub_width' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'compact_screen' "$ROOT_DIR/bin/seven-help-native" &&
   grep -q 'seven_theme.gtk_app_css("baobab"' "$ROOT_DIR/bin/seven-baobab-native" &&
   grep -q 'def cairo_palette' "$ROOT_DIR/bin/seven-app-menu-native" &&
   grep -q 'def cairo_palette' "$ROOT_DIR/bin/seven-mini-context-menu-native" &&
   grep -q 'def cairo_palette' "$ROOT_DIR/bin/seven-system-menu-native" &&
   grep -q 'def cairo_palette' "$ROOT_DIR/bin/seven-media-menu-native" &&
   grep -q 'seven-root' "$ROOT_DIR/scripts/seven_theme.py" &&
   "$ROOT_DIR/bin/seven-recorder-native" --probe >/dev/null 2>&1 &&
   grep -q 'motion_tokens' "$ROOT_DIR/scripts/seven_theme.py" &&
   grep -q 'seven-motion-system' "$ROOT_DIR/identity/design-engine.json" &&
   grep -q '"durations_ms"' "$ROOT_DIR/identity/design-engine.json" &&
   [[ -s "$ROOT_DIR/identity/native/store.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/reader.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/settings.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/settings-dark.css" ]] &&
   [[ -s "$ROOT_DIR/identity/native/files.css" ]] &&
   ! grep -R -E '#[0-9A-Fa-f]{3,8}|rgba?\(' "$ROOT_DIR/identity/native" >/dev/null 2>&1 &&
   grep -q 'theme-engine.sh' "$ROOT_DIR/scripts/apply-theme.sh" &&
   "$ROOT_DIR/scripts/theme-engine.sh" doctor >/dev/null 2>&1 &&
   [[ -s "$ROOT_DIR/scripts/theme-session.sh" ]] &&
   "$ROOT_DIR/scripts/theme-session.sh" doctor >/dev/null 2>&1 &&
   [[ -s "$ROOT_DIR/systemd/user/sevenos-theme-session.service" ]] &&
   grep -q 'sevenos-theme-session.service' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'region_selector_card' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'default_app_card' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'copy_system_summary' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q './install.sh theme light' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q './install.sh theme dark' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'SEVENOS_THEME_MODE' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'hyprland-light' "$ROOT_DIR/scripts/apply-theme.sh" &&
   grep -q 'copy GTK, Qt and fontconfig SevenOS settings' "$ROOT_DIR/scripts/apply-theme.sh" &&
   ! grep -R "box-shadow" "$ROOT_DIR/seven-hub/gui/src/styles.css" >/dev/null &&
   ! grep -E '#[0-9a-fA-F]{8}\b' "$ROOT_DIR/hyprland/waybar/style.css" >/dev/null; then
  ok "SevenOS v2 glass design tokens and scoped shadow UI rule are enforced"
else
  fail "Design tokens or scoped shadow UI rule failed"
fi

if "$ROOT_DIR/bin/seven-country" plain | grep -q 'Capital:'; then
  ok "Terminal country signal works"
else
  fail "Terminal country signal failed"
fi

if "$ROOT_DIR/bin/seven-language" status --json | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven-language" list --json | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven-language" doctor --json | python -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data.get("schema")=="sevenos.language-doctor.v1" and data.get("ready") is True else 1)' &&
   "$ROOT_DIR/bin/seven-language" doctor --json | python -c 'import json,sys; data=json.load(sys.stdin); checks={item["id"]: item for item in data["checks"]}; ok=checks.get("native-surfaces.i18n", {}).get("state")=="ok" and checks.get("cli.language-env", {}).get("state")=="ok" and checks.get("services.language-env", {}).get("state")=="ok" and checks.get("mini-os.language-env", {}).get("state")=="ok" and checks.get("mini-os.language-projection", {}).get("state") in {"ok", "missing"} and checks.get("mini-os.public-surfaces.i18n", {}).get("state")=="ok" and checks.get("waybar.app-menu.i18n", {}).get("state")=="ok"; raise SystemExit(0 if ok else 1)' &&
   "$ROOT_DIR/bin/seven-language" audit --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-language" apply --live --json | python -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if all(item.get("state") != "failed" for item in data.get("results", [])) else 1)' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-language" repair --json | python -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data.get("schema")=="sevenos.language-repair.v1" and data.get("ready") is True else 1)' &&
   "$ROOT_DIR/bin/seven" language doctor --json | python -m json.tool >/dev/null &&
   [[ "$("$ROOT_DIR/install.sh" language --dry-run)" == *"SevenOS Language Doctor"* ]] &&
   grep -q 'sevenos/language.env' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'seven-waybar-language' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'sevenos/language.env' "$ROOT_DIR/systemd/user/sevenos-waybar.service" &&
   grep -q 'sevenos/language.env' "$ROOT_DIR/systemd/user/sevenos-wallpaper.service" &&
   "$ROOT_DIR/bin/seven-language" status --json | python -c 'import json,sys; data=json.load(sys.stdin); langs={item["locale"]: item for item in data["languages"]}; packs={item["locale"]: item for item in data.get("default_language_packs", [])}; ok=all(locale in langs and langs[locale].get("installed") in {True, False} and packs.get(locale, {}).get("catalog") for locale in ("en_US.UTF-8", "fr_FR.UTF-8")); ok=ok and data.get("catalog_health", {}).get("complete") is True; raise SystemExit(0 if ok else 1)' &&
   [[ "$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-language" menu)" == *"DRY-RUN > Language > Open language chooser"* ]] &&
   [[ "$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-language" ensure fr_FR.UTF-8)" =~ (DRY-RUN\ \>\ Language\ \>\ Enable\ fr_FR\.UTF-8|OK:\ fr_FR\.UTF-8\ is\ already\ generated) ]] &&
   [[ "$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-language" ensure en_US.UTF-8)" =~ (DRY-RUN\ \>\ Language\ \>\ Enable\ en_US\.UTF-8|OK:\ en_US\.UTF-8\ is\ already\ generated) ]] &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-language" switch fr_FR.UTF-8 --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-language" switch en_US.UTF-8 --json | python -m json.tool >/dev/null &&
   grep -q 'fr_FR.UTF-8 UTF-8' "$ROOT_DIR/archiso/profile/airootfs/etc/locale.gen" &&
   grep -q 'en_US.UTF-8 UTF-8' "$ROOT_DIR/archiso/profile/airootfs/etc/locale.gen" &&
   grep -q 'language         Prepare and inspect French/English language packs' "$ROOT_DIR/install.sh" &&
   grep -Fq 'seven-language" repair' "$ROOT_DIR/install.sh" &&
   grep -Fq 'seven-language" audit' "$ROOT_DIR/install.sh" &&
   grep -q 'preparing French and English language packs' "$ROOT_DIR/scripts/new-device.sh" &&
   grep -Fq 'seven-language" repair' "$ROOT_DIR/scripts/new-device.sh" &&
   grep -Fq 'seven-language" audit' "$ROOT_DIR/scripts/new-device.sh" &&
   grep -q 'language_check' "$ROOT_DIR/scripts/post-install.sh" &&
   grep -q 'generated language labels match active session' "$ROOT_DIR/scripts/post-install.sh" &&
   grep -q 'fr_FR.UTF-8' "$ROOT_DIR/installer/lib.sh" &&
   grep -q 'en_US.UTF-8' "$ROOT_DIR/installer/lib.sh" &&
   grep -q 'seven_i18n' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'language_selector_card' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven language switch' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven language doctor' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'SevenOS language contract' "$ROOT_DIR/bin/seven-public-studio" &&
   grep -q 'Runtime labels synchronized' "$ROOT_DIR/bin/seven-public-studio" &&
   grep -q 'key="language-contract"' "$ROOT_DIR/bin/seven-public-studio" &&
   grep -q 'key="runtime-labels"' "$ROOT_DIR/bin/seven-public-studio" &&
   grep -q 'settings.system_updates.note' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'tr_text' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'tr_text' "$ROOT_DIR/bin/seven-waybar-center-native" &&
   grep -q 'tr_text' "$ROOT_DIR/bin/seven-notification-center-native" &&
   grep -q 'language_code' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'language_code' "$ROOT_DIR/bin/seven-profile-center-native" &&
   grep -q 'language_code' "$ROOT_DIR/bin/seven-mini-context-menu-native" &&
   grep -q 'FR_TO_EN' "$ROOT_DIR/bin/seven_waybar_app_profiles.py" &&
   grep -q 'ui(' "$ROOT_DIR/bin/seven-waybar-status" &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 "$ROOT_DIR/bin/seven_waybar_app_profiles.py" contract | python -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data.get("schema")=="sevenos.waybar.app-menu-contract.v1" and data.get("state")=="OK" else 1)' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 "$ROOT_DIR/bin/seven_waybar_app_profiles.py" contract | python -c 'import json,sys; data=json.load(sys.stdin); labels={item["id"]: item["file_label"] for item in data.get("checks", [])}; raise SystemExit(0 if data.get("state")=="OK" and labels.get("browser.gmail")=="Message" and labels.get("developer.vscode")=="File" else 1)' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 python -c 'import importlib.util; spec=importlib.util.spec_from_file_location("app_profiles", "bin/seven_waybar_app_profiles.py"); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); labels=mod.context_for_window({"class":"firefox","title":"Example"}, "equinox")["labels"]; title, items=mod.items_for("edit", "browser", "firefox", ""); raise SystemExit(0 if labels["file"]=="File" and title=="Edit" and any(item[1]=="Copy" for item in items) else 1)' &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 python -c 'import importlib.util; spec=importlib.util.spec_from_file_location("app_profiles", "bin/seven_waybar_app_profiles.py"); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); labels=mod.context_for_window({"class":"firefox","title":"Example"}, "equinox")["labels"]; title, items=mod.items_for("edit", "browser", "firefox", ""); raise SystemExit(0 if labels["file"]=="Fichier" and title=="Édition" and any(item[1]=="Copier" for item in items) else 1)' &&
   [[ "$(SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_TEST_APP_CLASS=firefox SEVENOS_TEST_APP_TITLE=Example "$ROOT_DIR/bin/seven-waybar-status" app-menu-item file)" == *"active app menu"* ]] &&
   [[ "$(SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_TEST_APP_CLASS=firefox SEVENOS_TEST_APP_TITLE=Example "$ROOT_DIR/bin/seven-waybar-status" app-menu-item file)" == *"menu de l'app active"* ]] &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 python -c 'import sys; from pathlib import Path; sys.path.insert(0, str(Path("scripts").resolve())); from seven_i18n import tr, tr_text; text="\n".join([tr("settings.system_updates.note"), tr("settings.appearance.subtitle"), tr_text("Control Center"), tr_text("No notifications"), tr_text("Connect, toggle and manage nearby networks")]); blocked=("Liquid glass", "No notifications", "Control Center", "Connect, toggle"); raise SystemExit(0 if not any(item in text for item in blocked) else 1)' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 python -c 'import sys; from pathlib import Path; sys.path.insert(0, str(Path("scripts").resolve())); from seven_i18n import tr, tr_text, language_code; text="\n".join([tr("settings.language_region"), tr_text("Control Center"), tr_text("No notifications")]); raise SystemExit(0 if language_code()=="en" and "Language and Region" in text and "Control Center" in text and "No notifications" in text else 1)' &&
   [[ "$(SEVENOS_LANGUAGE=fr_FR.UTF-8 "$ROOT_DIR/bin/seven-waybar-language")" == *'"text": "FR"'* ]] &&
   [[ "$(SEVENOS_LANGUAGE=en_US.UTF-8 "$ROOT_DIR/bin/seven-waybar-language")" == *'"text": "EN"'* ]] &&
   grep -q 'language_parser' "$ROOT_DIR/bin/seven"; then
  ok "SevenOS exposes dynamic French and English language selection in General settings"
else
  fail "SevenOS language selection should expose dynamic French and English packs from Settings, installer and CLI"
fi

if "$ROOT_DIR/bin/seven-apps" doctor | grep -q 'desktop applications indexed' &&
   "$ROOT_DIR/bin/seven-apps" doctor --json | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven" launchpad doctor --json | python -m json.tool >/dev/null &&
   "$ROOT_DIR/bin/seven-apps" list --json | python -m json.tool >/dev/null; then
  ok "SevenOS Apps indexes installed desktop applications and exposes Launchpad diagnostics"
else
  fail "SevenOS Apps should index installed desktop applications and expose Launchpad diagnostics"
fi

if "$ROOT_DIR/seven-hub/bin/seven-hub" doctor >/dev/null; then
  ok "Seven Hub doctor works"
else
  fail "Seven Hub doctor failed"
fi

hub_product_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" hub status --json)"
actions_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" actions --json)"
if python -m json.tool >/dev/null <<<"$hub_product_json" &&
   HUB_PRODUCT_JSON="$hub_product_json" python - <<'PY' &&
import json
import os

data = json.loads(os.environ["HUB_PRODUCT_JSON"])
contracts = data.get("contracts") or {}
required_actions = set(data.get("required_actions") or [])
ok = (
    data.get("schema") == "sevenos.hub.v1"
    and data.get("level") in {"active", "product-preview"}
    and contracts.get("state_runtime_manifest") is True
    and contracts.get("state_runtime_manifests") is True
    and contracts.get("support") is True
    and "support.status" in required_actions
)
raise SystemExit(0 if ok else 1)
PY
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" hub doctor >/dev/null &&
   grep -q '"hub.status"' <<<"$actions_json"; then
  ok "Seven Hub exposes a product-surface readiness contract"
else
  fail "Seven Hub product-surface readiness contract failed"
fi

if "$ROOT_DIR/seven-hub/bin/seven-control-center" status >/dev/null; then
  ok "Seven Control Center status works"
else
  fail "Seven Control Center status failed"
fi

if grep -q 'def daily_summary' "$ROOT_DIR/seven-hub/bin/seven-control-center" &&
   grep -q 'def primary_summary' "$ROOT_DIR/seven-hub/bin/seven-control-center" &&
   grep -q 'Primary PC' "$ROOT_DIR/seven-hub/bin/seven-control-center" &&
   grep -q 'Daily Driver' "$ROOT_DIR/seven-hub/bin/seven-control-center" &&
   grep -q '"daily-apply"' "$ROOT_DIR/seven-hub/bin/seven-control-center" &&
   grep -q '"primary-apply"' "$ROOT_DIR/seven-hub/bin/seven-control-center" &&
   grep -q 'wallpaper-refresh' "$ROOT_DIR/seven-hub/bin/seven-control-center"; then
  ok "Seven Control Center fallback exposes primary-PC gates and repair actions"
else
  fail "Seven Control Center fallback should expose daily-driver, Core and wallpaper repair actions"
fi

if grep -q 'get_hub_snapshot' "$ROOT_DIR/seven-hub/gui/src-tauri/src/main.rs" &&
   grep -q 'get_action_registry' "$ROOT_DIR/seven-hub/gui/src-tauri/src/main.rs" &&
   grep -q 'run_seven_action' "$ROOT_DIR/seven-hub/gui/src-tauri/src/main.rs" &&
   grep -q 'seven profile status --json' "$ROOT_DIR/seven-hub/gui/src-tauri/src/main.rs" &&
   grep -q '"identifier": "os.seven.seven-hub"' "$ROOT_DIR/seven-hub/gui/src-tauri/tauri.conf.json" &&
   grep -q '"active": false' "$ROOT_DIR/seven-hub/gui/src-tauri/tauri.conf.json" &&
   grep -q 'data-panel="dashboard"' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'confirm-layer' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'nav-label' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'data-section="profiles"' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'get_action_registry' "$ROOT_DIR/seven-hub/gui/src/main.js" &&
   grep -q 'data-action-id' "$ROOT_DIR/seven-hub/gui/src/main.js" &&
   grep -q 'run_seven_command' "$ROOT_DIR/seven-hub/gui/src/main.js" &&
   grep -q 'run_seven_action' "$ROOT_DIR/seven-hub/gui/src/main.js" &&
   grep -q 'actionNeedsConfirmation' "$ROOT_DIR/seven-hub/gui/src/main.js" &&
   grep -q 'summarizeResult' "$ROOT_DIR/seven-hub/gui/src/main.js" &&
   grep -q 'data-impact' "$ROOT_DIR/seven-hub/gui/src/main.js" &&
   grep -q 'seven-window' "$ROOT_DIR/seven-hub/gui/src/styles.css" &&
   grep -q 'overflow-y: auto' "$ROOT_DIR/seven-hub/gui/src/styles.css" &&
   grep -q 'scrollbar-color' "$ROOT_DIR/seven-hub/gui/src/styles.css" &&
   grep -q 'confirm-card' "$ROOT_DIR/seven-hub/gui/src/styles.css"; then
  ok "Seven Hub GUI behaves like a native Control Center foundation"
else
  fail "Seven Hub GUI should expose dashboard, profiles, confirmations, readable actions and native backend snapshot"
fi

keyboard_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" keyboard status --json)"
if python -m json.tool >/dev/null <<<"$keyboard_json" &&
   grep -q '"schema":"sevenos.keyboard.v1"' <<<"$keyboard_json" &&
   grep -q 'kb_layout = us,fr' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'kb_options = grp:alt_shift_toggle' "$ROOT_DIR/hyprland/conf/keyboard.conf"; then
  ok "SevenOS provides US/French keyboard layouts with Alt+Shift switching"
else
  fail "SevenOS keyboard should default to US/French with Alt+Shift switching"
fi

if grep -q 'javascriptcoregtk-4.1' "$ROOT_DIR/seven-hub/gui-stack.sh"; then
  ok "Seven Hub GUI stack reports WebKit and JavaScriptCore native prerequisites"
else
  fail "Seven Hub GUI stack should report WebKit and JavaScriptCore native prerequisites"
fi

if grep -Fq 'GTK4 + libadwaita' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -Fq 'Tauri is useful for fast iteration' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -Fq 'Seven Hub Native' "$ROOT_DIR/seven-hub/native/README.md" &&
   grep -Fq 'seven profile status --json' "$ROOT_DIR/seven-hub/native/README.md" &&
   grep -Fq 'seven actions --json' "$ROOT_DIR/seven-hub/native/README.md" &&
   grep -Fq 'seven ecosystem --json' "$ROOT_DIR/seven-hub/native/README.md" &&
   grep -q 'def render_dashboard' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def state_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def render_search_results' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def render_runtime_compact' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'profile_runtime_manifest' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'profile_runtime_manifests' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def render_actions' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def ecosystem_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def stack_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def shell_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def core_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def core_plan_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def profile_gaps_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def profile_plan_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def experience_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def control_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def events_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def insights_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def phase_gate_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def welcome_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def welcome_plan_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'First-run plan' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def session_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Session:' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def identity_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Beyond the Desktop' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Accent packs' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Active accent pack' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def shield_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def shield_plan_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Shield plan' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def server_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def server_plan_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Server plan' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def atlas_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Atlas Explorer' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def installer_plan_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Installer plan' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def packages_plan_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def packages_strategy_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def packages_catalog_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def packages_footprint_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Software strategy' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Software plan' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Phase Gate' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def b3_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'B3 Consolidation' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Stack Strategy' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Seven Shell' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Seven Core' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -Fq 'seven stack --json' "$ROOT_DIR/seven-hub/native/README.md" &&
   grep -Fq 'seven phase-gate --json' "$ROOT_DIR/seven-hub/native/README.md" &&
   grep -Fq 'seven b3 plan --json' "$ROOT_DIR/seven-hub/native/README.md" &&
   grep -q 'def run_ecosystem_command' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'def render_ecosystem' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'stack.add_titled(ecosystem_scroll' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'stack.add_titled(search_scroll' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'stack.add_titled(runtime_scroll' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-sidebar' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'nav_button(tr("hub.dashboard"' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'nav_button(tr("hub.search"' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'nav_button(tr("hub.runtime"' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-hero' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'metric_card(tr("hub.readiness"' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'from seven_i18n import tr' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'ensure_gtk_python' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'SEVENOS_NATIVE_PYTHON' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'media-playback-start-symbolic' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'icon_for_action' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'set_icon_name' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'render_loading_shell' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'render_dashboard_compact' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'render_profiles_compact' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'render_runtime_compact' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'render_actions_compact' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'smoke_payload' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'Smoke Gate' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-tile' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'seven-glass-strip' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'GLib.timeout_add' "$ROOT_DIR/bin/seven-hub-native" &&
   grep -q 'run_visible' "$ROOT_DIR/bin/seven-hub-native" &&
   "$ROOT_DIR/bin/seven-hub-native" status | grep -q 'Seven Hub' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" hub-native --dry-run | grep -q 'seven-hub-native open' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/seven-hub/bin/seven-hub" | grep -q 'seven-hub-native open' &&
   ! grep -Rqi 'Horizon' "$ROOT_DIR/seven-hub/gui/README.md" "$ROOT_DIR/seven-hub/gui/src-tauri/src/main.rs" "$ROOT_DIR/seven-hub/bin/seven-control-center" &&
   grep -q 'Exec=seven-hub' "$ROOT_DIR/seven-hub/seven-hub.desktop" &&
   grep -q 'Exec=seven-hub-native' "$ROOT_DIR/seven-hub/seven-hub-native.desktop"; then
  ok "Seven Hub native UI strategy is documented and OS-styled"
else
  fail "Seven Hub native UI strategy is missing, unstyled or unclear"
fi

autonomy_json="$(SEVENOS_AUTONOMY_FAST=1 "$ROOT_DIR/scripts/autonomy.sh" json)"
about_json="$("$ROOT_DIR/scripts/about.sh" json)"
about_plan="$("$ROOT_DIR/scripts/about.sh" plan)"
lifecycle_json="$(SEVENOS_LIFECYCLE_FAST=1 "$ROOT_DIR/scripts/lifecycle.sh" json)"
update_json="$(SEVENOS_UPDATE_FAST=1 "$ROOT_DIR/scripts/update.sh" json)"
recovery_json="$(SEVENOS_RECOVERY_FAST=1 "$ROOT_DIR/scripts/recovery.sh" json)"
health_json="$(SEVENOS_HEALTH_FAST=1 "$ROOT_DIR/scripts/health.sh" json)"
smoke_json="$("$ROOT_DIR/scripts/smoke.sh" json)"
support_json="$(SEVENOS_SUPPORT_FAST=1 "$ROOT_DIR/scripts/support.sh" json)"
product_json="$("$ROOT_DIR/scripts/product.sh" json)"
foundations_json="$("$ROOT_DIR/scripts/foundations.sh" json)"
platform_json="$("$ROOT_DIR/scripts/platform.sh" json)"
channel_json="$("$ROOT_DIR/scripts/channel.sh" json)"
mask_json="$("$ROOT_DIR/scripts/mask.sh" json)"
surfaces_json="$("$ROOT_DIR/scripts/surfaces.sh" json)"
routes_json="$("$ROOT_DIR/scripts/routes.sh" json)"
distribution_json="$(SEVENOS_DISTRIBUTION_FAST=1 "$ROOT_DIR/scripts/distribution.sh" json)"
action_runner_dry="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-action-runner" --dry-run -- "$ROOT_DIR/bin/seven" status)"
if grep -q '"schema": "sevenos.autonomy.v1"' <<<"$autonomy_json" &&
   grep -q '"schema": "sevenos.about.v1"' <<<"$about_json" &&
   grep -q 'SevenOS About Plan' <<<"$about_plan" &&
   "$ROOT_DIR/scripts/about.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.lifecycle.v1"' <<<"$lifecycle_json" &&
   SEVENOS_LIFECYCLE_FAST=1 "$ROOT_DIR/scripts/lifecycle.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.update.v1"' <<<"$update_json" &&
   SEVENOS_UPDATE_FAST=1 "$ROOT_DIR/scripts/update.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.recovery.v1"' <<<"$recovery_json" &&
   SEVENOS_RECOVERY_FAST=1 "$ROOT_DIR/scripts/recovery.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.health.v1"' <<<"$health_json" &&
   SEVENOS_HEALTH_FAST=1 "$ROOT_DIR/scripts/health.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.smoke.v1"' <<<"$smoke_json" &&
   "$ROOT_DIR/scripts/smoke.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.support.v1"' <<<"$support_json" &&
   SEVENOS_SUPPORT_FAST=1 "$ROOT_DIR/scripts/support.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.product.v1"' <<<"$product_json" &&
   "$ROOT_DIR/scripts/product.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.foundations.v1"' <<<"$foundations_json" &&
   "$ROOT_DIR/scripts/foundations.sh" doctor >/dev/null &&
   SEVENOS_AUTONOMY_FAST=1 "$ROOT_DIR/scripts/autonomy.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.platform.v1"' <<<"$platform_json" &&
   "$ROOT_DIR/scripts/platform.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.release-channel.v1"' <<<"$channel_json" &&
   "$ROOT_DIR/scripts/channel.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.mask.v1"' <<<"$mask_json" &&
   "$ROOT_DIR/scripts/mask.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.surfaces.v1"' <<<"$surfaces_json" &&
   "$ROOT_DIR/scripts/surfaces.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.routes.v1"' <<<"$routes_json" &&
   "$ROOT_DIR/scripts/routes.sh" doctor >/dev/null &&
   grep -q '"schema": "sevenos.distribution.v1"' <<<"$distribution_json" &&
   grep -q '"key": "public-positioning"' <<<"$distribution_json" &&
   grep -q 'Public SevenOS positioning' <<<"$distribution_json" &&
   SEVENOS_DISTRIBUTION_FAST=1 "$ROOT_DIR/scripts/distribution.sh" doctor >/dev/null &&
   grep -q 'seven status' <<<"$action_runner_dry" &&
   grep -q 'seven about' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'about.doctor' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven lifecycle' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven update' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven recovery' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven health' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven smoke' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven support' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven product' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven foundations' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven autonomy' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven platform' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven channel' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven mask' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven surfaces' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven routes' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'seven distribution' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q '"autonomy":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"about":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"lifecycle":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"update":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"recovery":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"health":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"smoke":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"support":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"product":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"foundations":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"platform":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"channel":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"mask":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"surfaces":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"routes":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"distribution":' "$ROOT_DIR/scripts/state.sh" &&
   grep -q 'SevenOS Distribution Autonomy' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'seven update' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'seven recovery' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'seven health' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'seven smoke' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'seven support' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'Foundations Contract' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'Platform Facade' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'Public Mask Contract' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'Dynamic OS Contract' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'Public Surfaces Contract' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'User Routes Contract' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'Distribution Contract' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'About Contract' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'Lifecycle Contract' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'Product Facade' "$ROOT_DIR/docs/DISTRIBUTION_AUTONOMY.md" &&
   grep -q 'seven-action-runner' "$ROOT_DIR/bin/seven-hub-native"; then
  ok "SevenOS exposes an autonomy layer that masks Arch/Hyprland internals"
else
  fail "SevenOS autonomy layer is missing or not connected to Hub/state/actions"
fi

shell_panel_quick_dry="$(SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-shell-panel" quick)"
shell_panel_notifications_dry="$(SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-shell-panel" notifications)"
shell_panel_quick_fr="$(SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-shell-panel" quick)"
shell_panel_notifications_fr="$(SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-shell-panel" notifications)"
waybar_notifications_dry="$(SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-notifications" menu)"
if grep -q 'DRY-RUN > Shell Panel > Quick > Open native panel' <<<"$shell_panel_quick_dry" &&
   grep -q 'DRY-RUN > Shell Panel > Notifications > Open native panel' <<<"$shell_panel_notifications_dry" &&
   grep -Eq 'No notifications|Notification' <<<"$shell_panel_notifications_dry" &&
   grep -Eq 'Aucune notification|Notification' <<<"$shell_panel_notifications_fr" &&
   grep -q 'Centre de contrôle' <<<"$shell_panel_quick_fr" &&
   grep -Eq 'No notifications|Notification' <<<"$waybar_notifications_dry" &&
   ! grep -q 'Notification Status' <<<"$waybar_notifications_dry" &&
   grep -Eq 'Active profile:|Active:' <<<"$shell_panel_quick_dry" &&
   grep -q 'PROFILE_ACTIONS' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'Forge Apps' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q 'from seven_i18n import tr_text' "$ROOT_DIR/bin/seven-shell-panel" &&
   grep -q '"atlas":' "$ROOT_DIR/bin/seven-shell-panel" &&
   "$ROOT_DIR/bin/seven-quick-settings-native" --probe >/dev/null 2>&1 &&
   grep -q 'SevenQuickSettingsNative' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'from seven_i18n import tr_text' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'build_slider_card' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'build_detail_card' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'nearby_wifi' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'wifi_networks' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'connect_wifi_network' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'bluetooth_device_rows' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'bluetooth_action' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'detail_button_row' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'seven-quick-settings wifi' "$ROOT_DIR/bin/seven-wifi" &&
   grep -q 'seven-quick-settings", "bluetooth"' "$ROOT_DIR/bin/seven-bluetooth" &&
   grep -q 'SEVENOS_CONTROL_CENTER_KEYBOARD' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'def placeholder_snapshot' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'SNAPSHOT_CACHE_FILE' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'QUICK_PID_FILE' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'BLUETOOTH_CACHE_FILE' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'PANEL_ORDER' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'process_is_control_center' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'claim_single_instance' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'handle_panel_request' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q '"toggle"' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'compact_mode' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'def render_panel' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'def build_nav_strip' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'panel_shortcuts' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'def start_refresh' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'def build_audio_panel' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'cached_bluetooth_device_rows' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'apply_snapshot_to_refs' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'control_center_css' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'context_signal' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'SystemSnapshot' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'Confirm this power action' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   grep -q 'Control Center' "$ROOT_DIR/bin/seven-quick-settings-native" &&
   "$ROOT_DIR/bin/seven-notification-center-native" --probe >/dev/null 2>&1 &&
   grep -q 'SevenNotificationCenterNative' "$ROOT_DIR/bin/seven-notification-center-native" &&
   grep -q 'from seven_i18n import tr_text' "$ROOT_DIR/bin/seven-notification-center-native" &&
   grep -q 'notification-card' "$ROOT_DIR/bin/seven-notification-center-native" &&
   grep -q 'action-glyph' "$ROOT_DIR/bin/seven-notification-center-native" &&
   grep -q 'seven-quick-settings-native' "$ROOT_DIR/bin/seven-quick-settings" &&
   grep -q 'seven-notification-center-native' "$ROOT_DIR/bin/seven-waybar-notifications"; then
  ok "Settings, Notifications and active profile actions prefer native OS surfaces"
else
  if "$ROOT_DIR/scripts/surfaces.sh" json | python -c 'import json,sys; data=json.load(sys.stdin); wanted={"settings","quick-settings","notifications","profile-center"}; states={item.get("key"): item.get("state") for item in data.get("surfaces", [])}; raise SystemExit(0 if all(states.get(key)=="OK" for key in wanted) else 1)' &&
     "$ROOT_DIR/bin/seven-quick-settings-native" --probe >/dev/null 2>&1 &&
     "$ROOT_DIR/bin/seven-notification-center-native" --probe >/dev/null 2>&1 &&
     grep -q 'DRY-RUN > Shell Panel > Quick > Open native panel' <<<"$shell_panel_quick_dry" &&
     grep -q 'DRY-RUN > Shell Panel > Notifications > Open native panel' <<<"$shell_panel_notifications_dry"; then
    ok "Settings, Notifications and active profile actions prefer native OS surfaces"
  else
    fail "Settings and Notifications should expose native profile-aware OS surfaces"
  fi
fi

settings_dry="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-settings")"
if grep -q 'DRY-RUN > Settings > Open SevenOS Settings' <<<"$settings_dry" &&
   "$ROOT_DIR/bin/seven-settings-native" --probe >/dev/null 2>&1 &&
   grep -q 'SevenOS Settings' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Langue et région' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'About this SevenOS' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Default apps' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Région et formats' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven doctor open' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'xdg-mime default' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.general' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Wallpaper' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Affichage' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Wi-Fi et réseau' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Keyboard' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Security' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Profiles' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Power' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'Mises à jour' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven update' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'hero-card' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'quick_strip' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings_row' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings_group' "$ROOT_DIR/bin/seven-settings-native" &&
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
	   grep -q 'settings-sudo-askpass.sh' "$ROOT_DIR/bin/seven-settings-native" &&
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
	   grep -q './scripts/update.sh apply --yes' "$ROOT_DIR/bin/seven-settings-native" &&
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
	   grep -q 'mini_os_capability_panel' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Outils d’autres espaces' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Mode d’utilisation SevenOS' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Entretien SevenOS' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Sauvegarde rapide' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'seven motion reduced' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'profile requirements' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'settings-inline-status' "$ROOT_DIR/identity/native/settings.css" &&
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
	   grep -q 'GLib.idle_add' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'set_transition_duration(140)' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'deep_settings_enabled' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q 'Vérification à la demande' "$ROOT_DIR/bin/seven-settings-native" &&
	   grep -q '.settings-row' "$ROOT_DIR/identity/native/settings.css" &&
	   grep -q 'seven-settings' "$ROOT_DIR/bin/seven-spotlight" &&
   grep -q 'Exec=seven-settings' "$ROOT_DIR/seven-hub/seven-settings.desktop"; then
  ok "SevenOS Settings provides a normal-user native configuration center"
else
  fail "SevenOS Settings should be discoverable and cover core normal-user configuration"
fi

ecosystem_json=""
ecosystem_processes=""
ecosystem_summary=""
ecosystem_maturity=""
experience_json=""
adaptive_json=""
adaptive_plan_output=""
control_json=""
events_json=""
insights_json=""
ai_json=""
ai_focus_output=""
shield_json=""
shield_plan_json=""
shield_control_json=""
cyberspace_json=""
cyberspace_plan_json=""
shield_bootstrap_preview=""
server_json=""
server_plan_json=""
welcome_json=""
welcome_plan_json=""
session_json=""
identity_json=""
identity_packs_json=""
identity_current_json=""

ecosystem_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ecosystem --json)"
ecosystem_processes="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" processes)"
ecosystem_summary="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" summary)"
ecosystem_maturity="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" maturity)"
experience_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" experience --json)"
adaptive_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" adaptive --json)"
dynamic_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" dynamic --json)"
adaptive_plan_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" adaptive plan)"
control_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" control --json)"
events_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" events --json)"
insights_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" insights --json)"
ai_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai --json)"
ai_focus_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" ai focus)"
shield_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield status --json)"
shield_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield plan --json)"
shield_control_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield dashboard --json)"
cyberspace_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield mode --json)"
cyberspace_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-daemon" cyberspace-plan --json)"
shield_bootstrap_preview="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/security/shield-workspace.sh" bootstrap)"
server_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" server status --json)"
server_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" server plan --json)"
welcome_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" welcome status --json)"
welcome_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" welcome plan --json)"
session_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" session status --json)"
identity_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" identity --json)"
identity_packs_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" identity packs --json)"
identity_current_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" identity current --json)"
identity_doctor_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" identity doctor --json)"
windows_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" windows plan --json)"
installer_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" installer status --json)"
installer_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" installer plan --json)"
installer_release_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" installer release)"
installer_release_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" installer release --json)"
installer_graphical_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" installer graphical --json)"
installer_graphical_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" installer graphical)"
installer_portal_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-installer" status --json)"
channel_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" channel --json)"
about_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" about --json)"
lifecycle_json="$(SEVENOS_LIFECYCLE_FAST=1 SEVENOS_UPDATE_FAST=1 SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" lifecycle --json)"
update_json="$(SEVENOS_UPDATE_FAST=1 SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" update --json)"
recovery_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" recovery --json)"
health_json="$(SEVENOS_HEALTH_FAST=1 SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" health --json)"
support_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" support --json)"
product_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" product --json)"
foundations_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" foundations --json)"
surfaces_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" surfaces --json)"
routes_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" routes --json)"
distribution_json="$(SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" distribution --json)"
installer_open_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-installer" open)"
packages_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" plan --json)"
packages_strategy_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" strategy --json)"
packages_catalog_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" catalog --json)"
packages_footprint_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" footprint --fast --json)"
package_sources_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" sources --json)"
profile_limits_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" profile-limits --json)"
forge_limits_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" profile-limits forge --json)"
forge_sources_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" forge sources --json)"
forge_packages_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" profile-packages forge --query htop --json)"
missing_rootfs_dir="$(mktemp -d)"
forge_missing_packages="$(SEVENOS_HOST_HOME=/tmp/sevenos-missing-home SEVENOS_HOST_DATA_HOME="$missing_rootfs_dir" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" profile-packages forge --query visual-studio-bin)"
forge_missing_install_json="$(SEVENOS_HOST_HOME=/tmp/sevenos-missing-home SEVENOS_HOST_DATA_HOME="$missing_rootfs_dir" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" install --profile forge visual-studio-bin --source pacman --preview --json)"
forge_shortcut_json="$(SEVENOS_HOST_HOME=/tmp/sevenos-missing-home SEVENOS_HOST_DATA_HOME="$missing_rootfs_dir" SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" forge install visual-studio-bin --source pacman --preview --json)"
studio_shortcut_packages="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" studio packages --query blender)"
pulse_shortcut_update="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" pulse update --preview)"
pulse_doctor_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-pulse" doctor --json)"
pulse_route_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" pulse doctor --json)"
pulse_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" pulse plan --json)"
pulse_rootfs_preview="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-pulse" rootfs --dry-run)"
pulse_launchers_preview="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-pulse" launchers --dry-run)"
pulse_hud_preview="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-pulse" hud --dry-run)"
pulse_helper_preview="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-pulse" helper --dry-run)"
pulse_open_preview="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-pulse" open --dry-run)"
pulse_activate_preview="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-pulse" activate --dry-run)"
mini_doctor_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-mini-doctor" all --json)"
mini_doctor_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" mini-doctor forge plan --json)"
mini_doctor_studio_preview="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-mini-doctor" studio install --dry-run)"
mini_doctor_baobab_preview="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-mini-doctor" baobab rootfs --dry-run)"
forge_helper_preview="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" forge helper paru --preview)"
profile_package_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" install --profile forge htop --source pacman --preview --json)"
profile_remove_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" remove --profile forge 7zip --preview --json)"
profile_remove_missing_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" remove --profile forge definitely-not-installed-sevenos-test-package --preview --json)"
profile_update_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" update --profile forge --preview --json)"
system_package_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" install --profile equinox htop --source pacman --preview --json)"
if grep -q 'profile-install' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'profile-remove' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'profile-limits' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'profile-packages' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'profile-sources' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'profile_sources_payload' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'profile_helper_transaction_commands' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'profile_helper_build_script' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'profile_helper_install_script' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q -- '--rootfs-admin' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q -- '--rootfs-admin' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q 'sevenpkg {profile} helper' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'show_package_removal_dialog' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.package_remove.section' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings:package-remove' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'remove --profile' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.package_remove.confirm' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'profile-packages' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'package-result-list' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'package_search_generation' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'package_preview_generation' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'last_preview' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'preview_required' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'remove_button.set_sensitive(False)' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'payload.get("blockers")' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'settings.package_remove.preview_running' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'GLib.idle_add(apply_preview' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'threading.Thread(target=worker' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'GLib.idle_add(apply_results' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'package-result-button' "$ROOT_DIR/identity/native/settings.css" &&
   grep -q 'default_profile_source' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'global_install' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'sevenos.profile-package-transaction.v1' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'sevenos.profile-package-limits.v1' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'sevenos.profile-package-sources.v1' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'sevenos.package-sources.v1' "$ROOT_DIR/bin/sevenpkg" &&
   grep -q 'global-system' <<<"$profile_limits_json" &&
   grep -q 'profile-rootfs' <<<"$profile_limits_json" &&
   grep -q 'sevenos.profile-package-inventory.v1' <<<"$forge_packages_json" &&
   python -m json.tool <<<"$forge_missing_install_json" >/dev/null &&
   python -m json.tool <<<"$forge_shortcut_json" >/dev/null &&
   grep -q 'rootfs missing' <<<"$forge_missing_packages" &&
   grep -q 'visual-studio-bin -> code' <<<"$forge_missing_packages" &&
   grep -q 'seven profile-rootfs build forge --apply --yes' <<<"$forge_missing_packages" &&
   grep -q '"code"' <<<"$forge_missing_install_json" &&
   grep -q '"code"' <<<"$forge_shortcut_json" &&
   grep -q '"schema": "sevenos.profile-package-sources.v1"' <<<"$forge_sources_json" &&
   grep -q 'helper_command' <<<"$forge_sources_json" &&
   grep -q 'sevenpkg forge install <package> --source pacman' <<<"$forge_sources_json" &&
   grep -q 'seven-profile-rootfs' <<<"$forge_missing_install_json" &&
   grep -q 'seven-profile-rootfs' <<<"$forge_shortcut_json" &&
   grep -q '"rootfs_ready": false' <<<"$forge_missing_install_json" &&
   grep -q '"prepare"' <<<"$forge_missing_install_json" &&
   grep -q 'studio · profile-rootfs' <<<"$studio_shortcut_packages" &&
   grep -q 'pulse · profile-rootfs' <<<"$pulse_shortcut_update" &&
   grep -q 'paru -Sua' <<<"$pulse_shortcut_update" &&
   python -m json.tool <<<"$pulse_doctor_json" >/dev/null &&
   python -m json.tool <<<"$pulse_route_json" >/dev/null &&
   python -m json.tool <<<"$pulse_plan_json" >/dev/null &&
   grep -q '"schema": "sevenos.pulse.doctor.v1"' <<<"$pulse_doctor_json" &&
   grep -q '"schema": "sevenos.pulse.plan.v1"' <<<"$pulse_plan_json" &&
   grep -q '"profile": "pulse"' <<<"$pulse_doctor_json" &&
   grep -q 'install_steam_private' <<<"$pulse_doctor_json" &&
   grep -q 'private_packages' <<<"$pulse_doctor_json" &&
   grep -q 'pulse.install.steam' <<<"$pulse_plan_json" &&
   grep -q 'sevenpkg pulse install steam --source pacman' <<<"$pulse_doctor_json" &&
   grep -q 'driver_hints' <<<"$pulse_doctor_json" &&
   grep -q 'multilib_enabled' <<<"$pulse_doctor_json" &&
   grep -q 'prepare pulse --apply --yes' <<<"$pulse_rootfs_preview" &&
   grep -q 'sevenpkg pulse install steam lutris --source pacman' <<<"$pulse_launchers_preview" &&
   grep -q 'sevenpkg pulse install mangohud gamescope --source pacman' <<<"$pulse_hud_preview" &&
   grep -q 'sevenpkg pulse helper paru' <<<"$pulse_helper_preview" &&
   grep -q 'seven-mini-os-center pulse' <<<"$pulse_open_preview" &&
   grep -q 'seven profile activate pulse' <<<"$pulse_activate_preview" &&
   grep -q 'seven-pulse doctor' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-pulse install' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-pulse launchers' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-pulse hud' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-pulse doctor' "$ROOT_DIR/bin/seven-settings-native" &&
   grep -q 'seven-pulse' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'vulkan-icd-loader' "$ROOT_DIR/scripts/packages-performance.txt" &&
   grep -q 'xdg-desktop-portal-hyprland' "$ROOT_DIR/scripts/packages-performance.txt" &&
   grep -q 'gamescope' "$ROOT_DIR/scripts/packages-performance-optional.txt" &&
   grep -q 'protontricks' "$ROOT_DIR/scripts/packages-performance-optional.txt" &&
   grep -q 'Pulse Gaming Mini OS' "$ROOT_DIR/docs/PULSE_MINI_OS.md" &&
   grep -q 'seven-pulse launchers' "$ROOT_DIR/docs/PULSE_MINI_OS.md" &&
   python -m json.tool <<<"$mini_doctor_json" >/dev/null &&
   python -m json.tool <<<"$mini_doctor_plan_json" >/dev/null &&
   grep -q '"schema": "sevenos.mini-os.doctor-set.v1"' <<<"$mini_doctor_json" &&
   grep -q '"schema": "sevenos.mini-os.plan.v1"' <<<"$mini_doctor_plan_json" &&
   grep -q '"forge"' <<<"$mini_doctor_json" &&
   grep -q '"studio"' <<<"$mini_doctor_json" &&
   grep -q '"baobab"' <<<"$mini_doctor_json" &&
   grep -q '"shield"' <<<"$mini_doctor_json" &&
   grep -Eq 'forge\.(install\.required|optional\.dev)' <<<"$mini_doctor_plan_json" &&
   grep -q 'seven profile requirements studio --apply --yes' <<<"$mini_doctor_studio_preview" &&
   grep -q 'seven profile-rootfs prepare baobab --apply --yes' <<<"$mini_doctor_baobab_preview" &&
   grep -q 'seven-mini-doctor forge' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-mini-doctor shield' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-mini-doctor studio' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-mini-doctor baobab' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-mini-doctor' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q 'scripts/packages-dev-optional.txt' "$ROOT_DIR/profiles/catalog.json" &&
   grep -q 'scripts/packages-creation-optional.txt' "$ROOT_DIR/profiles/catalog.json" &&
   grep -q 'podman' "$ROOT_DIR/scripts/packages-dev.txt" &&
   grep -q 'pipewire-jack' "$ROOT_DIR/scripts/packages-creation.txt" &&
   grep -q 'kiwix-desktop' "$ROOT_DIR/scripts/packages-culture.txt" &&
   grep -q 'Mini OS Requirements' "$ROOT_DIR/docs/MINI_OS_REQUIREMENTS.md" &&
   grep -q 'private to forge' <<<"$forge_helper_preview" &&
   grep -Eq 'AUR helper|already available inside forge' <<<"$forge_helper_preview" &&
   grep -Eq 'base-devel|already available inside forge' <<<"$forge_helper_preview" &&
   grep -Eq 'makepkg -s --noconfirm|already available inside forge' <<<"$forge_helper_preview" &&
   grep -Eq 'pacman -U --needed --noconfirm|already available inside forge' <<<"$forge_helper_preview" &&
   grep -Eq -- '--rootfs-admin|already available inside forge' <<<"$forge_helper_preview" &&
   grep -Eq 'https://aur.archlinux.org/paru.git|already available inside forge' <<<"$forge_helper_preview" &&
   grep -q '"profile_filter": "forge"' <<<"$forge_limits_json" &&
   grep -q 'next_actions' <<<"$forge_limits_json" &&
   grep -q 'sevenrepo' <<<"$package_sources_json" &&
   grep -q 'profile-rootfs-packages' <<<"$profile_package_json" &&
   grep -q '"action": "remove"' <<<"$profile_remove_json" &&
   grep -Eq 'not installed inside the forge rootfs|forge rootfs is not ready' <<<"$profile_remove_missing_json" &&
   grep -q '"action": "update"' <<<"$profile_update_json" &&
   grep -q 'pacman' <<<"$profile_update_json" &&
   grep -q 'does not touch other mini OS' <<<"$profile_remove_json" &&
   grep -q 'global-system-packages' <<<"$system_package_json" &&
   grep -q 'private to forge' <<<"$profile_package_json"; then
  ok "SevenPkg separates mini OS rootfs packages from Equinox global packages"
else
  fail "SevenPkg should provide profile-scoped package transactions"
fi
core_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core status --json)"
core_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core plan --json)"
core_snapshot_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core snapshot --json)"
core_health_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core health --json)"
core_profiles_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" core profiles --json)"
core_observe_json="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/core.sh" observe --json)"
context_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" context status --json)"
scheduler_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" scheduler status --json)"
runtime_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" runtime status --json)"
runtime_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" runtime plan forge shield studio --json)"
shell_status_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shell status --json)"
b3_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" b3 plan --json)"
sevenpkg_status_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" status --json)"
manifest_summary_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/manifest.sh" summary-json)"
state_fast_json="$(SEVENOS_UPDATE_FAST=1 SEVENOS_HEALTH_FAST=1 SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" state --json)"

core_json_contract_state="MISS"
if python -m json.tool <<<"$state_fast_json" >/dev/null &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.core.v1"' <<<"$core_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.packages-plan.v1"' <<<"$packages_plan_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.sevenpkg-strategy.v1"' <<<"$packages_strategy_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.app-catalog.v1"' <<<"$packages_catalog_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.sevenpkg-footprint.v1"' <<<"$packages_footprint_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.runtime-orchestrator.v1"' <<<"$runtime_json" &&
   python -c 'import json,sys; data=json.load(sys.stdin); required={"welcome","session","identity","profile_run","profile_runtime_manifest","profile_runtime_manifests","profile_gaps","profile_plan","profile_health","atlas","shield","cyberspace","server","installer","packages","packages_plan","packages_strategy","packages_catalog","packages_footprint","store","ecosystem","shell","core","core_snapshot","core_health","context","scheduler","runtime","experience","control","events","adaptive","about","lifecycle","update","recovery","health","smoke","support","product","foundations","platform","mask","surfaces","routes","distribution","language","language_audit","first_run"}; catalog=data.get("packages_catalog") or {}; first_keys={item.get("key") for item in data.get("first_run",{}).get("fresh_install",{}).get("checks",[]) if isinstance(item,dict)}; ok=required.issubset(data) and data.get("smoke",{}).get("schema")=="sevenos.smoke.v1" and data.get("language",{}).get("schema")=="sevenos.language-doctor.v1" and data.get("language_audit",{}).get("schema")=="sevenos.language-runtime-audit.v1" and data.get("first_run",{}).get("schema")=="sevenos.public-studio.v1" and {"language-contract","runtime-labels"}.issubset(first_keys) and catalog.get("schema")=="sevenos.app-catalog.v1" and int(catalog.get("count",0) or 0) >= 12; raise SystemExit(0 if ok else 1)' <<<"$state_fast_json"; then
  core_json_contract_state="OK"
fi
if [[ "$core_json_contract_state" == "OK" ]] || { SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" status --json | python -m json.tool >/dev/null &&
   SEVENOS_UPDATE_FAST=1 SEVENOS_HEALTH_FAST=1 SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" state --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile status --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile current --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile apps --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile gaps --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile plan --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield workspace --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield scope --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield workspaces --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield layout recon --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" shield hud --json | python -m json.tool >/dev/null &&
   grep -q 'shield.json' <<<"$shield_bootstrap_preview" &&
   python -m json.tool <<<"$welcome_json" >/dev/null &&
   python -m json.tool <<<"$welcome_plan_json" >/dev/null &&
   python -m json.tool <<<"$session_json" >/dev/null &&
   python -m json.tool <<<"$identity_json" >/dev/null &&
   python -m json.tool <<<"$identity_packs_json" >/dev/null &&
   python -m json.tool <<<"$identity_current_json" >/dev/null &&
   python -m json.tool <<<"$identity_doctor_json" >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" windows status --json | python -m json.tool >/dev/null &&
   python -m json.tool <<<"$windows_plan_json" >/dev/null &&
   python -m json.tool <<<"$ecosystem_json" >/dev/null &&
   python -m json.tool <<<"$experience_json" >/dev/null &&
   python -m json.tool <<<"$control_json" >/dev/null &&
   python -m json.tool <<<"$events_json" >/dev/null &&
   python -m json.tool <<<"$insights_json" >/dev/null &&
   python -m json.tool <<<"$ai_json" >/dev/null &&
   python -m json.tool <<<"$shield_json" >/dev/null &&
   python -m json.tool <<<"$shield_plan_json" >/dev/null &&
   python -m json.tool <<<"$cyberspace_json" >/dev/null &&
   python -m json.tool <<<"$cyberspace_plan_json" >/dev/null &&
   python -m json.tool <<<"$server_json" >/dev/null &&
   python -m json.tool <<<"$server_plan_json" >/dev/null &&
   python -m json.tool <<<"$installer_json" >/dev/null &&
   python -m json.tool <<<"$installer_plan_json" >/dev/null &&
   python -m json.tool <<<"$installer_release_json" >/dev/null &&
   python -m json.tool <<<"$installer_graphical_json" >/dev/null &&
   python -m json.tool <<<"$installer_portal_json" >/dev/null &&
   python -m json.tool <<<"$channel_json" >/dev/null &&
   python -m json.tool <<<"$about_json" >/dev/null &&
   python -m json.tool <<<"$lifecycle_json" >/dev/null &&
   python -m json.tool <<<"$product_json" >/dev/null &&
   python -m json.tool <<<"$surfaces_json" >/dev/null &&
   python -m json.tool <<<"$routes_json" >/dev/null &&
   python -m json.tool <<<"$distribution_json" >/dev/null &&
   python -m json.tool <<<"$packages_plan_json" >/dev/null &&
   python -m json.tool <<<"$adaptive_json" >/dev/null &&
   python -m json.tool <<<"$core_json" >/dev/null &&
   python -m json.tool <<<"$core_plan_json" >/dev/null &&
   python -m json.tool <<<"$core_snapshot_json" >/dev/null &&
   python -m json.tool <<<"$core_health_json" >/dev/null &&
   python -m json.tool <<<"$core_profiles_json" >/dev/null &&
   python -m json.tool <<<"$core_observe_json" >/dev/null &&
   python -m json.tool <<<"$context_json" >/dev/null &&
   python -m json.tool <<<"$scheduler_json" >/dev/null &&
   python -m json.tool <<<"$runtime_json" >/dev/null &&
   python -m json.tool <<<"$runtime_plan_json" >/dev/null &&
   python -m json.tool <<<"$shell_status_json" >/dev/null &&
   python -m json.tool <<<"$b3_json" >/dev/null &&
   grep -q '"schema": "sevenos.experience.v1"' <<<"$experience_json" &&
   grep -q '"schema": "sevenos.adaptive-ui.v1"' <<<"$adaptive_json" &&
   grep -q '"schema": "sevenos.surfaces.v1"' <<<"$surfaces_json" &&
   grep -q '"state": "productized"' <<<"$surfaces_json" &&
   grep -q '"schema": "sevenos.routes.v1"' <<<"$routes_json" &&
   grep -q '"state": "routed"' <<<"$routes_json" &&
   grep -q '"schema": "sevenos.distribution.v1"' <<<"$distribution_json" &&
   grep -q '"daily_driver_ready": true' <<<"$distribution_json" &&
   grep -q '"key": "foundations"' <<<"$distribution_json" &&
   grep -q '"dynamic_inputs"' <<<"$adaptive_json" &&
   grep -q '"profile-ui-bus"' <<<"$adaptive_json" &&
   grep -q '"wallpaper-palette"' <<<"$adaptive_json" &&
   grep -q 'SevenOS Adaptive UI Plan' <<<"$adaptive_plan_output" &&
   grep -q '"dynamic_inputs"' <<<"$dynamic_json" &&
   grep -q '"schema": "sevenos.control.v1"' <<<"$control_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.events.v1"' <<<"$events_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.insights.v1"' <<<"$insights_json" &&
   grep -Eq '"writer"[[:space:]]*:[[:space:]]*"seven-daemon"' <<<"$insights_json" &&
   grep -q '"schema": "sevenos.ai-local.v1"' <<<"$ai_json" &&
   grep -q '"focus"' <<<"$ai_json" &&
   grep -q 'SevenAI Product Focus' <<<"$ai_focus_output" &&
   grep -q '"schema": "sevenos.welcome.v1"' <<<"$welcome_json" &&
   grep -q '"schema": "sevenos.welcome-plan.v1"' <<<"$welcome_plan_json" &&
   grep -q '"schema": "sevenos.session.v1"' <<<"$session_json" &&
   grep -q '"schema": "sevenos.identity.v2"' <<<"$identity_json" &&
   grep -q '"profiles"' <<<"$identity_json" &&
   grep -q '"schema": "sevenos.accent-packs.v1"' <<<"$identity_packs_json" &&
   grep -q 'pan-african' <<<"$identity_packs_json" &&
   grep -q '"schema": "sevenos.identity-current.v1"' <<<"$identity_current_json" &&
   grep -q '"pack"' <<<"$identity_current_json" &&
   grep -q '"schema": "sevenos.identity-doctor.v1"' <<<"$identity_doctor_json" &&
   grep -Eq '"state"[[:space:]]*:[[:space:]]*"(ready|partial)"' <<<"$identity_doctor_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.shield.v1"' <<<"$shield_json" &&
   grep -q '"writer":"seven-daemon"' <<<"$shield_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.shield-plan.v1"' <<<"$shield_plan_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.shield-control.v1"' <<<"$shield_control_json" &&
   grep -q '"quick_actions"' <<<"$shield_control_json" &&
   grep -q '"scope"' <<<"$shield_control_json" &&
   grep -q '"labs"' <<<"$shield_control_json" &&
   grep -q '"tools"' <<<"$shield_control_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.cyberspace.v1"' <<<"$cyberspace_json" &&
   grep -Eq '"writer"[[:space:]]*:[[:space:]]*"seven-daemon"' <<<"$cyberspace_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.cyberspace-plan.v1"' <<<"$cyberspace_plan_json" &&
   grep -q '"workspaces"' <<<"$cyberspace_json" &&
   grep -q '"recon"' <<<"$cyberspace_json" &&
   grep -q '"sandbox"' <<<"$cyberspace_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.server.v1"' <<<"$server_json" &&
   grep -q '"writer":"seven-daemon"' <<<"$server_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.server-plan.v1"' <<<"$server_plan_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.windows-plan.v1"' <<<"$windows_plan_json" &&
   grep -Eq '"writer"[[:space:]]*:[[:space:]]*"seven-daemon"' <<<"$windows_plan_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.installer.v1"' <<<"$installer_json" &&
   grep -q '"writer":"seven-daemon"' <<<"$installer_json" &&
   grep -q '"release"' <<<"$installer_json" &&
   grep -q 'sevenos.installer-release.v1' <<<"$installer_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.installer-plan.v1"' <<<"$installer_plan_json" &&
   grep -q '"release"' <<<"$installer_plan_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.installer-release.v1"' <<<"$installer_release_json" &&
   grep -q '"graphical-launcher"' <<<"$installer_release_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.installer-graphical.v1"' <<<"$installer_graphical_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.installer-portal.v1"' <<<"$installer_portal_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.release-channel.v1"' <<<"$channel_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.about.v1"' <<<"$about_json" &&
   grep -q '"name": "SevenOS"' <<<"$about_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.lifecycle.v1"' <<<"$lifecycle_json" &&
   grep -q '"state": "managed"' <<<"$lifecycle_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.update.v1"' <<<"$update_json" &&
   grep -Eq '"state"[[:space:]]*:[[:space:]]*"(ready|updates-available|partial)"' <<<"$update_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.recovery.v1"' <<<"$recovery_json" &&
   grep -Eq '"state"[[:space:]]*:[[:space:]]*"(ready|partial)"' <<<"$recovery_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.health.v1"' <<<"$health_json" &&
   grep -Eq '"state"[[:space:]]*:[[:space:]]*"(healthy|attention|degraded)"' <<<"$health_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.support.v1"' <<<"$support_json" &&
   grep -Eq '"state"[[:space:]]*:[[:space:]]*"(ready|partial|foundation)"' <<<"$support_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.product.v1"' <<<"$product_json" &&
   grep -q '"state": "ready"' <<<"$product_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.foundations.v1"' <<<"$foundations_json" &&
   grep -Eq '"state"[[:space:]]*:[[:space:]]*"(sevenos-owned|mostly-owned)"' <<<"$foundations_json" &&
   grep -q '"installer-portal"' <<<"$installer_release_json" &&
   grep -q 'graphical-profile-ready' <<<"$installer_graphical_json" &&
   grep -q 'SevenOS Graphical Installer Route' <<<"$installer_graphical_output" &&
   grep -q 'seven installer release' <<<"$installer_open_output" &&
   grep -q 'Exec=seven-installer' "$ROOT_DIR/archiso/profile/airootfs/usr/share/applications/seven-installer.desktop" &&
   grep -q 'SevenOS Installer Release Readiness' <<<"$installer_release_output" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.packages-plan.v1"' <<<"$packages_plan_json" &&
   grep -Eq '"writer"[[:space:]]*:[[:space:]]*"seven-daemon"' <<<"$packages_plan_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.core.v1"' <<<"$core_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.core-plan.v1"' <<<"$core_plan_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.daemon.snapshot.v1"' <<<"$core_snapshot_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.daemon.health.v1"' <<<"$core_health_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.daemon.profiles.v1"' <<<"$core_profiles_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.context.emit.v1"' <<<"$core_observe_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.context.v1"' <<<"$context_json" &&
   grep -q '"primary_context"' <<<"$context_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.scheduler.v1"' <<<"$scheduler_json" &&
   grep -Eq '"state"[[:space:]]*:[[:space:]]*"active-user-space-executor"' <<<"$scheduler_json" &&
   grep -q '"active_policy"' <<<"$scheduler_json" &&
   grep -q 'safe renice executor' <<<"$scheduler_json" &&
   grep -q 'sevenos.scheduler-apply.v1' "$ROOT_DIR/scripts/scheduler.sh" &&
   grep -q '"runtime"' <<<"$state_json" &&
   grep -q '"profile_run"' <<<"$state_json" &&
   grep -q '"profile_runtime_manifest"' <<<"$state_json" &&
   grep -q '"profile_runtime_manifests"' <<<"$state_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.runtime-orchestrator.v1"' <<<"$runtime_json" &&
   grep -q '"capability_fusion"' <<<"$runtime_json" &&
   grep -q '"conflict_resolver"' <<<"$runtime_json" &&
   grep -q '"primary_profile"' <<<"$runtime_plan_json" &&
   grep -q '"shield"' <<<"$runtime_plan_json" &&
   grep -q '"studio"' <<<"$runtime_plan_json" &&
   grep -q '"runtime_health":' <<<"$shell_status_json" &&
   grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.b3.v1"' <<<"$b3_json" &&
   grep -q '"targets":' <<<"$b3_json" &&
   grep -q '"phase_state":' <<<"$b3_json" &&
   grep -q '"blocked_by":' <<<"$b3_json" &&
   grep -q '"processes"' <<<"$ecosystem_json" &&
   grep -q '"maturity"' <<<"$ecosystem_json" &&
   grep -q 'SevenOS All-In-One Process Map' <<<"$ecosystem_processes" &&
   grep -q 'SevenOS Ecosystem:' <<<"$ecosystem_summary" &&
   grep -q 'SevenOS Ecosystem Maturity' <<<"$ecosystem_maturity" &&
   python -m json.tool <<<"$sevenpkg_status_json" >/dev/null &&
   python -m json.tool <<<"$manifest_summary_json" >/dev/null &&
   python -c 'import json,sys; data=json.load(sys.stdin); catalog=data.get("packages_catalog") or {}; first_keys={item.get("key") for item in data.get("first_run",{}).get("fresh_install",{}).get("checks",[]) if isinstance(item,dict)}; ok={"welcome","welcome_plan","session","identity","design","icons","manifest","active_profile","profile_run","profile_runtime_manifest","profile_runtime_manifests","profile_gaps","profile_plan","profile_health","atlas","atlas_plan","shield","shield_plan","cyberspace","cyberspace_plan","server","server_plan","installer","installer_plan","packages","packages_plan","packages_strategy","packages_catalog","packages_footprint","store","box","cloud","flow","cluster","ecosystem","stack","shell","core","core_snapshot","core_health","context","scheduler","runtime","experience","control","b3","daily","events","adaptive","autonomy","about","lifecycle","update","recovery","health","smoke","support","product","foundations","platform","mask","surfaces","routes","distribution","language","language_audit","first_run"}.issubset(data) and data.get("smoke",{}).get("schema")=="sevenos.smoke.v1" and data.get("language",{}).get("schema")=="sevenos.language-doctor.v1" and data.get("language_audit",{}).get("schema")=="sevenos.language-runtime-audit.v1" and data.get("first_run",{}).get("schema")=="sevenos.public-studio.v1" and {"language-contract","runtime-labels"}.issubset(first_keys) and int(catalog.get("count",0) or 0) >= 12; raise SystemExit(0 if ok else 1)' <<<"$state_fast_json"; }; then
  ok "SevenOS core commands expose stable JSON for the Hub"
else
  fail "SevenOS core commands must expose JSON for GUI integration"
fi

profile_show_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile show forge)"
profile_activate_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/profiles/profile-manager.sh" activate studio)"
profile_json_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile status --json)"
profile_catalog_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile catalog --json)"
profile_aliases_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile aliases --json)"
profile_migration_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile migrate-aliases --json)"
profile_isolation_json="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/profile-isolation.sh" apply equinox forge --yes --json)"
runtime_alias_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" runtime plan horizon shield --json)"
mini_os_alias_plan_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/mini-os-bridge.sh" plan horizon shield --json)"
if grep -q 'Workspace:' <<<"$profile_show_output" &&
   grep -q 'profile.env' <<<"$profile_activate_output" &&
   grep -q 'profile.lock' <<<"$profile_activate_output" &&
   grep -q 'seven profile migrate-aliases --apply' <<<"$profile_activate_output" &&
   grep -q 'seven runtime activate' <<<"$profile_activate_output" &&
   grep -q '"active"' <<<"$profile_json_output" &&
   PROFILE_JSON_OUTPUT="$profile_json_output" python -c 'import json,os,sys; data=json.loads(os.environ["PROFILE_JSON_OUTPUT"]); keys=[item.get("key") for item in data]; raise SystemExit(0 if len(keys)==7 and "horizon" not in keys else 1)' &&
   python -m json.tool <<<"$profile_catalog_json" >/dev/null &&
   python -m json.tool <<<"$profile_aliases_output" >/dev/null &&
   python -m json.tool <<<"$profile_migration_output" >/dev/null &&
   python -m json.tool <<<"$profile_isolation_json" >/dev/null &&
   grep -q '"default_profile": "equinox"' <<<"$profile_catalog_json" &&
   grep -q '"profile_model"' <<<"$profile_catalog_json" &&
   grep -q '"mini_os": true' <<<"$profile_catalog_json" &&
   grep -q '"Atlas Explorer"' <<<"$profile_catalog_json" &&
   grep -q '"Baobab Cultural OS"' <<<"$profile_catalog_json" &&
   grep -q '"redirects_to"[[:space:]]*:[[:space:]]*"forge"' <<<"$profile_aliases_output" &&
   grep -q '"pending"[[:space:]]*:[[:space:]]*0' <<<"$profile_migration_output" &&
   RUNTIME_ALIAS_PLAN_JSON="$runtime_alias_plan_json" python -c 'import json,os; data=json.loads(os.environ["RUNTIME_ALIAS_PLAN_JSON"]); raise SystemExit(0 if data.get("primary_profile", {}).get("key") == "forge" and "shield" in data.get("composite_runtime", {}).get("injected_profiles", []) else 1)' &&
   MINI_OS_ALIAS_PLAN_JSON="$mini_os_alias_plan_json" python -c 'import json,os; data=json.loads(os.environ["MINI_OS_ALIAS_PLAN_JSON"]); raise SystemExit(0 if data.get("primary") == "forge" and "shield" in data.get("capabilities", []) else 1)' &&
   grep -q '"schema": "sevenos.profile-isolation.v1"' <<<"$profile_isolation_json" &&
   PROFILE_ISOLATION_JSON="$profile_isolation_json" python -c 'import json,os; data=json.loads(os.environ["PROFILE_ISOLATION_JSON"]); overlays=data.get("profile_overlays",{}); containers=data.get("profile_containers",{}); strict=data.get("strict_runtime",{}); equinox=containers.get("equinox",{}); other=[item for key,item in containers.items() if key!="equinox"]; raise SystemExit(0 if overlays and containers and strict and all(item.get("state")=="prepared" for item in overlays.values()) and equinox.get("state")=="system" and equinox.get("launch_mode")=="host-system" and all(item.get("state")=="prepared" and item.get("launch_mode")=="available-via-seven-profile-run-container" for item in other) and all(item.get("score",0) >= 70 for item in strict.values()) else 1)' &&
   grep -q 'seven-profile-run' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q '^#!/usr/bin/python3' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q 'sevenos.profile-run.v1' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q 'sevenos.profile-runtime-manifest.v1' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q -- '--profile' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q -- '--workspace' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q -- '--ephemeral' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q -- '--manifest' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q 'SEVENOS_EPHEMERAL' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q -- '--workspace-profile' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q 'profile_default' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q 'explicit-bind-only' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q 'profile-home-cache-data' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -Fq 'seven profile exec <profile> [--container|--rootfs|--independent] [--ephemeral] [--workspace PATH|--workspace-profile]' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'profile-folder-grants.json' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'equinox_system_ready' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'runtime_contract' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'host-system' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'HOST_CONFIG_HOME' "$ROOT_DIR/profiles/profile-manager.sh" &&
   grep -q 'sevenos.system-profile.v1' "$ROOT_DIR/scripts/system-profile.sh" &&
   grep -q 'system-profile' "$ROOT_DIR/install.sh" &&
   grep -q 'system-profile' "$ROOT_DIR/bin/seven" &&
   grep -q 'seven-system-profile' "$ROOT_DIR/scripts/install-cli.sh" &&
   grep -q '"system_profile"' "$ROOT_DIR/scripts/status.sh" &&
   grep -q 'external_folders' "$ROOT_DIR/bin/seven-profile-run" &&
   grep -q 'profile.grant.repo' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.open.repo' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.strict.active' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.strict.manifest' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.strict.workspace' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.strict.profile_workspace' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.strict.ephemeral' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.strict.shield_ephemeral' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.strict.baobab' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'profile.strict.atlas' "$ROOT_DIR/scripts/actions.sh" &&
   grep -q 'strict_runtime' "$ROOT_DIR/scripts/profile-isolation.sh" &&
   grep -q 'runtime_manifests' "$ROOT_DIR/scripts/profile-isolation.sh" &&
   grep -q 'manifest_command' "$ROOT_DIR/scripts/profile-isolation.sh" &&
   grep -q '"profile_run"' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"profile_runtime_manifest"' "$ROOT_DIR/scripts/state.sh" &&
   grep -q '"profile_runtime_manifests"' "$ROOT_DIR/scripts/state.sh" &&
   grep -q 'Limite stricte' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'Strict boundary' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-terminal.*seven-profile-run --profile' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'Shell espace' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'Workspace shell' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'Shell temporaire' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'Ephemeral shell' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q -- '--workspace-profile' "$ROOT_DIR/bin/seven-mini-os-center" &&
   grep -q 'seven-profile-run --profile shield --container' "$ROOT_DIR/docs/PROFILE_ISOLATION.md" &&
   grep -q 'seven-profile-run --profile <profile> --manifest' "$ROOT_DIR/docs/PROFILE_ISOLATION.md" &&
   grep -q 'seven-profile-run --profile forge --container --workspace' "$ROOT_DIR/docs/PROFILE_ISOLATION.md" &&
   grep -q 'seven-profile-run --profile forge --container --workspace-profile' "$ROOT_DIR/docs/PROFILE_ISOLATION.md" &&
   grep -q 'seven-profile-run --profile shield --ephemeral' "$ROOT_DIR/docs/PROFILE_ISOLATION.md" &&
   grep -q 'protected_commands' "$ROOT_DIR/scripts/profile-isolation.sh" &&
   grep -q '"python3"' "$ROOT_DIR/scripts/profile-isolation.sh" &&
   grep -q '"bwrap"' "$ROOT_DIR/scripts/profile-isolation.sh" &&
   grep -q '"firejail"' "$ROOT_DIR/scripts/profile-isolation.sh" &&
   grep -q 'SEVENOS_PROFILE_SHIMS' "$ROOT_DIR/branding/shell/terminal-bashrc" &&
   grep -q 'SEVENOS_PROFILE_SHIMS' "$ROOT_DIR/branding/shell/terminal-zsh/.zshrc" &&
   grep -q '"runtime_context"' "$ROOT_DIR/bin/seven-profile-theme" &&
   grep -q 'temporary_optimization' "$ROOT_DIR/bin/seven-profile-theme" &&
   grep -q 'runtime_context' "$ROOT_DIR/bin/seven-mini-os-center" &&
   ! grep -Eq ':-baobab|ACTIVE_PROFILE", "baobab"|return "Baobab", "unknown"' "$ROOT_DIR/scripts/context.sh" "$ROOT_DIR/scripts/scheduler.sh" "$ROOT_DIR/bin/seven-shell-panel" "$ROOT_DIR/bin/seven-quick-settings-native" "$ROOT_DIR/bin/seven-settings-native"; then
  ok "SevenOS profiles expose concrete state, activation and workspaces"
else
  fail "SevenOS profiles should expose state, activation and workspaces"
fi

if "$ROOT_DIR/scripts/terminal-guard.sh" check >/dev/null; then
  ok "Seven Terminal executes commands across mini OS profiles with isolation shims active"
else
  fail "Seven Terminal command execution guard failed"
fi

if SEVENOS_DRY_RUN=1 "$ROOT_DIR/seven-hub/bin/seven-control-center" open | grep -q 'xdg-open http://127.0.0.1:7787'; then
  ok "Seven Control Center open dry-run works"
else
  fail "Seven Control Center open dry-run failed"
fi

if grep -q 'seven ecosystem' "$ROOT_DIR/branding/motd" &&
   grep -q 'Beyond the Desktop' "$ROOT_DIR/branding/issue" &&
   grep -q 'seven ecosystem' "$ROOT_DIR/archiso/profile/airootfs/etc/motd"; then
  ok "Branding exposes SevenOS ecosystem identity"
else
  fail "Branding is not aligned with ecosystem identity"
fi

hybrid_arch_json="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" architecture matrix --json)"
if "$ROOT_DIR/scripts/architecture.sh" doctor >/dev/null &&
   "$ROOT_DIR/scripts/architecture.sh" hybrid | grep -q 'user-space' &&
   "$ROOT_DIR/scripts/architecture.sh" matrix | grep -q 'Hybrid Architecture Matrix' &&
   python -m json.tool <<<"$hybrid_arch_json" >/dev/null &&
   grep -q '"schema": "sevenos.hybrid-architecture.v1"' <<<"$hybrid_arch_json" &&
   grep -q '"SevenAI Layer"' <<<"$hybrid_arch_json" &&
   grep -q '"Seven Runtime Orchestrator"' <<<"$hybrid_arch_json" &&
   grep -q '"Seven System Orchestration Layer"' <<<"$hybrid_arch_json" &&
   grep -q '"User-Space Services Layer"' <<<"$hybrid_arch_json" &&
   grep -q '"contracts"' <<<"$hybrid_arch_json" &&
   grep -q '"capabilities"' <<<"$hybrid_arch_json" &&
   grep -q '"next_actions"' <<<"$hybrid_arch_json" &&
   grep -q 'SevenAI Layer' "$ROOT_DIR/docs/HYBRID_OS_ARCHITECTURE.md" &&
   grep -q 'Seven Runtime Orchestrator' "$ROOT_DIR/docs/HYBRID_OS_ARCHITECTURE.md" &&
   grep -q 'Seven System Orchestration' "$ROOT_DIR/docs/HYBRID_OS_ARCHITECTURE.md"; then
  ok "SevenOS architecture doctor works"
else
  fail "SevenOS architecture doctor failed"
fi

if "$ROOT_DIR/scripts/manifest.sh" doctor >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" manifest restore-plan | grep -q 'Hyprland user override' &&
   "$ROOT_DIR/scripts/package-plan.sh" plan | grep -q 'sevenos-hyprland' &&
   python - "$ROOT_DIR/sevenos.dotinst" <<'PY' >/dev/null
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

component_ids = {item.get("id") for item in manifest.get("components", [])}
required = {
    "sevenos-cli",
    "sevenos-branding",
    "sevenos-hyprland",
    "sevenos-hub",
    "sevenos-profiles",
    "sevenos-server",
    "sevenos-installer",
}
if not required.issubset(component_ids):
    missing = ", ".join(sorted(required - component_ids))
    raise SystemExit(f"missing components: {missing}")
if "~/.config/hypr/conf/custom.conf" not in manifest.get("protected", []):
    raise SystemExit("missing protected custom Hyprland path")
PY
then
  ok "SevenOS install manifest defines package boundaries and protected user paths"
else
  fail "SevenOS install manifest is incomplete"
fi

package_plan_out="$(mktemp -d)"
if SEVENOS_PACKAGE_OUT="$package_plan_out" "$ROOT_DIR/scripts/package-plan.sh" generate >/dev/null &&
   SEVENOS_PACKAGE_OUT="$package_plan_out" "$ROOT_DIR/scripts/package-plan.sh" doctor | grep -q 'SevenOS package plan OK' &&
   [[ -s "$package_plan_out/sevenos-cli/PKGBUILD" ]] &&
   grep -q 'pkgname=sevenos-hyprland' "$package_plan_out/sevenos-hyprland/PKGBUILD"; then
  ok "SevenOS package skeletons can be generated from the manifest"
else
  fail "SevenOS package skeleton generation failed"
fi
rm -rf "$package_plan_out"

migration_plan_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/migrate.sh" plan)"
migration_backup_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/migrate.sh" backup)"
migration_seven_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" migrate backup)"
if [[ "$migration_plan_output" == *"SevenOS migration plan"* ]] &&
   [[ "$migration_backup_output" == *"sevenos/migrations"* ]] &&
   [[ "$migration_seven_output" == *"scripts/migrate.sh backup"* ]]; then
  ok "SevenOS migration planner protects user state before upgrades"
else
  fail "SevenOS migration planner is missing"
fi

if grep -q 'path == "/state"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/welcome"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/welcome-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/session"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/identity"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/profiles"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/profile-gaps"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/profile-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/windows-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/installer-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/packages-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/store"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/box"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/cloud"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/flow"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/cluster"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/manifest"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/actions"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/stack"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/shell"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/shell-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/core-snapshot"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/core-health"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/experience"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/shield"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/shield-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/cyberspace"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/cyberspace-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/server-plan"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/control"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/b3"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/daily"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/events"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'path == "/insights"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'curl http://127.0.0.1:7777/state' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/welcome' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/welcome-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/session' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/identity' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/profile-gaps' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/profile-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/windows-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/installer-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/cyberspace' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/cyberspace-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/packages-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/store' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/box' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/cloud' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/flow' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/cluster' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/actions' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/stack' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/shell' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/shell-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/core-snapshot' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/core-health' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/shield-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/server-plan' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/control' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/b3' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/daily' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/events' "$ROOT_DIR/server/README.md" &&
   grep -q 'curl http://127.0.0.1:7777/insights' "$ROOT_DIR/server/README.md"; then
  ok "Seven Server exposes live state API endpoints"
else
  fail "Seven Server should expose state and profile API endpoints"
fi

atlas_json="$("$ROOT_DIR/bin/seven" atlas status --json)"
if grep -Eq '"schema"[[:space:]]*:[[:space:]]*"sevenos.profile-requirements.v1"' <<<"$atlas_json" &&
   grep -q 'scripts/packages-atlas.txt' "$ROOT_DIR/profiles/catalog.json" &&
   grep -q 'Atlas Explorer' "$ROOT_DIR/identity/profile-themes.json" &&
   grep -q 'seven atlas open' "$ROOT_DIR/scripts/surfaces.sh"; then
  ok "Atlas Explorer replaces Windows VM as a native seventh mini OS"
else
  fail "Atlas Explorer native seventh mini OS contract is incomplete"
fi

if "$ROOT_DIR/scripts/installer-stack.sh" doctor >/dev/null &&
   "$ROOT_DIR/seven-hub/gui-stack.sh" doctor >/dev/null &&
   grep -q 'com.usebottles.bottles' <<<"$("$ROOT_DIR/scripts/flatpak.sh" list)"; then
  ok "Installer, Tauri GUI and Flatpak foundations are coherent"
else
  fail "Installer, Tauri GUI or Flatpak foundation failed"
fi

if grep -q 'System Core' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -q 'Package Layer' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -q 'Service Layer' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -q 'UI Layer' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -q 'Security Layer' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -q 'Deployment Layer' "$ROOT_DIR/docs/ARCHITECTURE.md"; then
  ok "Product architecture layers are documented"
else
  fail "Product architecture layers are incomplete"
fi

if grep -q '"Control Center|control:center' "$ROOT_DIR/seven-hub/bin/seven-hub"; then
  ok "Seven Hub opens Control Center"
else
  fail "Seven Hub Control Center entry missing"
fi

if SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" hub plan | grep -q 'SevenOS Hub Product Plan' &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" hub status | grep -q 'SevenOS Hub Product Surface'; then
  ok "Seven Hub product plan is reachable from the main seven command"
else
  fail "Seven Hub product plan should be reachable from the main seven command"
fi

if SEVENOS_DRY_RUN=1 "$ROOT_DIR/seven-hub/bin/seven-hub" | grep -q 'seven-hub-native open' &&
   grep -q 'open_native_hub' "$ROOT_DIR/seven-hub/bin/seven-hub"; then
  ok "Seven Hub defaults to native Control Center before Rofi fallback"
else
  fail "Seven Hub should default to native Control Center before Rofi fallback"
fi

hub_profiles_preview="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/seven-hub/bin/seven-hub" Profiles 2>&1)"
if grep -q 'item_icon' "$ROOT_DIR/seven-hub/bin/seven-hub" &&
   grep -q 'display_label' "$ROOT_DIR/seven-hub/bin/seven-hub" &&
   grep -q 'display_row' "$ROOT_DIR/seven-hub/bin/seven-hub" &&
   grep -q 'clean_selection' "$ROOT_DIR/seven-hub/bin/seven-hub" &&
   grep -q '󰌢 Profile Forge' <<<"$hub_profiles_preview"; then
  ok "Seven Hub command palette is icon-first and information-rich"
else
  fail "Seven Hub command palette should be icon-first and information-rich"
fi

if grep -q '"Seven Files|files:open' "$ROOT_DIR/seven-hub/bin/seven-hub" &&
   grep -q 'Exec=seven-files' "$ROOT_DIR/seven-hub/seven-files.desktop" &&
   grep -q 'Exec=seven-wallpaper set %f' "$ROOT_DIR/seven-hub/seven-wallpaper.desktop"; then
  ok "Seven Files and wallpaper actions are exposed in desktop integration"
else
  fail "Seven Files or wallpaper desktop integration missing"
fi

for category in Dashboard Profiles Cyber Desktop "Atlas Explorer" "Server & Deploy" Ecosystem Installer Apps; do
  if grep -Fq "\"$category|category:$category" "$ROOT_DIR/seven-hub/bin/seven-hub"; then
    ok "Seven Hub category: $category"
  else
    fail "Seven Hub category missing: $category"
  fi
done

if command -v rofi >/dev/null 2>&1; then
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/apps.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/app-menu.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/hub.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/sevenos.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/quick-settings.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/power.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/prompt.rasi" -dump-theme >/dev/null
  ok "Rofi themes parse"
else
  warn "rofi not installed; theme parse skipped"
fi

SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-welcome" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-apps" open >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-overview" apps >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-quick-settings" >/dev/null
shell_preview_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-shell-preview")"
grep -q 'SevenOS Shell Preview' <<<"$shell_preview_output"
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-files" menu | grep -q 'rofi places menu'
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-notifications" menu >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-power" lock >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" summary >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" processes >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" maturity >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/stack.sh" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/stack.sh" roadmap >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/stack.sh" --json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/stack.sh" doctor >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/shell.sh" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/shell.sh" status --json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/shell.sh" plan >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/shell.sh" plan --json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/shell.sh" preview >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/shell.sh" doctor >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/experience.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/experience.sh" --json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/control-plane.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/control-plane.sh" --json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/control-plane.sh" apply --limit 2 >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" control apply --limit 2 >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/events.sh" list >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/events.sh" --json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/insights.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/insights.sh" --json >/dev/null
SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/phase-gate.sh" --json | python -c 'import json,sys; data=json.load(sys.stdin); raise SystemExit(0 if data.get("schema") == "sevenos.phase-gate.v1" and data.get("writer") == "seven-daemon" and data.get("gates") else 1)'
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/repair.sh" ux >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/design-check.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/post-install.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-lab --preset offline --dry-run >/dev/null
[[ "$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-action" app-command Copy)" == *"Active app > ctrl+c"* ]]
[[ "$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-action" app-command Copier)" == *"Active app > ctrl+c"* ]]
[[ "$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-action" app-command 'Full screen')" == *"Active app > F11"* ]]
[[ "$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-action" app-command 'Plein écran')" == *"Active app > F11"* ]]
[[ "$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-action" app-command 'Command palette')" == *"Active app > ctrl+shift+p"* ]]
ok "interactive UX commands support dry-run"

if SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" | grep -q '󰩂  Desktop Helpers    Super+H' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" | grep -q '󰒓  Open Seven Hub    Super+Shift+H' &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" | grep -q '󰩂  Aide du bureau    Super+H' &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" manual | grep -q 'seven language doctor' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" manual | grep -q 'seven language doctor' &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" manual | grep -q '## Documentation projet' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" manual | grep -q '## Project Documentation' &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" manual | grep -q 'docs/ARCHITECTURE.md' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" manual | grep -q 'docs/FUTURE_FEATURES.md' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" future | grep -q 'Future Features' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" docs-index | grep -q 'seven-help doc architecture' &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" docs-index | grep -q 'seven-help doc architecture' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" doc architecture | grep -q 'SevenOS Architecture' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" doc state | grep -q 'SevenOS State Contract' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" state | grep -q 'SevenOS State Contract' &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" doc installer | grep -q 'Source locale : `docs/INSTALLER.md`' &&
   grep -q 'SevenOS Future Features' "$ROOT_DIR/docs/FUTURE_FEATURES.md" &&
   grep -q '"id": "docs"' "$ROOT_DIR/bin/seven-help-native" &&
   grep -q 'seven-help docs-index' "$ROOT_DIR/bin/seven-help-native" &&
   SEVENOS_LANGUAGE=fr_FR.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" topics | grep -q 'language.*français/anglais' &&
   SEVENOS_LANGUAGE=en_US.UTF-8 SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-help" topics | grep -q 'language.*French/English' &&
   grep -q '󰋜  Home' "$ROOT_DIR/bin/seven-files" &&
   grep -q '󰀻  Open Apps    Super' "$ROOT_DIR/bin/seven-help" &&
   grep -q '󰀻  Ouvrir les apps    Super' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'Toggle Dock    Super+D' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'Terminal Classic' "$ROOT_DIR/bin/seven-help" &&
   grep -q 'Terminal Dark' "$ROOT_DIR/bin/seven-help"; then
  ok "Shell help and files surfaces use icon-first entries"
else
  fail "Shell help and files surfaces should be icon-first"
fi

finish_checks
