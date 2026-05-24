#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_DIR="$CONFIG_HOME/sevenos"
THEME_CONF="$STATE_DIR/theme.conf"
RUNTIME_ENV="$STATE_DIR/theme-runtime.env"
RUNTIME_JSON="$STATE_DIR/theme-runtime.json"
RUNTIME_CSS="$DATA_HOME/sevenos/identity/runtime-theme.css"

theme_mode() {
  if [[ "${SEVENOS_THEME_MODE:-}" == "dark" || "${SEVENOS_THEME_MODE:-}" == "light" ]]; then
    printf '%s' "$SEVENOS_THEME_MODE"
    return 0
  fi
  if [[ -r "$THEME_CONF" ]]; then
    # shellcheck disable=SC1090
    source "$THEME_CONF" || true
  fi
  printf '%s' "${SEVENOS_THEME_MODE:-dark}"
}

toolkit_value() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 0
  sed -n "s/^${key}=//p" "$file" | tail -n 1
}

gsettings_value() {
  local schema="$1" key="$2"
  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings get "$schema" "$key" 2>/dev/null | sed "s/^'//;s/'$//" || true
}

write_runtime() {
  local mode gtk_theme icon_theme cursor_theme qt5_icon qt6_icon kvantum_theme color_scheme
  mode="$(theme_mode)"
  gtk_theme="$(toolkit_value "$CONFIG_HOME/gtk-3.0/settings.ini" gtk-theme-name)"
  icon_theme="$(toolkit_value "$CONFIG_HOME/gtk-3.0/settings.ini" gtk-icon-theme-name)"
  cursor_theme="$(toolkit_value "$CONFIG_HOME/gtk-3.0/settings.ini" gtk-cursor-theme-name)"
  qt5_icon="$(toolkit_value "$CONFIG_HOME/qt5ct/qt5ct.conf" icon_theme)"
  qt6_icon="$(toolkit_value "$CONFIG_HOME/qt6ct/qt6ct.conf" icon_theme)"
  kvantum_theme="$(toolkit_value "$CONFIG_HOME/Kvantum/kvantum.kvconfig" theme)"
  color_scheme="$(gsettings_value org.gnome.desktop.interface color-scheme)"

  mkdir -p "$STATE_DIR" "$(dirname -- "$RUNTIME_CSS")"
  cat > "$RUNTIME_ENV" <<EOF
SEVENOS_THEME_MODE="$mode"
SEVENOS_GTK_THEME="$gtk_theme"
SEVENOS_ICON_THEME="$icon_theme"
SEVENOS_CURSOR_THEME="$cursor_theme"
SEVENOS_QT5_ICON_THEME="$qt5_icon"
SEVENOS_QT6_ICON_THEME="$qt6_icon"
SEVENOS_KVANTUM_THEME="$kvantum_theme"
SEVENOS_COLOR_SCHEME="$color_scheme"
EOF

  MODE="$mode" GTK_THEME="$gtk_theme" ICON_THEME="$icon_theme" CURSOR_THEME="$cursor_theme" \
  QT5_ICON="$qt5_icon" QT6_ICON="$qt6_icon" KVANTUM_THEME="$kvantum_theme" COLOR_SCHEME="$color_scheme" \
  python - "$RUNTIME_JSON" "$RUNTIME_CSS" <<'PY'
import json
import os
import sys
from pathlib import Path

payload = {
    "schema": "sevenos.theme-runtime.v1",
    "mode": os.environ.get("MODE", "dark"),
    "toolkits": {
        "gtk_theme": os.environ.get("GTK_THEME", ""),
        "icon_theme": os.environ.get("ICON_THEME", ""),
        "cursor_theme": os.environ.get("CURSOR_THEME", ""),
        "qt5_icon_theme": os.environ.get("QT5_ICON", ""),
        "qt6_icon_theme": os.environ.get("QT6_ICON", ""),
        "kvantum_theme": os.environ.get("KVANTUM_THEME", ""),
        "color_scheme": os.environ.get("COLOR_SCHEME", ""),
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
mode = payload["mode"]
if mode == "light":
    css = """:root {
  --seven-runtime-mode: "light";
  --seven-runtime-bg: #FFFFFF;
  --seven-runtime-panel: rgba(255, 255, 255, 0.82);
  --seven-runtime-text: #1C1F26;
  --seven-runtime-muted: #6B7280;
  --seven-runtime-accent: #2F7BFF;
  --seven-runtime-border: rgba(28, 31, 38, 0.08);
}
"""
else:
    css = """:root {
  --seven-runtime-mode: "dark";
  --seven-runtime-bg: #09090B;
  --seven-runtime-panel: rgba(18, 19, 26, 0.78);
  --seven-runtime-text: #EDEDED;
  --seven-runtime-muted: #8A8F98;
  --seven-runtime-accent: #4DA3FF;
  --seven-runtime-border: rgba(255, 255, 255, 0.08);
}
"""
Path(sys.argv[2]).write_text(css, encoding="utf-8")
PY
}

json_status() {
  write_runtime
  cat "$RUNTIME_JSON"
}

doctor() {
  write_runtime
  MODE="$(theme_mode)" ROOT_DIR="$ROOT_DIR" CONFIG_HOME="$CONFIG_HOME" RUNTIME_JSON="$RUNTIME_JSON" python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
config = Path(os.environ["CONFIG_HOME"])
mode = os.environ.get("MODE", "dark")
runtime = json.loads(Path(os.environ["RUNTIME_JSON"]).read_text(encoding="utf-8"))
errors = []
warnings = []

def ok_file(path, label):
    if not path.exists() or path.stat().st_size == 0:
        errors.append(f"{label}: MISS ({path})")

ok_file(root / "identity" / "tokens.css", "dark tokens")
ok_file(root / "identity" / "tokens-light.css", "light tokens")
ok_file(root / "identity" / "design-engine.json", "design engine contract")
ok_file(root / "hyprland" / "waybar" / "style.css", "dark waybar")
ok_file(root / "hyprland-light" / "waybar" / "style.css", "light waybar")
ok_file(root / "hyprland-light" / "swaync" / "style.css", "light swaync")
ok_file(root / "hyprland-light" / "wlogout" / "style.css", "light wlogout")
ok_file(root / "hyprland-light" / "hyprlock.conf", "light hyprlock")

profile_modes = []
for theme_file in sorted((config / "sevenos" / "profiles").glob("*/theme.conf")):
    profile = theme_file.parent.name
    try:
        for raw in theme_file.read_text(encoding="utf-8", errors="ignore").splitlines():
            key, _, value = raw.partition("=")
            if key.strip().lower() in {"mode", "theme_mode", "sevenos_theme_mode"}:
                value = value.strip().strip("'\"").lower()
                if value in {"dark", "light"}:
                    profile_modes.append(f"{profile}:{value}")
                break
    except OSError:
        pass
if profile_modes:
    warnings.append("Profile theme files still force a mode instead of inheriting global theme: " + ", ".join(profile_modes))

keybinds = root / "hyprland" / "lua" / "rules" / "keybinds.lua"
try:
    if "seven-terminal dark" in keybinds.read_text(encoding="utf-8", errors="ignore"):
        warnings.append("Hyprland keybinds still force seven-terminal dark")
except OSError:
    errors.append("Hyprland keybinds missing")

native_surface_files = [
    "bin/seven-actions-native",
    "bin/seven-app-menu-native",
    "bin/seven-profile-center-native",
    "bin/seven-mini-os-center",
    "bin/seven-notification-center-native",
    "bin/seven-dock-native",
    "bin/seven-shield-center-native",
    "bin/seven-waybar-center-native",
    "bin/seven-doctor-native",
    "bin/seven-terminal-native",
]
for relative in native_surface_files:
    path = root / relative
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        errors.append(f"native surface missing: {relative}")
        continue
    if "seven_theme" not in text and "current_theme_mode" not in text and "SEVENOS_THEME_MODE" not in text:
        warnings.append(f"native surface is not theme-aware yet: {relative}")

toolkits = runtime.get("toolkits", {})
gtk = toolkits.get("gtk_theme", "")
icons = toolkits.get("icon_theme", "")
qt6 = toolkits.get("qt6_icon_theme", "")
kvantum = toolkits.get("kvantum_theme", "")
if not gtk:
    warnings.append("GTK theme not resolved in active user config")
if not icons:
    warnings.append("GTK icon theme not resolved in active user config")
if icons and qt6 and icons != qt6:
    warnings.append(f"GTK/Qt icon mismatch: GTK={icons} Qt6={qt6}")
if mode == "light" and kvantum and "latte" not in kvantum.lower() and "light" not in kvantum.lower():
    warnings.append(f"Light mode Kvantum does not look light-specific: {kvantum}")
if mode == "dark" and kvantum and all(token not in kvantum.lower() for token in ("mocha", "dark", "arc", "mojave")):
    warnings.append(f"Dark mode Kvantum does not look dark-specific: {kvantum}")

tokens_light = (root / "identity" / "tokens-light.css").read_text(encoding="utf-8")
for token in ("--ease-cinematic", "--glow-blue", "--glass-border-2", "@media (prefers-reduced-motion"):
    if token not in tokens_light:
        errors.append(f"light tokens missing parity token: {token}")

state = "ok" if not errors else "error"
print(json.dumps({
    "schema": "sevenos.theme-doctor.v1",
    "state": state,
    "mode": mode,
    "runtime": runtime,
    "errors": errors,
    "warnings": warnings,
}, indent=2))
raise SystemExit(0 if not errors else 1)
PY
}

status() {
  write_runtime
  python - "$RUNTIME_JSON" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print("SevenOS Theme Engine")
print("====================")
print()
print(f"Mode:      {data.get('mode')}")
toolkits = data.get("toolkits", {})
print(f"GTK:       {toolkits.get('gtk_theme') or 'MISS'}")
print(f"Icons:     {toolkits.get('icon_theme') or 'MISS'}")
print(f"Cursor:    {toolkits.get('cursor_theme') or 'MISS'}")
print(f"Qt5 icon:  {toolkits.get('qt5_icon_theme') or 'MISS'}")
print(f"Qt6 icon:  {toolkits.get('qt6_icon_theme') or 'MISS'}")
print(f"Kvantum:   {toolkits.get('kvantum_theme') or 'MISS'}")
print()
print("Doctor:")
print("  seven identity theme-doctor")
print("Apply:")
print("  ./install.sh theme dark")
print("  ./install.sh theme light")
PY
}

case "${1:-status}" in
  status) status ;;
  json|--json) json_status ;;
  doctor) doctor ;;
  apply) write_runtime ;;
  *) printf 'Usage: theme-engine.sh [status|json|doctor|apply]\n' >&2; exit 2 ;;
esac
