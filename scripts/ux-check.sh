#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

failures=0

ok() {
  printf '[OK] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
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

log_info "Running SevenOS UX coherence checks..."

require_file "docs/VISION.md"
require_file "docs/ARCHITECTURE.md"
require_file "docs/UX_PRINCIPLES.md"
require_file "docs/VOCABULARY.md"
require_file "docs/PHASE_GATE.md"
require_file "docs/ECOSYSTEM.md"
require_file "docs/PRODUCTIZATION.md"
require_file "docs/TEST_MACHINE.md"
require_file "docs/PRE_PUSH.md"
require_file "sevenos.dotinst"
require_file "installer/calamares/README.md"
require_file "installer/calamares/settings.conf"
require_file "installer/calamares/modules/sevenos.conf"
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
require_file "scripts/flatpak-apps.txt"
require_file "branding/shell/terminal-country.sh"
require_file "branding/motd"
require_file "branding/issue"
require_file "branding/sevenos-release"
require_file "archiso/profile/airootfs/etc/motd"
require_file "archiso/profile/airootfs/etc/issue"
require_file "archiso/profile/airootfs/etc/sevenos-release"
require_file "identity/countries/africa.tsv"
require_file "identity/STYLE.md"
require_file "identity/tokens.css"
require_file "identity/patterns/kente.svg"
require_file "identity/patterns/motif-concentric.svg"
require_file "identity/patterns/motif-diamond.svg"
require_file "identity/patterns/motif-grid.svg"
require_file "identity/patterns/motif-triangle.svg"
require_file "identity/patterns/motif-stripe.svg"
require_file "identity/patterns/motif-cross.svg"
require_file "hyprland/rofi/apps.rasi"
require_file "hyprland/rofi/quick-settings.rasi"
require_file "hyprland/rofi/power.rasi"
require_file "hyprland/mako/config"
require_file "hyprland/kitty/kitty.conf"
require_file "hyprland/conf/custom.conf"
require_file "hyprland/conf/keyboard.conf"
require_file "hyprland/conf/monitor.conf"
require_file "hyprland/waybar/config.jsonc"
require_file "hyprland/gtk-3.0/settings.ini"
require_file "hyprland/gtk-4.0/settings.ini"
require_file "hyprland/qt5ct/qt5ct.conf"
require_file "hyprland/qt6ct/qt6ct.conf"
require_file "seven-hub/seven-files.desktop"

require_executable "bin/seven"
require_executable "bin/sevenpkg"
require_executable "seven-hub/bin/seven-hub"
require_executable "seven-hub/bin/seven-control-center"
require_executable "bin/seven-country"
require_executable "bin/seven-apps"
require_executable "bin/seven-files"
require_executable "bin/seven-help"
require_executable "bin/seven-overview"
require_executable "bin/seven-quick-settings"
require_executable "bin/seven-session"
require_executable "bin/seven-wallpaper"
require_executable "bin/seven-power"
require_executable "bin/seven-welcome"
require_executable "bin/seven-hub-native"
require_executable "bin/seven-waybar-action"
require_executable "bin/seven-waybar-profile"
require_executable "bin/seven-waybar-security"
require_executable "scripts/phase-gate.sh"
require_executable "scripts/architecture.sh"
require_executable "scripts/state.sh"
require_executable "profiles/profile-manager.sh"
require_executable "scripts/installer-stack.sh"
require_executable "scripts/flatpak.sh"
require_executable "scripts/ecosystem.sh"
require_executable "scripts/manifest.sh"
require_executable "scripts/migrate.sh"
require_executable "seven-hub/gui-stack.sh"
require_executable "scripts/repair.sh"
require_executable "scripts/post-install.sh"
require_executable "scripts/design-check.sh"

package_manifest_contains "mako" "scripts/packages-base.txt"
package_manifest_contains "libnotify" "scripts/packages-base.txt"
package_manifest_contains "swaylock" "scripts/packages-base.txt"
package_manifest_contains "swayidle" "scripts/packages-base.txt"
package_manifest_contains "hyprpaper" "scripts/packages-base.txt"
package_manifest_contains "librsvg" "scripts/packages-base.txt"
package_manifest_contains "ttf-jetbrains-mono-nerd" "scripts/packages-base.txt"
package_manifest_contains "ttf-cormorant" "scripts/packages-base.txt"
package_manifest_contains "noto-fonts-emoji" "scripts/packages-base.txt"
package_manifest_contains "kitty" "scripts/packages-base.txt"
package_manifest_contains "nautilus" "scripts/packages-base.txt"
package_manifest_contains "gvfs" "scripts/packages-base.txt"
package_manifest_contains "gvfs-mtp" "scripts/packages-base.txt"
package_manifest_contains "gvfs-smb" "scripts/packages-base.txt"
package_manifest_contains "file-roller" "scripts/packages-base.txt"
package_manifest_contains "sushi" "scripts/packages-base.txt"
package_manifest_contains "xdg-user-dirs" "scripts/packages-base.txt"
package_manifest_contains "xdg-utils" "scripts/packages-base.txt"
package_manifest_contains "desktop-file-utils" "scripts/packages-base.txt"
package_manifest_contains "adw-gtk-theme" "scripts/packages-base.txt"
package_manifest_contains "qt5ct" "scripts/packages-base.txt"
package_manifest_contains "qt6ct" "scripts/packages-base.txt"
package_manifest_contains "kvantum" "scripts/packages-base.txt"
package_manifest_contains "flatpak" "scripts/packages-base.txt"
package_manifest_contains "btop" "scripts/packages-base.txt"
package_manifest_contains "pavucontrol" "scripts/packages-base.txt"
package_manifest_contains "network-manager-applet" "scripts/packages-base.txt"
package_manifest_contains "archinstall" "scripts/packages-installer.txt"
package_manifest_contains "rust" "scripts/packages-hub-gui.txt"
package_manifest_contains "nodejs" "scripts/packages-hub-gui.txt"
package_manifest_contains "npm" "scripts/packages-hub-gui.txt"
package_manifest_contains "webkit2gtk-4.1" "scripts/packages-hub-gui.txt"
package_manifest_contains "gtk4" "scripts/packages-hub-gui.txt"
package_manifest_contains "libadwaita" "scripts/packages-hub-gui.txt"
package_manifest_contains "python-gobject" "scripts/packages-hub-gui.txt"

if jq -e '."custom/sevenos"."on-click" == "seven hub"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar SevenOS click opens dashboard"
else
  fail "Waybar SevenOS click does not open dashboard"
fi

if jq -e '."custom/sevenos"."on-click-right" == "seven-welcome"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar SevenOS right-click opens welcome"
else
  fail "Waybar SevenOS right-click does not open welcome"
fi

if jq -e '."custom/apps".format == "Apps" and ."custom/apps"."on-click" == "seven-overview apps" and ."custom/apps"."on-click-right" == "seven-overview search"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar exposes visible Apps launcher"
else
  fail "Waybar visible Apps launcher missing"
fi

if grep -q '@theme "sevenos.rasi"' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'ebene: #09090d' "$ROOT_DIR/hyprland/rofi/sevenos.rasi" &&
   grep -q 'fullscreen: true' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'columns: 6' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   grep -q 'element-icon' "$ROOT_DIR/hyprland/rofi/apps.rasi" &&
   ! grep -RE '#[0-9a-fA-F]{8}\b' "$ROOT_DIR/hyprland/rofi" >/dev/null &&
   grep -q 'gtk-application-prefer-dark-theme=true' "$ROOT_DIR/hyprland/gtk-3.0/settings.ini" &&
   grep -q 'icon_theme=Papirus-Dark' "$ROOT_DIR/hyprland/qt6ct/qt6ct.conf"; then
  ok "App launcher and toolkit themes use dark SevenOS identity"
else
  fail "Theme coherence is incomplete across launcher and toolkits"
fi

if jq -e '."custom/files".format == "Files" and ."custom/files"."on-click" == "seven-files" and ."custom/files"."on-click-right" == "seven-files menu"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar exposes Seven Files"
else
  fail "Waybar Seven Files launcher missing"
fi

if jq -e '."custom/power"."on-click" == "seven-power"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar power opens seven-power"
else
  fail "Waybar power action missing"
fi

if jq -e '.network."on-click" == "seven-waybar-action network" and .pulseaudio."on-click" == "seven-waybar-action audio" and .battery."on-click" == "seven-waybar-action battery" and .clock."on-click" == "seven-waybar-action clock" and ."custom/security"."on-click" == "seven-waybar-action security" and ."custom/profile"."on-click" == "seven-waybar-action profile" and ."custom/quick"."on-click" == "seven-quick-settings"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar modules expose actionable controls"
else
  fail "Waybar still has decorative modules without actions"
fi

if SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven-waybar-profile" | grep -Eq 'Baobab|Forge|Shield|Studio|Windows|Horizon|Profiles|Profile' &&
   grep -q 'Native Profiles' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'Open Active Workspace' "$ROOT_DIR/bin/seven-waybar-action" &&
   grep -q 'seven profile activate forge' "$ROOT_DIR/bin/seven-waybar-action"; then
  ok "Waybar profile indicator uses live SevenOS profile state"
else
  fail "Waybar profile indicator should use live SevenOS profile state"
fi

if SEVENOS_DRY_RUN=1 "$ROOT_DIR/profiles/profile-manager.sh" activate forge | grep -q 'profile.json' &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile status --json | grep -q '"apps"' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/profiles/profile-manager.sh" open forge | grep -q 'seven-files open'; then
  ok "SevenOS profile activation creates live workspaces and app metadata"
else
  fail "SevenOS profile activation should create workspaces and app metadata"
fi

if grep -q 'exec-once = seven-session' "$ROOT_DIR/hyprland/hyprland.conf"; then
  ok "Hyprland starts SevenOS session"
else
  fail "Hyprland should start seven-session"
fi

if grep -q 'source = ~/.config/hypr/conf/monitor.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'source = ~/.config/hypr/conf/keyboard.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'source = ~/.config/hypr/conf/custom.conf' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'install_preserved_config_file' "$ROOT_DIR/scripts/apply-theme.sh"; then
  ok "Hyprland exposes protected user override files"
else
  fail "Hyprland protected override files are missing"
fi

if grep -q 'env = GTK_THEME,adw-gtk3-dark' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'env = QT_QPA_PLATFORMTHEME,qt6ct' "$ROOT_DIR/hyprland/hyprland.conf"; then
  ok "Hyprland exports GTK and Qt theme hints"
else
  fail "Hyprland missing GTK/Qt theme environment"
fi

if grep -q 'bind = $mod, SPACE, exec, seven hub' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bind = $mod, A, exec, $launcher' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bind = $mod, TAB, exec, $overview' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bind = $mod, N, exec, $quicksettings' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bind = $mod, E, exec, seven-files' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bind = $mod CTRL, E, exec, seven-files profile' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'seven-overview apps' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'bind = $mod, slash, exec, seven-help' "$ROOT_DIR/hyprland/hyprland.conf"; then
  ok "Hyprland exposes discoverable Hub, Apps and Help shortcuts"
else
  fail "Hyprland discoverable desktop shortcuts missing"
fi

overview_search_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-overview" search)"
quick_settings_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-quick-settings")"
apps_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-apps" open)"
if grep -q 'rounding = 16' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'animation = specialWorkspace' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'workspace = special:seven' "$ROOT_DIR/hyprland/hyprland.conf" &&
   grep -q 'windowrule = match:title ^(Open File)' "$ROOT_DIR/hyprland/hyprland.conf" &&
   [[ "$overview_search_output" == *"rofi"* ]] &&
   [[ "$apps_output" == *"seven-apps catalog"* ]] &&
   [[ "$quick_settings_output" == *"Control Center"* ]]; then
  ok "SevenOS Shell exposes GNOME-like overview, quick settings and polished window rules"
else
  fail "SevenOS Shell GNOME-like interface layer is incomplete"
fi

if grep -q 'start_once mako' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'start_once waybar' "$ROOT_DIR/bin/seven-session" &&
   grep -q 'seven-wallpaper' "$ROOT_DIR/bin/seven-session"; then
  ok "SevenOS session supervises desktop components"
else
  fail "seven-session should supervise desktop components"
fi

if grep -Eq '^[[:space:]]*pseudotile[[:space:]]*=|togglesplit' "$ROOT_DIR/hyprland/hyprland.conf"; then
  fail "Hyprland config contains options removed in Hyprland 0.55"
else
  ok "Hyprland config avoids removed 0.55 options"
fi

if grep -q 'wallpaper-sevenos-royal-kente.png' "$ROOT_DIR/hyprland/hyprpaper.conf"; then
  ok "Hyprpaper uses SevenOS wallpaper target"
else
  fail "Hyprpaper should use the SevenOS wallpaper target"
fi

if grep -q 'background_opacity 0.88' "$ROOT_DIR/hyprland/kitty/kitty.conf" &&
   grep -q 'active_tab_background #c8a96e' "$ROOT_DIR/hyprland/kitty/kitty.conf" &&
   grep -q 'cursor #c8a96e' "$ROOT_DIR/hyprland/kitty/kitty.conf" &&
   grep -q 'symbol_map U+1F1E6-U+1F1FF Noto Color Emoji' "$ROOT_DIR/hyprland/kitty/kitty.conf"; then
  ok "Kitty uses SevenOS Design System v1 palette"
else
  fail "Kitty palette is not aligned with SevenOS identity"
fi

if grep -q -- '--gold: #c8a96e' "$ROOT_DIR/identity/tokens.css" &&
   grep -q -- '--font-display' "$ROOT_DIR/identity/tokens.css" &&
   ! grep -R "box-shadow" "$ROOT_DIR/hyprland/waybar/style.css" "$ROOT_DIR/seven-hub/gui/src/styles.css" >/dev/null &&
   ! grep -E '#[0-9a-fA-F]{8}\b' "$ROOT_DIR/hyprland/waybar/style.css" >/dev/null; then
  ok "Design tokens and no-shadow UI rule are enforced"
else
  fail "Design tokens or no-shadow UI rule failed"
fi

if "$ROOT_DIR/bin/seven-country" plain | grep -q 'Capital:'; then
  ok "Terminal country signal works"
else
  fail "Terminal country signal failed"
fi

if "$ROOT_DIR/bin/seven-apps" doctor | grep -q 'desktop applications indexed'; then
  ok "SevenOS Apps indexes installed desktop applications"
else
  fail "SevenOS Apps should index installed desktop applications"
fi

if "$ROOT_DIR/seven-hub/bin/seven-hub" doctor >/dev/null; then
  ok "Seven Hub doctor works"
else
  fail "Seven Hub doctor failed"
fi

if "$ROOT_DIR/seven-hub/bin/seven-control-center" status >/dev/null; then
  ok "Seven Control Center status works"
else
  fail "Seven Control Center status failed"
fi

if grep -q 'get_hub_snapshot' "$ROOT_DIR/seven-hub/gui/src-tauri/src/main.rs" &&
   grep -q 'seven profile status --json' "$ROOT_DIR/seven-hub/gui/src-tauri/src/main.rs" &&
   grep -q '"identifier": "os.seven.seven-hub"' "$ROOT_DIR/seven-hub/gui/src-tauri/tauri.conf.json" &&
   grep -q '"active": false' "$ROOT_DIR/seven-hub/gui/src-tauri/tauri.conf.json" &&
   grep -q 'data-panel="dashboard"' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'confirm-layer' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'nav-label' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'data-section="profiles"' "$ROOT_DIR/seven-hub/gui/src/index.html" &&
   grep -q 'run_seven_command' "$ROOT_DIR/seven-hub/gui/src/main.js" &&
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

if grep -Fq 'GTK4 + libadwaita' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -Fq 'Tauri is useful for fast iteration' "$ROOT_DIR/docs/ARCHITECTURE.md" &&
   grep -Fq 'Seven Hub Native' "$ROOT_DIR/seven-hub/native/README.md" &&
   grep -Fq 'seven profile status --json' "$ROOT_DIR/seven-hub/native/README.md" &&
   "$ROOT_DIR/bin/seven-hub-native" status | grep -q 'Seven Hub Native' &&
   SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" hub-native --dry-run | grep -q 'seven-hub-native open' &&
   grep -q 'Exec=seven-hub-native' "$ROOT_DIR/seven-hub/seven-hub-native.desktop"; then
  ok "Seven Hub native UI strategy is documented"
else
  fail "Seven Hub native UI strategy is missing or unclear"
fi

if SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" status --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" state --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile status --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/sevenpkg" status --json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/scripts/manifest.sh" summary-json | python -m json.tool >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" state --json | python -c 'import json,sys; raise SystemExit(0 if "manifest" in json.load(sys.stdin) else 1)'; then
  ok "SevenOS core commands expose stable JSON for the Hub"
else
  fail "SevenOS core commands must expose JSON for GUI integration"
fi

profile_show_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile show forge)"
profile_activate_output="$(SEVENOS_DRY_RUN=1 "$ROOT_DIR/profiles/profile-manager.sh" activate studio)"
profile_json_output="$(SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" profile status --json)"
if grep -q 'Workspace:' <<<"$profile_show_output" &&
   grep -q 'profile.env' <<<"$profile_activate_output" &&
   grep -q '"active"' <<<"$profile_json_output"; then
  ok "SevenOS profiles expose concrete state, activation and workspaces"
else
  fail "SevenOS profiles should expose state, activation and workspaces"
fi

if SEVENOS_DRY_RUN=1 "$ROOT_DIR/seven-hub/bin/seven-control-center" open | grep -q 'xdg-open http://127.0.0.1:7787'; then
  ok "Seven Control Center open dry-run works"
else
  fail "Seven Control Center open dry-run failed"
fi

if grep -q 'seven ecosystem' "$ROOT_DIR/branding/motd" &&
   grep -q 'African first intelligent Linux ecosystem' "$ROOT_DIR/branding/issue" &&
   grep -q 'seven ecosystem' "$ROOT_DIR/archiso/profile/airootfs/etc/motd"; then
  ok "Branding exposes SevenOS ecosystem identity"
else
  fail "Branding is not aligned with ecosystem identity"
fi

if "$ROOT_DIR/scripts/architecture.sh" doctor >/dev/null; then
  ok "SevenOS architecture doctor works"
else
  fail "SevenOS architecture doctor failed"
fi

if "$ROOT_DIR/scripts/manifest.sh" doctor >/dev/null &&
   SEVENOS_DRY_RUN=0 "$ROOT_DIR/bin/seven" manifest restore-plan | grep -q 'Hyprland user override' &&
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

if grep -q 'self.path == "/state"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'self.path == "/profiles"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'self.path == "/manifest"' "$ROOT_DIR/server/seven-server.sh" &&
   grep -q 'curl http://127.0.0.1:7777/state' "$ROOT_DIR/server/README.md"; then
  ok "Seven Server exposes live state API endpoints"
else
  fail "Seven Server should expose state and profile API endpoints"
fi

if "$ROOT_DIR/scripts/installer-stack.sh" doctor >/dev/null &&
   "$ROOT_DIR/seven-hub/gui-stack.sh" doctor >/dev/null &&
   "$ROOT_DIR/scripts/flatpak.sh" list | grep -q 'com.usebottles.bottles'; then
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

if grep -q '"Seven Files|files:open' "$ROOT_DIR/seven-hub/bin/seven-hub" &&
   grep -q 'Exec=seven-files' "$ROOT_DIR/seven-hub/seven-files.desktop"; then
  ok "Seven Files is exposed in Hub and app launcher"
else
  fail "Seven Files desktop integration missing"
fi

for category in Dashboard Profiles Cyber Desktop "VM & Windows" "Server & Deploy" Ecosystem Installer Apps; do
  if grep -q "\"$category|category:$category" "$ROOT_DIR/seven-hub/bin/seven-hub"; then
    ok "Seven Hub category: $category"
  else
    fail "Seven Hub category missing: $category"
  fi
done

if command -v rofi >/dev/null 2>&1; then
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/apps.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/sevenos.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/quick-settings.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/power.rasi" -dump-theme >/dev/null
  ok "Rofi themes parse"
else
  warn "rofi not installed; theme parse skipped"
fi

SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-welcome" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-apps" open >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-overview" apps >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-quick-settings" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-files" menu >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-power" lock >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/repair.sh" ux >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/design-check.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/post-install.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-lab --preset offline --dry-run >/dev/null
ok "interactive UX commands support dry-run"

if [[ "$failures" -gt 0 ]]; then
  log_error "UX checks failed: $failures"
  exit 1
fi

log_success "UX coherence checks passed."
