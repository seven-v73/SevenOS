#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SHELL_HOOK="$CONFIG_HOME/sevenos/shell/terminal-country.sh"
WALLPAPER_DIR="$DATA_HOME/sevenos/wallpapers"
WALLPAPER_PNG="$WALLPAPER_DIR/wallpaper-sevenos-royal-kente.png"
WALLPAPER_ACTIVE="$WALLPAPER_DIR/wallpaper-sevenos-active.png"
HYPRPAPER_CONFIG="$CONFIG_HOME/hypr/hyprpaper.conf"
SYSTEMD_USER_DIR="$CONFIG_HOME/systemd/user"
WAYLAND_SESSION_DIR="$DATA_HOME/wayland-sessions"

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
      notify-send "SevenOS desktop refreshed" "Use Super+Space for Hub, Super+A for Apps, Super+/ for Help" || true
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
    printf 'xdg-mime default org.gnome.Nautilus.desktop inode/directory\n'
    printf 'install Nautilus script: Set as SevenOS Wallpaper\n'
    printf 'install desktop action: Set as SevenOS Wallpaper\n'
    printf 'update-desktop-database %q || true\n' "$HOME/.local/share/applications"
    return 0
  fi

  if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update >/dev/null 2>&1 || true
  fi

  mkdir -p "$HOME/Documents" "$HOME/Downloads" "$HOME/Pictures" "$HOME/Videos" "$HOME/Music" "$HOME/Projects"

  if command -v xdg-mime >/dev/null 2>&1 && command -v nautilus >/dev/null 2>&1; then
    xdg-mime default org.gnome.Nautilus.desktop inode/directory >/dev/null 2>&1 || true
    xdg-mime default org.gnome.Nautilus.desktop application/x-gnome-saved-search >/dev/null 2>&1 || true
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

  mkdir -p "$HOME/.local/share/applications"
  cp "$ROOT_DIR/seven-hub/seven-wallpaper.desktop" "$HOME/.local/share/applications/seven-wallpaper.desktop"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi
}

configure_toolkit_theme() {
  log_info "Configuring SevenOS GTK and Qt theme coherence..."

  if is_dry_run; then
    printf 'copy GTK and Qt SevenOS settings into %q\n' "$CONFIG_HOME"
    printf 'gsettings set org.gnome.desktop.interface color-scheme prefer-light\n'
    printf 'gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3\n'
    printf 'gsettings set org.gnome.desktop.interface icon-theme Papirus\n'
    return 0
  fi

  copy_config_dir "$ROOT_DIR/hyprland/gtk-3.0" "$CONFIG_HOME/gtk-3.0"
  copy_config_dir "$ROOT_DIR/hyprland/gtk-4.0" "$CONFIG_HOME/gtk-4.0"
  copy_config_dir "$ROOT_DIR/hyprland/qt5ct" "$CONFIG_HOME/qt5ct"
  copy_config_dir "$ROOT_DIR/hyprland/qt6ct" "$CONFIG_HOME/qt6ct"

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-light >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3 >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface icon-theme Papirus >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic >/dev/null 2>&1 || true
  fi
}

render_wallpaper() {
  log_info "Rendering SevenOS Sovereign Graphite wallpaper..."

  if is_dry_run; then
    printf 'rm -f %q\n' "$WALLPAPER_PNG"
    printf 'rsvg-convert -w 1920 -h 1080 %q -o %q\n' "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" "$WALLPAPER_PNG"
    return 0
  fi

  rm -f "$WALLPAPER_PNG"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1920 -h 1080 "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" -o "$WALLPAPER_PNG"
  elif command -v magick >/dev/null 2>&1; then
    magick "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" -resize 1920x1080! "$WALLPAPER_PNG"
  else
    log_warn "No SVG renderer found. Install librsvg or imagemagick to generate the PNG wallpaper."
    log_warn "Run: sudo pacman -S --needed librsvg"
    return 1
  fi
}

log_info "Applying SevenOS African first theme..."
copy_config_file "$ROOT_DIR/hyprland/hyprland.conf" "$CONFIG_HOME/hypr/hyprland.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/monitor.conf" "$CONFIG_HOME/hypr/conf/monitor.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/keyboard.conf" "$CONFIG_HOME/hypr/conf/keyboard.conf"
install_preserved_config_file "$ROOT_DIR/hyprland/conf/custom.conf" "$CONFIG_HOME/hypr/conf/custom.conf"
copy_config_dir "$ROOT_DIR/hyprland/waybar" "$CONFIG_HOME/waybar"
copy_config_dir "$ROOT_DIR/hyprland/rofi" "$CONFIG_HOME/rofi"
copy_config_dir "$ROOT_DIR/hyprland/mako" "$CONFIG_HOME/mako"
copy_config_dir "$ROOT_DIR/hyprland/kitty" "$CONFIG_HOME/kitty"
configure_toolkit_theme
copy_config_file "$ROOT_DIR/branding/shell/terminal-country.sh" "$SHELL_HOOK"

run_cmd mkdir -p "$WALLPAPER_DIR" "$DATA_HOME/sevenos/countries" "$DATA_HOME/sevenos/identity" "$DATA_HOME/icons/hicolor/scalable/apps"
run_cmd cp "$ROOT_DIR/identity/assets/wallpaper-sevenos.svg" "$WALLPAPER_DIR/wallpaper-sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/assets/logo-sevenos.svg" "$DATA_HOME/icons/hicolor/scalable/apps/sevenos.svg"
run_cmd cp "$ROOT_DIR/identity/countries/africa.tsv" "$DATA_HOME/sevenos/countries/africa.tsv"
run_cmd cp "$ROOT_DIR/identity/tokens.css" "$DATA_HOME/sevenos/identity/tokens.css"
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
log_info "Use Super+Space for Seven Hub, Super+A for apps, and Super+/ for desktop help."
log_info "Disable terminal country signals with: export SEVENOS_TERMINAL_COUNTRY=0"
