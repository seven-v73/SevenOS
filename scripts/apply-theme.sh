#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SEVENOS_CONFIG_DIR="$CONFIG_HOME/sevenos"
THEME_PREF="$SEVENOS_CONFIG_DIR/theme.conf"
WALLPAPER_STATE="$SEVENOS_CONFIG_DIR/wallpaper-state"
SHELL_HOOK="$CONFIG_HOME/sevenos/shell/terminal-country.sh"
WALLPAPER_DIR="$DATA_HOME/sevenos/wallpapers"
WALLPAPER_PNG="$WALLPAPER_DIR/wallpaper-sevenos-royal-kente.png"
WALLPAPER_ACTIVE="$WALLPAPER_DIR/wallpaper-sevenos-active.png"
HYPRPAPER_CONFIG="$CONFIG_HOME/hypr/hyprpaper.conf"
SYSTEMD_USER_DIR="$CONFIG_HOME/systemd/user"
WAYLAND_SESSION_DIR="$DATA_HOME/wayland-sessions"
DESIGN_ENGINE_STATE="$SEVENOS_CONFIG_DIR/design-engine.json"
REQUESTED_THEME="${1:-${SEVENOS_THEME_MODE:-}}"

read_persisted_theme() {
  if [[ -f "$THEME_PREF" ]]; then
    # shellcheck disable=SC1090
    source "$THEME_PREF" || true
  fi
  printf '%s' "${SEVENOS_THEME_MODE:-dark}"
}

wallpaper_state_value() {
  local key="$1"
  [[ -f "$WALLPAPER_STATE" ]] || return 1
  awk -F '\t' -v key="$key" '$1 == key { print $2; exit }' "$WALLPAPER_STATE"
}

case "$REQUESTED_THEME" in
  ""|"current") THEME_MODE="$(read_persisted_theme)" ;;
  dark|light) THEME_MODE="$REQUESTED_THEME" ;;
  *)
    log_error "Unsupported SevenOS theme mode: $REQUESTED_THEME"
    log_info "Use: ./install.sh theme dark or ./install.sh theme light"
    exit 2
    ;;
esac

case "$THEME_MODE" in
  light)
    THEME_SOURCE_DIR="$ROOT_DIR/hyprland-light"
    COMMON_SOURCE_DIR="$ROOT_DIR/hyprland"
    THEME_LABEL="Light Mode"
    WALLPAPER_SVG="$ROOT_DIR/identity/assets/wallpaper-sevenos-light.svg"
    WALLPAPER_PNG="$WALLPAPER_DIR/wallpaper-sevenos-light.png"
    ;;
  dark)
    THEME_SOURCE_DIR="$ROOT_DIR/hyprland"
    COMMON_SOURCE_DIR="$ROOT_DIR/hyprland"
    THEME_LABEL="Dark Mode"
    WALLPAPER_SVG="$ROOT_DIR/identity/assets/wallpaper-sevenos.svg"
    ;;
esac

theme_source_or_common() {
  local relative="$1"
  if [[ -e "$THEME_SOURCE_DIR/$relative" ]]; then
    printf '%s/%s' "$THEME_SOURCE_DIR" "$relative"
  else
    printf '%s/%s' "$COMMON_SOURCE_DIR" "$relative"
  fi
}

resolve_icon_theme() {
  SEVENOS_THEME_MODE_ACTIVE="$THEME_MODE" python - <<'PY'
import os
from pathlib import Path

mode = os.environ.get("SEVENOS_THEME_MODE_ACTIVE", "dark")
candidates = (
    [
        "Colloid-Catppuccin-Light",
        "Colloid-Catppuccin",
        "Catppuccin-Latte",
        "Catppuccin-Latte-Light",
        "Catppuccin-Latte-Blue",
    ]
    if mode == "light"
    else [
        "Colloid-Catppuccin-Dark",
        "Colloid-Catppuccin",
        "Catppuccin-Mocha",
        "Catppuccin-Mocha-Dark",
        "Catppuccin-Mocha-Blue",
    ]
)
icon_dirs = [
    Path.home() / ".local/share/icons",
    Path.home() / ".icons",
    Path("/usr/local/share/icons"),
    Path("/usr/share/icons"),
]
available = sorted({
    child.name
    for directory in icon_dirs
    if directory.is_dir()
    for child in directory.iterdir()
    if child.is_dir()
})
lower = {name.lower(): name for name in available}
for candidate in candidates:
    if candidate.lower() in lower:
        print(lower[candidate.lower()])
        raise SystemExit(0)
wanted = "latte" if mode == "light" else "mocha"
for accent in ("blue", "lavender", "mauve", "sky", "purple"):
    for name in available:
        lowered = name.lower()
        if "catppuccin" in lowered and wanted in lowered and accent in lowered and "cursor" not in lowered:
            print(name)
            raise SystemExit(0)
for name in available:
    lowered = name.lower()
    if "catppuccin" in lowered and wanted in lowered and "cursor" not in lowered:
        print(name)
        raise SystemExit(0)
fallbacks = ["Papirus", "Tela-circle", "hicolor"] if mode == "light" else ["Papirus-Dark", "Papirus", "Tela-circle-dark", "Tela-circle", "hicolor"]
for fallback in fallbacks:
    if fallback.lower() in lower:
        print(lower[fallback.lower()])
        raise SystemExit(0)
print("hicolor")
PY
}

ICON_THEME="$(resolve_icon_theme)"

resolve_gtk_theme() {
  SEVENOS_THEME_MODE_ACTIVE="$THEME_MODE" python - <<'PY'
import os
from pathlib import Path

mode = os.environ.get("SEVENOS_THEME_MODE_ACTIVE", "dark")
theme_dirs = [Path.home() / ".local/share/themes", Path.home() / ".themes", Path("/usr/local/share/themes"), Path("/usr/share/themes")]
available = sorted({child.name for directory in theme_dirs if directory.is_dir() for child in directory.iterdir() if child.is_dir()})
lower = {name.lower(): name for name in available}
candidates = (
    [
        "Catppuccin-Latte-Standard-Blue-Light",
        "Catppuccin-Latte-Standard-Lavender-Light",
        "Catppuccin-Latte-Standard-Mauve-Light",
    ]
    if mode == "light"
    else [
        "Catppuccin-Mocha-Standard-Blue-Dark",
        "Catppuccin-Mocha-Standard-Lavender-Dark",
        "Catppuccin-Mocha-Standard-Mauve-Dark",
    ]
)
for candidate in candidates:
    if candidate.lower() in lower:
        print(lower[candidate.lower()])
        raise SystemExit(0)
wanted = "latte" if mode == "light" else "mocha"
for accent in ("blue", "lavender", "mauve", "sky"):
    for name in available:
        lowered = name.lower()
        if "catppuccin" in lowered and wanted in lowered and accent in lowered:
            print(name)
            raise SystemExit(0)
fallbacks = ["adw-gtk3", "Adwaita"] if mode == "light" else ["adw-gtk3-dark", "Adwaita-dark"]
for fallback in fallbacks:
    if fallback.lower() in lower:
        print(lower[fallback.lower()])
        raise SystemExit(0)
print("adw-gtk3" if mode == "light" else "adw-gtk3-dark")
PY
}

resolve_cursor_theme() {
  SEVENOS_THEME_MODE_ACTIVE="$THEME_MODE" python - <<'PY'
import os
from pathlib import Path

mode = os.environ.get("SEVENOS_THEME_MODE_ACTIVE", "dark")
icon_dirs = [Path.home() / ".local/share/icons", Path.home() / ".icons", Path("/usr/local/share/icons"), Path("/usr/share/icons")]
available = sorted({child.name for directory in icon_dirs if directory.is_dir() for child in directory.iterdir() if child.is_dir()})
lower = {name.lower(): name for name in available}
candidates = (
    [
        "Catppuccin-Latte-Blue-Cursors",
        "Catppuccin-Latte-Lavender-Cursors",
        "Catppuccin-Latte-Mauve-Cursors",
        "Bibata-Modern-Ice",
        "Bibata-Modern-Classic",
    ]
    if mode == "light"
    else [
        "Catppuccin-Mocha-Blue-Cursors",
        "Catppuccin-Mocha-Lavender-Cursors",
        "Catppuccin-Mocha-Mauve-Cursors",
        "Bibata-Modern-Ice",
        "Bibata-Modern-Classic",
    ]
)
for candidate in candidates:
    if candidate.lower() in lower:
        print(lower[candidate.lower()])
        raise SystemExit(0)
wanted = "latte" if mode == "light" else "mocha"
for accent in ("blue", "lavender", "mauve", "sky"):
    for name in available:
        lowered = name.lower()
        if "catppuccin" in lowered and wanted in lowered and "cursor" in lowered and accent in lowered:
            print(name)
            raise SystemExit(0)
print("Bibata-Modern-Ice" if mode == "light" else "Bibata-Modern-Classic")
PY
}

resolve_kvantum_theme() {
  SEVENOS_THEME_MODE_ACTIVE="$THEME_MODE" python - <<'PY'
import os
from pathlib import Path

mode = os.environ.get("SEVENOS_THEME_MODE_ACTIVE", "dark")
dirs = [Path.home() / ".config/Kvantum", Path.home() / ".local/share/Kvantum", Path("/usr/local/share/Kvantum"), Path("/usr/share/Kvantum")]
available = sorted({child.name for directory in dirs if directory.is_dir() for child in directory.iterdir() if child.is_dir()})
lower = {name.lower(): name for name in available}
candidates = (
    ["Catppuccin-Latte-Blue", "Catppuccin-Latte-Lavender", "Catppuccin-Latte-Mauve", "KvMojaveLight", "KvFlatLight"]
    if mode == "light"
    else ["Catppuccin-Mocha-Blue", "Catppuccin-Mocha-Lavender", "Catppuccin-Mocha-Mauve", "KvMojave", "KvArcDark"]
)
for candidate in candidates:
    if candidate.lower() in lower:
        print(lower[candidate.lower()])
        raise SystemExit(0)
wanted = "latte" if mode == "light" else "mocha"
for accent in ("blue", "lavender", "mauve", "sky"):
    for name in available:
        lowered = name.lower()
        if "catppuccin" in lowered and wanted in lowered and accent in lowered:
            print(name)
            raise SystemExit(0)
print("KvMojaveLight" if mode == "light" else "KvMojave")
PY
}

GTK_THEME="$(resolve_gtk_theme)"
CURSOR_THEME="$(resolve_cursor_theme)"
KVANTUM_THEME="$(resolve_kvantum_theme)"

persist_theme_mode() {
  log_info "Persisting SevenOS theme mode: $THEME_MODE"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$SEVENOS_CONFIG_DIR"
    printf 'write %q with SEVENOS_THEME_MODE=%q\n' "$THEME_PREF" "$THEME_MODE"
    return 0
  fi

  mkdir -p "$SEVENOS_CONFIG_DIR"
  printf 'SEVENOS_THEME_MODE=%q\n' "$THEME_MODE" > "$THEME_PREF"
}

normalize_profile_theme_modes() {
  log_info "Normalizing mini OS theme modes to inherit the global SevenOS mode..."

  if is_dry_run; then
    printf 'for each %q/profiles/*/theme.conf: set mode=system and keep profile accent metadata\n' "$SEVENOS_CONFIG_DIR"
    return 0
  fi

  local file profile
  shopt -s nullglob
  for file in "$SEVENOS_CONFIG_DIR"/profiles/*/theme.conf; do
    profile="$(basename -- "$(dirname -- "$file")")"
    {
      printf 'mode=system\n'
      printf 'profile=%s\n' "$profile"
      printf 'inherits=global\n'
    } > "$file"
  done
  shopt -u nullglob
}

install_preserved_config_file() {
  local source_file="$1"
  local target_file="$2"
  local target_dir

  target_dir="$(dirname -- "$target_file")"
  log_info "Ensuring protected config: ${target_file#$HOME/}"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$target_dir"
    if [[ ! -e "$target_file" ]]; then
      printf 'cp %q %q\n' "$source_file" "$target_file"
    else
      printf 'preserve existing %q\n' "$target_file"
    fi
    return 0
  fi

  mkdir -p "$target_dir"
  if [[ -e "$target_file" ]]; then
    return 0
  fi
  cp "$source_file" "$target_file"
}

install_shell_hook() {
  local rc_file="$1"
  local marker_start="# >>> SevenOS terminal country signal"
  local marker_end="# <<< SevenOS terminal country signal"

  log_info "Enabling SevenOS terminal country signal in ${rc_file#$HOME/}"

  if is_dry_run; then
    printf 'touch %q\n' "$rc_file"
    printf 'append managed SevenOS terminal country block to %q\n' "$rc_file"
    return 0
  fi

  touch "$rc_file"
  if grep -qF "$marker_start" "$rc_file"; then
    return 0
  fi

  cp -a "$rc_file" "$(backup_path "$rc_file")"
  {
    printf '\n%s\n' "$marker_start"
    printf 'if [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/shell/terminal-country.sh" ]; then\n'
    printf '  . "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/shell/terminal-country.sh"\n'
    printf 'fi\n'
    printf '%s\n' "$marker_end"
  } >> "$rc_file"
}

reload_desktop_session() {
  if is_dry_run; then
    printf 'hyprctl reload\n'
    printf 'systemctl --user start sevenos-session.target || seven-session\n'
    return 0
  fi

  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
  fi

  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user start sevenos-session.target >/dev/null 2>&1 || "$ROOT_DIR/bin/seven-session" >/tmp/sevenos-session.log 2>&1 || true
    elif [[ -x "$ROOT_DIR/bin/seven-session" ]]; then
      "$ROOT_DIR/bin/seven-session" >/tmp/sevenos-session.log 2>&1 || true
    fi
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "SevenOS desktop refreshed" "Use Super for Apps, Super+D for Dock, Super+Space for Spotlight, Super+H for Help" || true
    fi
  fi
}

configure_user_session_services() {
  log_info "Installing SevenOS user session services..."

  if is_dry_run; then
    printf 'mkdir -p %q %q\n' "$SYSTEMD_USER_DIR" "$WAYLAND_SESSION_DIR"
    printf 'cp %q/*.service %q/\n' "$ROOT_DIR/systemd/user" "$SYSTEMD_USER_DIR"
    printf 'cp %q/*.target %q/\n' "$ROOT_DIR/systemd/user" "$SYSTEMD_USER_DIR"
    printf 'cp %q %q/\n' "$ROOT_DIR/session/sevenos.desktop" "$WAYLAND_SESSION_DIR"
    printf 'systemctl --user daemon-reload\n'
    printf 'systemctl --user enable sevenos-session.target\n'
    return 0
  fi

  mkdir -p "$SYSTEMD_USER_DIR" "$WAYLAND_SESSION_DIR"
  cp "$ROOT_DIR"/systemd/user/*.service "$SYSTEMD_USER_DIR"/
  cp "$ROOT_DIR"/systemd/user/*.target "$SYSTEMD_USER_DIR"/
  cp "$ROOT_DIR/session/sevenos.desktop" "$WAYLAND_SESSION_DIR"/

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable sevenos-session.target >/dev/null 2>&1 || true
    systemctl --user enable sevenos-waybar-context.service sevenos-waybar.service sevenos-notifications.service sevenos-wallpaper.service sevenos-idle.service sevenos-shell-experience.service >/dev/null 2>&1 || true
  fi
}

write_hyprpaper_config() {
  log_info "Writing Hyprpaper config with absolute SevenOS wallpaper path..."

  if is_dry_run; then
    printf 'write hyprpaper config %q using %q\n' "$HYPRPAPER_CONFIG" "$WALLPAPER_ACTIVE"
    return 0
  fi

  mkdir -p "$(dirname -- "$HYPRPAPER_CONFIG")"
  if [[ ! -f "$WALLPAPER_ACTIVE" && -f "$WALLPAPER_PNG" ]]; then
    cp "$WALLPAPER_PNG" "$WALLPAPER_ACTIVE"
  fi
  {
    printf 'ipc = on\n'
    printf 'preload = %s\n' "$WALLPAPER_ACTIVE"
    printf 'wallpaper = ,%s\n' "$WALLPAPER_ACTIVE"
    printf 'splash = false\n'
  } > "$HYPRPAPER_CONFIG"
}

configure_file_experience() {
  log_info "Configuring SevenOS file experience..."

  if is_dry_run; then
    printf 'xdg-user-dirs-update\n'
    printf 'mkdir -p %q %q %q %q %q %q\n' "$HOME/Documents" "$HOME/Downloads" "$HOME/Pictures" "$HOME/Videos" "$HOME/Music" "$HOME/Projects"
    printf 'install Seven Files desktop entry\n'
    printf 'install SevenOS Spotlight, AI, Reader, Recorder and Terminal desktop entries\n'
    printf 'write SevenOS default terminal contract\n'
    printf 'write xdg-terminal-exec preference\n'
    printf 'xdg-mime default seven-files.desktop inode/directory\n'
    printf 'install Nautilus script: Set as SevenOS Wallpaper\n'
    printf 'install desktop action: Set as SevenOS Wallpaper\n'
    printf 'remove SevenOS wallpaper from image MIME defaults\n'
    printf 'update-desktop-database %q || true\n' "$HOME/.local/share/applications"
    return 0
  fi

  if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update >/dev/null 2>&1 || true
  fi

  mkdir -p "$HOME/Documents" "$HOME/Downloads" "$HOME/Pictures" "$HOME/Videos" "$HOME/Music" "$HOME/Projects"
  mkdir -p "$HOME/.local/share/applications"
  cp "$ROOT_DIR/seven-hub/seven-actions.desktop" "$HOME/.local/share/applications/seven-actions.desktop"
  cp "$ROOT_DIR/seven-hub/seven-home.desktop" "$HOME/.local/share/applications/seven-home.desktop"
  cp "$ROOT_DIR/seven-hub/seven-files.desktop" "$HOME/.local/share/applications/seven-files.desktop"
  cp "$ROOT_DIR/seven-hub/seven-spotlight.desktop" "$HOME/.local/share/applications/seven-spotlight.desktop"
  cp "$ROOT_DIR/seven-hub/seven-ai.desktop" "$HOME/.local/share/applications/seven-ai.desktop"
  cp "$ROOT_DIR/seven-hub/seven-baobab.desktop" "$HOME/.local/share/applications/seven-baobab.desktop"
  cp "$ROOT_DIR/seven-hub/seven-reader.desktop" "$HOME/.local/share/applications/seven-reader.desktop"
  cp "$ROOT_DIR/seven-hub/seven-recorder.desktop" "$HOME/.local/share/applications/seven-recorder.desktop"
  cp "$ROOT_DIR/seven-hub/seven-store.desktop" "$HOME/.local/share/applications/seven-store.desktop"
  cp "$ROOT_DIR/seven-hub/seven-terminal.desktop" "$HOME/.local/share/applications/seven-terminal.desktop"
  cp "$ROOT_DIR/seven-hub/seven-doctor.desktop" "$HOME/.local/share/applications/seven-doctor.desktop"

  mkdir -p "$CONFIG_HOME/sevenos"
  {
    printf 'SEVENOS_TERMINAL=seven-terminal\n'
    printf 'TERMINAL=seven-terminal\n'
    printf 'SEVENOS_TERMINAL_PROFILE=classic\n'
  } > "$CONFIG_HOME/sevenos/defaults.conf"

  {
    printf 'seven-terminal.desktop\n'
  } > "$CONFIG_HOME/xdg-terminals.list"

  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default seven-files.desktop inode/directory >/dev/null 2>&1 || true
    xdg-mime default seven-files.desktop application/x-gnome-saved-search >/dev/null 2>&1 || true
    xdg-mime default seven-reader.desktop application/pdf >/dev/null 2>&1 || true
    xdg-mime default seven-reader.desktop application/epub+zip >/dev/null 2>&1 || true
    xdg-mime default seven-reader.desktop text/markdown >/dev/null 2>&1 || true
    xdg-mime default seven-reader.desktop application/x-cbz >/dev/null 2>&1 || true
  fi

  local nautilus_scripts_dir="$HOME/.local/share/nautilus/scripts"
  local wallpaper_script="$nautilus_scripts_dir/Set as SevenOS Wallpaper"
  mkdir -p "$nautilus_scripts_dir"
  cat > "$wallpaper_script" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

selected="${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}"
first="$(printf '%s\n' "$selected" | sed -n '1p')"
if [[ -z "$first" && "$#" -gt 0 ]]; then
  first="$1"
fi

if [[ -z "$first" ]]; then
  notify-send "SevenOS Wallpaper" "No image selected." 2>/dev/null || true
  exit 1
fi

if command -v seven-wallpaper >/dev/null 2>&1; then
  seven-wallpaper set "$first"
elif [[ -x "$HOME/Code/OS/SevenOS/bin/seven-wallpaper" ]]; then
  "$HOME/Code/OS/SevenOS/bin/seven-wallpaper" set "$first"
elif [[ -x "$HOME/SevenOS/bin/seven-wallpaper" ]]; then
  "$HOME/SevenOS/bin/seven-wallpaper" set "$first"
else
  notify-send "SevenOS Wallpaper" "seven-wallpaper command not found." 2>/dev/null || true
  exit 1
fi
EOF
  chmod +x "$wallpaper_script"

  cp "$ROOT_DIR/seven-hub/seven-wallpaper.desktop" "$HOME/.local/share/applications/seven-wallpaper.desktop"

  local mime_file
  for mime_file in "$CONFIG_HOME/mimeapps.list" "$HOME/.local/share/applications/mimeapps.list" "$HOME/.local/share/applications/mimeinfo.cache"; do
    if [[ -f "$mime_file" ]]; then
      sed -i \
        -e '/^image\/.*=seven-wallpaper\.desktop;*$/d' \
        -e 's/seven-wallpaper\.desktop;//g' \
        -e 's/;seven-wallpaper\.desktop//g' \
        "$mime_file"
    fi
  done

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi
}

configure_toolkit_theme() {
  log_info "Configuring SevenOS GTK and Qt theme coherence..."
  log_info "Resolved SevenOS GTK theme: $GTK_THEME"
  log_info "Resolved SevenOS icon theme: $ICON_THEME"
  log_info "Resolved SevenOS cursor theme: $CURSOR_THEME"
  log_info "Resolved SevenOS Kvantum theme: $KVANTUM_THEME"

  if is_dry_run; then
    printf 'copy GTK, Qt and fontconfig SevenOS settings into %q\n' "$CONFIG_HOME"
    printf '%q apply-default\n' "$ROOT_DIR/scripts/fonts.sh"
    if [[ "$THEME_MODE" == "light" ]]; then
      printf 'gsettings set org.gnome.desktop.interface color-scheme prefer-light\n'
    else
      printf 'gsettings set org.gnome.desktop.interface color-scheme prefer-dark\n'
    fi
    printf 'gsettings set org.gnome.desktop.interface gtk-theme %q\n' "$GTK_THEME"
    printf 'gsettings set org.gnome.desktop.interface icon-theme %q\n' "$ICON_THEME"
    printf 'gsettings set org.gnome.desktop.interface cursor-theme %q\n' "$CURSOR_THEME"
    printf 'write Kvantum theme %q into %q\n' "$KVANTUM_THEME" "$CONFIG_HOME/Kvantum/kvantum.kvconfig"
    printf 'gsettings set org.gnome.desktop.interface gtk-decoration-layout close,minimize,maximize:\n'
    printf 'gsettings set org.gnome.nautilus.preferences default-folder-viewer icon-view\n'
    printf 'write Seven Design Engine runtime state to %q\n' "$DESIGN_ENGINE_STATE"
    return 0
  fi

  copy_config_dir "$THEME_SOURCE_DIR/gtk-3.0" "$CONFIG_HOME/gtk-3.0"
  copy_config_dir "$THEME_SOURCE_DIR/gtk-4.0" "$CONFIG_HOME/gtk-4.0"
  copy_config_dir "$ROOT_DIR/hyprland/qt5ct" "$CONFIG_HOME/qt5ct"
  copy_config_dir "$ROOT_DIR/hyprland/qt6ct" "$CONFIG_HOME/qt6ct"
  copy_config_dir "$ROOT_DIR/hyprland/fontconfig" "$CONFIG_HOME/fontconfig"
  "$ROOT_DIR/scripts/fonts.sh" apply-default

  sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$ICON_THEME/" \
    "$CONFIG_HOME/gtk-3.0/settings.ini" "$CONFIG_HOME/gtk-4.0/settings.ini" 2>/dev/null || true
  sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$GTK_THEME/" \
    "$CONFIG_HOME/gtk-3.0/settings.ini" "$CONFIG_HOME/gtk-4.0/settings.ini" 2>/dev/null || true
  sed -i "s/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name=$CURSOR_THEME/" \
    "$CONFIG_HOME/gtk-3.0/settings.ini" "$CONFIG_HOME/gtk-4.0/settings.ini" 2>/dev/null || true
  sed -i "s/^icon_theme=.*/icon_theme=$ICON_THEME/" \
    "$CONFIG_HOME/qt5ct/qt5ct.conf" "$CONFIG_HOME/qt6ct/qt6ct.conf" 2>/dev/null || true

  mkdir -p "$CONFIG_HOME/Kvantum"
  {
    printf '[General]\n'
    printf 'theme=%s\n' "$KVANTUM_THEME"
  } > "$CONFIG_HOME/Kvantum/kvantum.kvconfig"

  if command -v gsettings >/dev/null 2>&1; then
    if [[ "$THEME_MODE" == "light" ]]; then
      gsettings set org.gnome.desktop.interface color-scheme prefer-light >/dev/null 2>&1 || true
    else
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
    fi
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface font-name 'SF Pro Display 10' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface document-font-name 'SF Pro Text 10' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface monospace-font-name 'SF Mono 10' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-decoration-layout 'close,minimize,maximize:' >/dev/null 2>&1 || true
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'icon-view' >/dev/null 2>&1 || true
    gsettings set org.gnome.nautilus.icon-view default-zoom-level 'large' >/dev/null 2>&1 || true
    gsettings set org.gtk.Settings.FileChooser sort-directories-first true >/dev/null 2>&1 || true
  fi

  mkdir -p "$SEVENOS_CONFIG_DIR"
  "$ROOT_DIR/scripts/identity.sh" design --json > "$DESIGN_ENGINE_STATE" || true
}

render_wallpaper() {
  local render_size render_width render_height
  render_size="${SEVENOS_WALLPAPER_SIZE:-}"
  if [[ -z "$render_size" ]] && command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    render_size="$(hyprctl monitors -j 2>/dev/null | python -c 'import json,sys
try:
    data=json.load(sys.stdin)
except Exception:
    data=[]
monitors=sorted(data, key=lambda item: 0 if item.get("focused") else 1)
if monitors:
    width=int(monitors[0].get("width") or 1920)
    height=int(monitors[0].get("height") or 1080)
    print(f"{width}x{height}")' 2>/dev/null || true)"
  fi
  render_size="${render_size:-2560x1440}"
  render_width="${render_size%x*}"
  render_height="${render_size#*x}"

  log_info "Rendering SevenOS $THEME_LABEL wallpaper..."
  log_info "Wallpaper render target: ${render_width}x${render_height}"

  if is_dry_run; then
    printf 'rm -f %q\n' "$WALLPAPER_PNG"
    printf 'rsvg-convert -w %q -h %q %q -o %q\n' "$render_width" "$render_height" "$WALLPAPER_SVG" "$WALLPAPER_PNG"
    printf 'cp %q %q\n' "$WALLPAPER_PNG" "$WALLPAPER_ACTIVE"
    return 0
  fi

  rm -f "$WALLPAPER_PNG"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$render_width" -h "$render_height" "$WALLPAPER_SVG" -o "$WALLPAPER_PNG"
  elif command -v magick >/dev/null 2>&1; then
    magick "$WALLPAPER_SVG" -resize "${render_width}x${render_height}!" "$WALLPAPER_PNG"
  else
    log_warn "No SVG renderer found. Install librsvg or imagemagick to generate the PNG wallpaper."
    log_warn "Run: sudo pacman -S --needed librsvg"
    return 1
  fi
  cp "$WALLPAPER_PNG" "$WALLPAPER_ACTIVE"
}

restore_persisted_wallpaper() {
  local mode value profile_png custom_png
  mode="$(wallpaper_state_value mode 2>/dev/null || true)"
  value="$(wallpaper_state_value value 2>/dev/null || true)"
  custom_png="$WALLPAPER_DIR/wallpaper-sevenos-custom.png"

  case "$mode" in
    custom)
      if [[ -f "$custom_png" ]]; then
        log_info "Restoring saved custom SevenOS wallpaper..."
        run_cmd cp "$custom_png" "$WALLPAPER_ACTIVE"
      fi
      ;;
    profile)
      profile_png="$WALLPAPER_DIR/wallpaper-sevenos-${value:-equinox}.png"
      if [[ -f "$profile_png" ]]; then
        log_info "Restoring saved profile SevenOS wallpaper..."
        run_cmd cp "$profile_png" "$WALLPAPER_ACTIVE"
      fi
      ;;
  esac
}

log_info "Applying SevenOS Beyond the Desktop theme: $THEME_LABEL..."
persist_theme_mode
normalize_profile_theme_modes
copy_config_file "$ROOT_DIR/hyprland/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/monitor.conf" "$CONFIG_HOME/hypr/conf/monitor.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/keyboard.conf" "$CONFIG_HOME/hypr/conf/keyboard.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/custom.conf" "$CONFIG_HOME/hypr/conf/custom.conf"
copy_config_dir "$THEME_SOURCE_DIR/waybar" "$CONFIG_HOME/waybar"
copy_config_dir "$THEME_SOURCE_DIR/rofi" "$CONFIG_HOME/rofi"
copy_config_dir "$(theme_source_or_common mako)" "$CONFIG_HOME/mako"
copy_config_dir "$(theme_source_or_common swaync)" "$CONFIG_HOME/swaync"
copy_config_dir "$(theme_source_or_common wlogout)" "$CONFIG_HOME/wlogout"
copy_config_dir "$THEME_SOURCE_DIR/kitty" "$CONFIG_HOME/kitty"
copy_config_file "$ROOT_DIR/hyprland/hypridle.conf" "$CONFIG_HOME/hypr/hypridle.conf"
copy_config_file "$(theme_source_or_common hyprlock.conf)" "$CONFIG_HOME/hypr/hyprlock.conf"
copy_config_file "$ROOT_DIR/hyprland/conf/sevenos-windows.conf" "$CONFIG_HOME/hypr/conf/sevenos-windows.conf"
copy_config_file "$ROOT_DIR/hyprland/conf/sevenos-lua-generated.conf" "$CONFIG_HOME/hypr/conf/sevenos-lua-generated.conf"
copy_config_file "$ROOT_DIR/hyprland/conf/sevenos-dynamic.conf" "$CONFIG_HOME/hypr/conf/sevenos-dynamic.conf"
copy_config_file "$ROOT_DIR/hyprland/conf/sevenos-motion.conf" "$CONFIG_HOME/hypr/conf/sevenos-motion.conf"
copy_config_file "$ROOT_DIR/hyprland-light/kitty/light.conf" "$CONFIG_HOME/kitty/light.conf"
configure_toolkit_theme
copy_config_file "$ROOT_DIR/branding/shell/terminal-country.sh" "$SHELL_HOOK"

run_cmd mkdir -p "$WALLPAPER_DIR" "$DATA_HOME/sevenos/countries" "$DATA_HOME/sevenos/identity" "$DATA_HOME/icons/hicolor/scalable/apps"
run_cmd cp "$WALLPAPER_SVG" "$WALLPAPER_DIR/wallpaper-sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos.svg" "$DATA_HOME/icons/hicolor/scalable/apps/sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-hub.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-hub.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-files.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-files.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-reader.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-reader.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-store.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-store.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-settings.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-settings.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-spotlight.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-spotlight.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-ai.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-ai.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-security.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-security.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-studio.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-studio.svg"
run_cmd cp "$ROOT_DIR/identity/icons/seven-baobab.svg" "$DATA_HOME/icons/hicolor/scalable/apps/seven-baobab.svg"
run_cmd cp "$ROOT_DIR/identity/countries/africa.tsv" "$DATA_HOME/sevenos/countries/africa.tsv"
if [[ "$THEME_MODE" == "light" ]]; then
  run_cmd cp "$ROOT_DIR/identity/tokens-light.css" "$DATA_HOME/sevenos/identity/tokens.css"
else
  run_cmd cp "$ROOT_DIR/identity/tokens.css" "$DATA_HOME/sevenos/identity/tokens.css"
fi
run_cmd cp "$ROOT_DIR/identity/tokens.css" "$DATA_HOME/sevenos/identity/tokens-dark.css"
run_cmd cp "$ROOT_DIR/identity/tokens-light.css" "$DATA_HOME/sevenos/identity/tokens-light.css"
run_cmd cp "$ROOT_DIR/identity/control-center-dark.css" "$DATA_HOME/sevenos/identity/control-center-dark.css"
run_cmd cp "$ROOT_DIR/identity/control-center-light.css" "$DATA_HOME/sevenos/identity/control-center-light.css"
run_cmd cp "$ROOT_DIR/identity/design-engine.json" "$DATA_HOME/sevenos/identity/design-engine.json"
run_cmd cp "$ROOT_DIR/identity/design-engine.css" "$DATA_HOME/sevenos/identity/design-engine.css"
run_cmd cp -r "$ROOT_DIR/identity/icons" "$DATA_HOME/sevenos/identity/icons"
run_cmd cp "$ROOT_DIR/identity/accent-packs.json" "$DATA_HOME/sevenos/identity/accent-packs.json"
run_cmd cp -r "$ROOT_DIR/identity/patterns" "$DATA_HOME/sevenos/identity/patterns"
run_cmd cp -r "$ROOT_DIR/identity/components" "$DATA_HOME/sevenos/identity/components"
render_wallpaper
restore_persisted_wallpaper
write_hyprpaper_config
"$ROOT_DIR/scripts/wallpaper-theme.sh" generate "$WALLPAPER_ACTIVE" || true
"$ROOT_DIR/scripts/theme-engine.sh" apply || true
configure_file_experience
configure_user_session_services
"$ROOT_DIR/scripts/hypr-ecosystem.sh" apply || true

install_shell_hook "$HOME/.bashrc"
install_shell_hook "$HOME/.zshrc"
reload_desktop_session

log_success "SevenOS theme applied."
log_info "Use Super for apps, Super+D for Dock, Super+Space for SevenOS Spotlight, and Super+H for desktop help."
log_info "Disable terminal country signals with: export SEVENOS_TERMINAL_COUNTRY=0"
