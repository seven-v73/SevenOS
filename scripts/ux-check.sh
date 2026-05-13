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
require_file "docs/UX_PRINCIPLES.md"
require_file "docs/VOCABULARY.md"
require_file "hyprland/rofi/power.rasi"
require_file "hyprland/mako/config"
require_file "hyprland/waybar/config.jsonc"

require_executable "bin/seven"
require_executable "bin/sevenpkg"
require_executable "seven-hub/bin/seven-hub"
require_executable "bin/seven-power"
require_executable "bin/seven-welcome"
require_executable "bin/seven-waybar-profile"
require_executable "bin/seven-waybar-security"

package_manifest_contains "mako" "scripts/packages-base.txt"
package_manifest_contains "libnotify" "scripts/packages-base.txt"
package_manifest_contains "swaylock" "scripts/packages-base.txt"
package_manifest_contains "swayidle" "scripts/packages-base.txt"
package_manifest_contains "hyprpaper" "scripts/packages-base.txt"
package_manifest_contains "ttf-jetbrains-mono-nerd" "scripts/packages-base.txt"

if jq -e '."custom/sevenos"."on-click" == "seven-hub Dashboard"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar SevenOS click opens dashboard"
else
  fail "Waybar SevenOS click does not open dashboard"
fi

if jq -e '."custom/sevenos"."on-click-right" == "seven-welcome"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar SevenOS right-click opens welcome"
else
  fail "Waybar SevenOS right-click does not open welcome"
fi

if jq -e '."custom/power"."on-click" == "seven-power"' "$ROOT_DIR/hyprland/waybar/config.jsonc" >/dev/null; then
  ok "Waybar power opens seven-power"
else
  fail "Waybar power action missing"
fi

if grep -q 'exec-once = mako' "$ROOT_DIR/hyprland/hyprland.conf"; then
  ok "Hyprland starts mako"
else
  fail "Hyprland does not start mako"
fi

if grep -q 'exec-once = swayidle' "$ROOT_DIR/hyprland/hyprland.conf"; then
  ok "Hyprland starts swayidle"
else
  fail "Hyprland does not start swayidle"
fi

for category in Dashboard Profiles Cyber Desktop "VM & Windows" Installer Apps; do
  if grep -q "\"$category|category:$category" "$ROOT_DIR/seven-hub/bin/seven-hub"; then
    ok "Seven Hub category: $category"
  else
    fail "Seven Hub category missing: $category"
  fi
done

if command -v rofi >/dev/null 2>&1; then
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/sevenos.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/power.rasi" -dump-theme >/dev/null
  ok "Rofi themes parse"
else
  warn "rofi not installed; theme parse skipped"
fi

SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-welcome" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-power" lock >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-lab --preset offline --dry-run >/dev/null
ok "interactive UX commands support dry-run"

if [[ "$failures" -gt 0 ]]; then
  log_error "UX checks failed: $failures"
  exit 1
fi

log_success "UX coherence checks passed."
