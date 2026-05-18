#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SEVENOS_CONFIG_DIR="$CONFIG_HOME/sevenos"
THEME_PREF="$SEVENOS_CONFIG_DIR/theme.conf"
SHELL_HOOK="$CONFIG_HOME/sevenos/shell/terminal-country.sh"
WALLPAPER_DIR="$DATA_HOME/sevenos/wallpapers"
WALLPAPER_PNG="$WALLPAPER_DIR/wallpaper-sevenos-royal-kente.png"
WALLPAPER_ACTIVE="$WALLPAPER_DIR/wallpaper-sevenos-active.png"
HYPRPAPER_CONFIG="$CONFIG_HOME/hypr/hyprpaper.conf"
SYSTEMD_USER_DIR="$CONFIG_HOME/systemd/user"
WAYLAND_SESSION_DIR="$DATA_HOME/wayland-sessions"
REQUESTED_THEME="${1:-${SEVENOS_THEME_MODE:-}}"

read_persisted_theme() {
  if [[ -f "$THEME_PREF" ]]; then
    # shellcheck disable=SC1090
    source "$THEME_PREF" || true
  fi
  printf '%s' "${SEVENOS_THEME_MODE:-dark}"
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
    THEME_LABEL="Light Mode"
    WALLPAPER_SVG="$ROOT_DIR/identity/assets/wallpaper-sevenos-light.svg"
    WALLPAPER_PNG="$WALLPAPER_DIR/wallpaper-sevenos-light.png"
    ;;
  dark)
    THEME_SOURCE_DIR="$ROOT_DIR/hyprland"
    THEME_LABEL="Dark Mode"
    WALLPAPER_SVG="$ROOT_DIR/identity/assets/wallpaper-sevenos.svg"
    ;;
esac

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
    systemctl --user enable sevenos-waybar.service sevenos-notifications.service sevenos-wallpaper.service sevenos-idle.service >/dev/null 2>&1 || true
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
  cp "$ROOT_DIR/seven-hub/seven-files.desktop" "$HOME/.local/share/applications/seven-files.desktop"

  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default seven-files.desktop inode/directory >/dev/null 2>&1 || true
    xdg-mime default seven-files.desktop application/x-gnome-saved-search >/dev/null 2>&1 || true
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

  if is_dry_run; then
    printf 'copy GTK, Qt and fontconfig SevenOS settings into %q\n' "$CONFIG_HOME"
    printf '%q apply-default\n' "$ROOT_DIR/scripts/fonts.sh"
    if [[ "$THEME_MODE" == "light" ]]; then
      printf 'gsettings set org.gnome.desktop.interface color-scheme prefer-light\n'
    else
      printf 'gsettings set org.gnome.desktop.interface color-scheme prefer-dark\n'
    fi
    printf 'gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3\n'
    printf 'gsettings set org.gnome.desktop.interface icon-theme Papirus\n'
    printf 'gsettings set org.gnome.desktop.interface gtk-decoration-layout close,minimize,maximize:\n'
    printf 'gsettings set org.gnome.nautilus.preferences default-folder-viewer icon-view\n'
    return 0
  fi

  copy_config_dir "$THEME_SOURCE_DIR/gtk-3.0" "$CONFIG_HOME/gtk-3.0"
  copy_config_dir "$THEME_SOURCE_DIR/gtk-4.0" "$CONFIG_HOME/gtk-4.0"
  copy_config_dir "$ROOT_DIR/hyprland/qt5ct" "$CONFIG_HOME/qt5ct"
  copy_config_dir "$ROOT_DIR/hyprland/qt6ct" "$CONFIG_HOME/qt6ct"
  copy_config_dir "$ROOT_DIR/hyprland/fontconfig" "$CONFIG_HOME/fontconfig"
  "$ROOT_DIR/scripts/fonts.sh" apply-default

  if command -v gsettings >/dev/null 2>&1; then
    if [[ "$THEME_MODE" == "light" ]]; then
      gsettings set org.gnome.desktop.interface color-scheme prefer-light >/dev/null 2>&1 || true
    else
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
    fi
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3 >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface icon-theme Papirus >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface font-name 'SF Pro Display 10' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface document-font-name 'SF Pro Text 10' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface monospace-font-name 'SF Mono 10' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-decoration-layout 'close,minimize,maximize:' >/dev/null 2>&1 || true
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'icon-view' >/dev/null 2>&1 || true
    gsettings set org.gnome.nautilus.icon-view default-zoom-level 'large' >/dev/null 2>&1 || true
    gsettings set org.gtk.Settings.FileChooser sort-directories-first true >/dev/null 2>&1 || true
  fi
}

render_wallpaper() {
  log_info "Rendering SevenOS $THEME_LABEL wallpaper..."

  if is_dry_run; then
    printf 'rm -f %q\n' "$WALLPAPER_PNG"
    printf 'rsvg-convert -w 1920 -h 1080 %q -o %q\n' "$WALLPAPER_SVG" "$WALLPAPER_PNG"
    printf 'cp %q %q\n' "$WALLPAPER_PNG" "$WALLPAPER_ACTIVE"
    return 0
  fi

  rm -f "$WALLPAPER_PNG"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1920 -h 1080 "$WALLPAPER_SVG" -o "$WALLPAPER_PNG"
  elif command -v magick >/dev/null 2>&1; then
    magick "$WALLPAPER_SVG" -resize 1920x1080! "$WALLPAPER_PNG"
  else
    log_warn "No SVG renderer found. Install librsvg or imagemagick to generate the PNG wallpaper."
    log_warn "Run: sudo pacman -S --needed librsvg"
    return 1
  fi
  cp "$WALLPAPER_PNG" "$WALLPAPER_ACTIVE"
}

log_info "Applying SevenOS Beyond the Desktop theme: $THEME_LABEL..."
persist_theme_mode
copy_config_file "$ROOT_DIR/hyprland/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/monitor.conf" "$CONFIG_HOME/hypr/conf/monitor.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/keyboard.conf" "$CONFIG_HOME/hypr/conf/keyboard.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/custom.conf" "$CONFIG_HOME/hypr/conf/custom.conf"
copy_config_dir "$THEME_SOURCE_DIR/waybar" "$CONFIG_HOME/waybar"
copy_config_dir "$THEME_SOURCE_DIR/rofi" "$CONFIG_HOME/rofi"
copy_config_dir "$THEME_SOURCE_DIR/mako" "$CONFIG_HOME/mako"
copy_config_dir "$THEME_SOURCE_DIR/kitty" "$CONFIG_HOME/kitty"
configure_toolkit_theme
copy_config_file "$ROOT_DIR/branding/shell/terminal-country.sh" "$SHELL_HOOK"

run_cmd mkdir -p "$WALLPAPER_DIR" "$DATA_HOME/sevenos/countries" "$DATA_HOME/sevenos/identity" "$DATA_HOME/icons/hicolor/scalable/apps"
run_cmd cp "$WALLPAPER_SVG" "$WALLPAPER_DIR/wallpaper-sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos.svg" "$DATA_HOME/icons/hicolor/scalable/apps/sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/countries/africa.tsv" "$DATA_HOME/sevenos/countries/africa.tsv"
if [[ "$THEME_MODE" == "light" ]]; then
  run_cmd cp "$ROOT_DIR/identity/tokens-light.css" "$DATA_HOME/sevenos/identity/tokens.css"
else
  run_cmd cp "$ROOT_DIR/identity/tokens.css" "$DATA_HOME/sevenos/identity/tokens.css"
fi
run_cmd cp "$ROOT_DIR/identity/tokens.css" "$DATA_HOME/sevenos/identity/tokens-dark.css"
run_cmd cp "$ROOT_DIR/identity/tokens-light.css" "$DATA_HOME/sevenos/identity/tokens-light.css"
run_cmd cp "$ROOT_DIR/identity/accent-packs.json" "$DATA_HOME/sevenos/identity/accent-packs.json"
run_cmd cp -r "$ROOT_DIR/identity/patterns" "$DATA_HOME/sevenos/identity/patterns"
run_cmd cp -r "$ROOT_DIR/identity/components" "$DATA_HOME/sevenos/identity/components"
render_wallpaper
write_hyprpaper_config
configure_file_experience
configure_user_session_services

install_shell_hook "$HOME/.bashrc"
install_shell_hook "$HOME/.zshrc"
reload_desktop_session

log_success "SevenOS theme applied."
log_info "Use Super for apps, Super+D for Dock, Super+Space for SevenOS Spotlight, and Super+H for desktop help."
log_info "Disable terminal country signals with: export SEVENOS_TERMINAL_COUNTRY=0"
