#!/usr/bin/env bash
# ==============================================================================
# SevenOS — Theme Generator v2.0
# Propagates core/design/palette.sh across Hyprland, Waybar, Rofi, tokens and
# native GTK runtime surfaces.
# ==============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PALETTE_FILE="$ROOT_DIR/core/design/palette.sh"

if [[ ! -f "$PALETTE_FILE" ]]; then
  echo "Erreur: palette canonique introuvable: $PALETTE_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$PALETTE_FILE"

strip_hash() {
  printf '%s' "${1#\#}"
}

hex_rgb() {
  printf 'rgb(%s)' "$(strip_hash "$1")"
}

hex_rgba() {
  local hex value
  hex="$(strip_hash "$1")"
  value="$2"
  printf 'rgba(%s,%s,%s,%s)' "$((0x${hex:0:2}))" "$((0x${hex:2:2}))" "$((0x${hex:4:2}))" "$value"
}

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

REPO_HYPR_DIR="$ROOT_DIR/hyprland/conf"
REPO_WAYBAR_DIR="$ROOT_DIR/hyprland/waybar"
REPO_ROFI_DIR="$ROOT_DIR/hyprland/rofi"
REPO_IDENTITY_GEN="$ROOT_DIR/identity/generated"

USER_HYPR_DIR="$CONFIG_HOME/hypr/conf"
USER_WAYBAR_DIR="$CONFIG_HOME/waybar"
USER_ROFI_DIR="$CONFIG_HOME/rofi"
USER_TOKENS_DIR="$DATA_HOME/sevenos/identity"

mkdir -p \
  "$REPO_HYPR_DIR" "$REPO_WAYBAR_DIR" "$REPO_ROFI_DIR" "$REPO_IDENTITY_GEN" \
  "$USER_HYPR_DIR" "$USER_WAYBAR_DIR" "$USER_ROFI_DIR" "$USER_TOKENS_DIR"

echo "SevenOS — generation du theme unifie"
echo "  Palette: $PALETTE_FILE"

write_hypr_colors() {
  local target="$1"
  cat > "$target" <<HYPR
# ==============================================================================
# SevenOS — Hyprland Colors
# Generated from core/design/palette.sh — do not edit manually
# ==============================================================================

\$seven_primary = $(hex_rgb "$SEVENOS_COLOR_PRIMARY")
\$seven_secondary = $(hex_rgb "$SEVENOS_COLOR_SECONDARY")
\$seven_accent = $(hex_rgb "$SEVENOS_COLOR_ACCENT")
\$seven_success = $(hex_rgb "$SEVENOS_COLOR_SUCCESS")
\$seven_warning = $(hex_rgb "$SEVENOS_COLOR_WARNING")
\$seven_error = $(hex_rgb "$SEVENOS_COLOR_ERROR")

\$seven_bg = $(hex_rgb "$SEVENOS_SURFACE_0")
\$seven_surface = $(hex_rgb "$SEVENOS_SURFACE_1")
\$seven_panel = $(hex_rgb "$SEVENOS_SURFACE_2")
\$seven_elevated = $(hex_rgb "$SEVENOS_SURFACE_3")

\$seven_text = $(hex_rgb "$SEVENOS_TEXT_PRIMARY")
\$seven_text_secondary = $(hex_rgb "$SEVENOS_TEXT_SECONDARY")
\$seven_text_muted = $(hex_rgb "$SEVENOS_TEXT_MUTED")
\$seven_text_disabled = $(hex_rgb "$SEVENOS_TEXT_DISABLED")

\$seven_blue = \$seven_primary
\$seven_violet = \$seven_secondary
\$seven_cyan = \$seven_accent
\$seven_green = \$seven_success

general {
    col.active_border = \$seven_primary \$seven_secondary \$seven_accent 45deg
    col.inactive_border = $(hex_rgba "$SEVENOS_TEXT_MUTED" 0.22)
}
HYPR
}

write_waybar_colors() {
  local target="$1"
  local mode="${2:-dark}"
  if [[ "$mode" == "light" ]]; then
    cat > "$target" <<WAYBAR
/* Generated from core/design/palette.sh — light */
@define-color seven_primary #$(strip_hash "$SEVENOS_LIGHT_COLOR_PRIMARY");
@define-color seven_secondary #$(strip_hash "$SEVENOS_LIGHT_COLOR_SECONDARY");
@define-color seven_accent #$(strip_hash "$SEVENOS_LIGHT_COLOR_ACCENT");
@define-color seven_success #$(strip_hash "$SEVENOS_LIGHT_COLOR_SUCCESS");
@define-color seven_warning #$(strip_hash "$SEVENOS_LIGHT_COLOR_WARNING");
@define-color seven_error #$(strip_hash "$SEVENOS_LIGHT_COLOR_ERROR");
@define-color seven_bg #$(strip_hash "$SEVENOS_LIGHT_SURFACE_0");
@define-color seven_surface #$(strip_hash "$SEVENOS_LIGHT_SURFACE_1");
@define-color seven_panel #$(strip_hash "$SEVENOS_LIGHT_SURFACE_2");
@define-color seven_elevated #$(strip_hash "$SEVENOS_LIGHT_SURFACE_3");
@define-color seven_text #$(strip_hash "$SEVENOS_LIGHT_TEXT_PRIMARY");
@define-color seven_text_secondary #$(strip_hash "$SEVENOS_LIGHT_TEXT_SECONDARY");
@define-color seven_text_muted #$(strip_hash "$SEVENOS_LIGHT_TEXT_MUTED");
@define-color seven_border ${SEVENOS_LIGHT_BORDER};
@define-color seven_hover ${SEVENOS_COMFORT_LIGHT_HOVER};
@define-color seven_selected ${SEVENOS_COMFORT_LIGHT_SELECTED};
@define-color bg_bar rgba(246, 249, 253, 0.92);
@define-color bg_glass ${SEVENOS_LIGHT_GLASS_1};
@define-color bg_hover ${SEVENOS_COMFORT_LIGHT_HOVER};
@define-color bg_active ${SEVENOS_COMFORT_LIGHT_SELECTED};
@define-color border_soft ${SEVENOS_LIGHT_BORDER};
@define-color border_focus ${SEVENOS_LIGHT_BORDER_STRONG};
@define-color text_primary #$(strip_hash "$SEVENOS_LIGHT_TEXT_PRIMARY");
@define-color text_secondary rgba(28, 31, 38, 0.72);
@define-color text_tertiary rgba(28, 31, 38, 0.48);
@define-color text_muted rgba(28, 31, 38, 0.32);
@define-color accent_blue #$(strip_hash "$SEVENOS_LIGHT_COLOR_PRIMARY");
@define-color accent_cyan #$(strip_hash "$SEVENOS_LIGHT_COLOR_ACCENT");
@define-color accent_violet #$(strip_hash "$SEVENOS_LIGHT_COLOR_SECONDARY");
@define-color accent_green #$(strip_hash "$SEVENOS_LIGHT_COLOR_SUCCESS");
@define-color accent_warm #$(strip_hash "$SEVENOS_LIGHT_COLOR_WARNING");
@define-color accent_rose #$(strip_hash "$SEVENOS_LIGHT_COLOR_ERROR");
@define-color accent_gold #$(strip_hash "$SEVENOS_LIGHT_COLOR_SECONDARY");
@define-color shadow_system rgba(28, 31, 38, 0.12);
@define-color glow_blue rgba(47, 123, 255, 0.10);
@define-color glow_cyan rgba(0, 184, 217, 0.08);
WAYBAR
  else
    cat > "$target" <<WAYBAR
/* Generated from core/design/palette.sh — dark */
@define-color seven_primary #$(strip_hash "$SEVENOS_COLOR_PRIMARY");
@define-color seven_secondary #$(strip_hash "$SEVENOS_COLOR_SECONDARY");
@define-color seven_accent #$(strip_hash "$SEVENOS_COLOR_ACCENT");
@define-color seven_success #$(strip_hash "$SEVENOS_COLOR_SUCCESS");
@define-color seven_warning #$(strip_hash "$SEVENOS_COLOR_WARNING");
@define-color seven_error #$(strip_hash "$SEVENOS_COLOR_ERROR");
@define-color seven_bg #$(strip_hash "$SEVENOS_SURFACE_0");
@define-color seven_surface #$(strip_hash "$SEVENOS_SURFACE_1");
@define-color seven_panel #$(strip_hash "$SEVENOS_SURFACE_2");
@define-color seven_elevated #$(strip_hash "$SEVENOS_SURFACE_3");
@define-color seven_text #$(strip_hash "$SEVENOS_TEXT_PRIMARY");
@define-color seven_text_secondary #$(strip_hash "$SEVENOS_TEXT_SECONDARY");
@define-color seven_text_muted #$(strip_hash "$SEVENOS_TEXT_MUTED");
@define-color seven_border ${SEVENOS_BORDER};
@define-color seven_hover ${SEVENOS_COMFORT_DARK_HOVER};
@define-color seven_selected ${SEVENOS_COMFORT_DARK_SELECTED};
@define-color bg_bar rgba(9, 9, 11, 0.92);
@define-color bg_glass ${SEVENOS_GLASS_1};
@define-color bg_hover ${SEVENOS_GLASS_2};
@define-color bg_active ${SEVENOS_GLASS_3};
@define-color border_soft ${SEVENOS_BORDER};
@define-color border_focus ${SEVENOS_BORDER_PRIMARY};
@define-color text_primary #$(strip_hash "$SEVENOS_TEXT_PRIMARY");
@define-color text_secondary rgba(237, 237, 237, 0.72);
@define-color text_tertiary rgba(237, 237, 237, 0.48);
@define-color text_muted rgba(237, 237, 237, 0.28);
@define-color accent_blue #$(strip_hash "$SEVENOS_COLOR_PRIMARY");
@define-color accent_cyan #$(strip_hash "$SEVENOS_COLOR_ACCENT");
@define-color accent_violet #$(strip_hash "$SEVENOS_COLOR_SECONDARY");
@define-color accent_green #$(strip_hash "$SEVENOS_COLOR_SUCCESS");
@define-color accent_warm #$(strip_hash "$SEVENOS_COLOR_WARNING");
@define-color accent_rose #$(strip_hash "$SEVENOS_COLOR_ERROR");
@define-color accent_gold #$(strip_hash "$SEVENOS_COLOR_SECONDARY");
@define-color shadow_system rgba(0, 0, 0, 0.30);
@define-color glow_blue rgba(77, 163, 255, 0.10);
@define-color glow_cyan rgba(0, 212, 255, 0.08);
WAYBAR
  fi
}

write_rofi_theme() {
  local target="$1"
  cat > "$target" <<ROFI
* {
  seven-blue: #$(strip_hash "$SEVENOS_COLOR_PRIMARY");
  seven-violet: #$(strip_hash "$SEVENOS_COLOR_SECONDARY");
  seven-cyan: #$(strip_hash "$SEVENOS_COLOR_ACCENT");
  seven-green: #$(strip_hash "$SEVENOS_COLOR_SUCCESS");
  deep-void: #$(strip_hash "$SEVENOS_SURFACE_0");
  surface-dark: #$(strip_hash "$SEVENOS_SURFACE_1");
  surface-0: #$(strip_hash "$SEVENOS_SURFACE_0");
  surface-1: rgba(18, 19, 26, 0.86);
  surface-2: rgba(28, 31, 44, 0.76);
  surface-3: rgba(39, 43, 61, 0.82);
  glass: ${SEVENOS_GLASS_1};
  glass-2: ${SEVENOS_GLASS_2};
  glass-3: ${SEVENOS_GLASS_3};
  glass-border: ${SEVENOS_BORDER};
  glass-border-2: ${SEVENOS_BORDER_PRIMARY};
  text-1: #$(strip_hash "$SEVENOS_TEXT_PRIMARY");
  text-2: #$(strip_hash "$SEVENOS_TEXT_SECONDARY");
  text-3: #$(strip_hash "$SEVENOS_TEXT_MUTED");
  indigo: #$(strip_hash "$SEVENOS_COLOR_PRIMARY");
  indigo-bright: #$(strip_hash "$SEVENOS_COLOR_ACCENT");
  gold: #$(strip_hash "$SEVENOS_COLOR_SECONDARY");
  gold-bright: #$(strip_hash "$SEVENOS_COLOR_ACCENT");
  gold-dim: rgba(122, 92, 255, 0.72);
  clay: #$(strip_hash "$SEVENOS_COLOR_ERROR");
  clay-dim: #C94563;
  baobab: #$(strip_hash "$SEVENOS_COLOR_SUCCESS");
  baobab-bright: #00E676;

  background-color: transparent;
  text-color: @text-1;
  font: "SF Pro Text 13";
  margin: 0;
  padding: 0;
}
ROFI
}

write_palette_core_css() {
  local target="$1"
  cat > "$target" <<CSS
/* Generated from core/design/palette.sh — do not edit manually */

:root {
  --palette-primary: #$(strip_hash "$SEVENOS_COLOR_PRIMARY");
  --palette-secondary: #$(strip_hash "$SEVENOS_COLOR_SECONDARY");
  --palette-accent: #$(strip_hash "$SEVENOS_COLOR_ACCENT");
  --palette-success: #$(strip_hash "$SEVENOS_COLOR_SUCCESS");
  --palette-warning: #$(strip_hash "$SEVENOS_COLOR_WARNING");
  --palette-error: #$(strip_hash "$SEVENOS_COLOR_ERROR");
  --palette-surface-0: #$(strip_hash "$SEVENOS_SURFACE_0");
  --palette-surface-1: #$(strip_hash "$SEVENOS_SURFACE_1");
  --palette-surface-2: #$(strip_hash "$SEVENOS_SURFACE_2");
  --palette-surface-3: #$(strip_hash "$SEVENOS_SURFACE_3");
  --palette-text-primary: #$(strip_hash "$SEVENOS_TEXT_PRIMARY");
  --palette-text-muted: #$(strip_hash "$SEVENOS_TEXT_MUTED");
  --comfort-dark-bg: #$(strip_hash "$SEVENOS_COMFORT_DARK_BG");
  --comfort-dark-panel: ${SEVENOS_COMFORT_DARK_PANEL};
  --comfort-dark-panel-2: ${SEVENOS_COMFORT_DARK_PANEL_2};
  --comfort-dark-sidebar: ${SEVENOS_COMFORT_DARK_SIDEBAR};
  --comfort-dark-text: #$(strip_hash "$SEVENOS_COMFORT_DARK_TEXT");
  --comfort-dark-muted: #$(strip_hash "$SEVENOS_COMFORT_DARK_MUTED");
  --comfort-dark-border: ${SEVENOS_COMFORT_DARK_BORDER};
  --comfort-light-bg: #$(strip_hash "$SEVENOS_COMFORT_LIGHT_BG");
  --comfort-light-panel: #$(strip_hash "$SEVENOS_COMFORT_LIGHT_PANEL");
  --comfort-light-panel-2: #$(strip_hash "$SEVENOS_COMFORT_LIGHT_PANEL_2");
  --comfort-light-panel-3: #$(strip_hash "$SEVENOS_COMFORT_LIGHT_PANEL_3");
  --comfort-light-sidebar: #$(strip_hash "$SEVENOS_COMFORT_LIGHT_SIDEBAR");
  --comfort-light-text: #$(strip_hash "$SEVENOS_COMFORT_LIGHT_TEXT");
  --comfort-light-muted: #$(strip_hash "$SEVENOS_COMFORT_LIGHT_MUTED");
}
CSS
}

write_palette_runtime_json() {
  local target="$1"
  cat > "$target" <<JSON
{
  "schema": "sevenos.palette-runtime.v1",
  "version": "${SEVENOS_DESIGN_SYSTEM_VERSION}",
  "source": "core/design/palette.sh",
  "dark": {
    "bg": "#$(strip_hash "$SEVENOS_COMFORT_DARK_BG")",
    "panel": "${SEVENOS_COMFORT_DARK_PANEL}",
    "panel_2": "${SEVENOS_COMFORT_DARK_PANEL_2}",
    "sidebar": "${SEVENOS_COMFORT_DARK_SIDEBAR}",
    "text": "#$(strip_hash "$SEVENOS_COMFORT_DARK_TEXT")",
    "muted": "#$(strip_hash "$SEVENOS_COMFORT_DARK_MUTED")",
    "border": "${SEVENOS_COMFORT_DARK_BORDER}",
    "hover": "${SEVENOS_COMFORT_DARK_HOVER}",
    "selected": "${SEVENOS_COMFORT_DARK_SELECTED}",
    "accent": "#$(strip_hash "$SEVENOS_COLOR_PRIMARY")",
    "secondary": "#$(strip_hash "$SEVENOS_COLOR_SECONDARY")",
    "success": "#$(strip_hash "$SEVENOS_COLOR_SUCCESS")",
    "danger": "#$(strip_hash "$SEVENOS_COLOR_ERROR")",
    "warning": "#$(strip_hash "$SEVENOS_COLOR_WARNING")",
    "paper": "#F4E8D1",
    "paper_text": "#1C1F26",
    "paper_shadow": "rgba(0, 0, 0, 0.42)",
    "paper_edge": "rgba(90, 70, 42, 0.18)",
    "traffic_close": "#FF5F57",
    "traffic_minimize": "#FEBC2E",
    "traffic_maximize": "#28C840"
  },
  "light": {
    "bg": "#$(strip_hash "$SEVENOS_COMFORT_LIGHT_BG")",
    "panel": "#$(strip_hash "$SEVENOS_COMFORT_LIGHT_PANEL")",
    "panel_2": "#$(strip_hash "$SEVENOS_COMFORT_LIGHT_PANEL_2")",
    "sidebar": "#$(strip_hash "$SEVENOS_COMFORT_LIGHT_SIDEBAR")",
    "text": "#$(strip_hash "$SEVENOS_COMFORT_LIGHT_TEXT")",
    "muted": "#$(strip_hash "$SEVENOS_COMFORT_LIGHT_MUTED")",
    "border": "${SEVENOS_COMFORT_LIGHT_BORDER}",
    "hover": "${SEVENOS_COMFORT_LIGHT_HOVER}",
    "selected": "${SEVENOS_COMFORT_LIGHT_SELECTED}",
    "accent": "#$(strip_hash "$SEVENOS_LIGHT_COLOR_PRIMARY")",
    "secondary": "#$(strip_hash "$SEVENOS_LIGHT_COLOR_SECONDARY")",
    "success": "#$(strip_hash "$SEVENOS_LIGHT_COLOR_SUCCESS")",
    "danger": "#$(strip_hash "$SEVENOS_LIGHT_COLOR_ERROR")",
    "warning": "#$(strip_hash "$SEVENOS_LIGHT_COLOR_WARNING")",
    "paper": "#F4E8D1",
    "paper_text": "#202634",
    "paper_shadow": "rgba(32, 38, 52, 0.22)",
    "paper_edge": "rgba(90, 70, 42, 0.18)",
    "traffic_close": "#FF5F57",
    "traffic_minimize": "#FEBC2E",
    "traffic_maximize": "#28C840"
  }
}
JSON
}

write_hypr_colors "$REPO_HYPR_DIR/sevenos-colors.conf"
write_hypr_colors "$USER_HYPR_DIR/sevenos-colors.conf"

write_waybar_colors "$REPO_WAYBAR_DIR/sevenos-colors.css" dark
write_waybar_colors "$USER_WAYBAR_DIR/sevenos-colors.css" dark
write_waybar_colors "$ROOT_DIR/hyprland-light/waybar/sevenos-colors.css" light

write_rofi_theme "$REPO_ROFI_DIR/sevenos-palette.rasi"
write_rofi_theme "$ROOT_DIR/hyprland-light/rofi/sevenos-palette.rasi"
write_rofi_theme "$USER_ROFI_DIR/sevenos-palette.rasi"

write_palette_core_css "$REPO_IDENTITY_GEN/palette-core.css"
write_palette_core_css "$USER_TOKENS_DIR/palette-core.css"

write_palette_runtime_json "$REPO_IDENTITY_GEN/palette-runtime.json"
write_palette_runtime_json "$USER_TOKENS_DIR/palette-runtime.json"

echo "  Hyprland: $REPO_HYPR_DIR/sevenos-colors.conf"
echo "  Waybar:   $REPO_WAYBAR_DIR/sevenos-colors.css"
echo "  Rofi:     $REPO_ROFI_DIR/sevenos-palette.rasi"
echo "  Tokens:   $REPO_IDENTITY_GEN/palette-core.css"
echo "  Runtime:  $REPO_IDENTITY_GEN/palette-runtime.json"
echo ""
echo "Theme SevenOS genere. Appliquer avec: ./scripts/apply-theme.sh current"
