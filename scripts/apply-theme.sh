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
HYPRPAPER_CONFIG="$CONFIG_HOME/hypr/hyprpaper.conf"

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
    printf 'pkill -x waybar hyprpaper mako || true\n'
    printf 'waybar -c %q -s %q >/tmp/sevenos-waybar.log 2>&1 &\n' "$CONFIG_HOME/waybar/config.jsonc" "$CONFIG_HOME/waybar/style.css"
    printf 'hyprpaper >/tmp/sevenos-hyprpaper.log 2>&1 &\n'
    printf 'mako >/tmp/sevenos-mako.log 2>&1 &\n'
    return 0
  fi

  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
  fi

  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    pkill -x waybar >/dev/null 2>&1 || true
    pkill -x hyprpaper >/dev/null 2>&1 || true
    pkill -x mako >/dev/null 2>&1 || true
    if command -v waybar >/dev/null 2>&1; then
      waybar -c "$CONFIG_HOME/waybar/config.jsonc" -s "$CONFIG_HOME/waybar/style.css" >/tmp/sevenos-waybar.log 2>&1 &
    fi
    if command -v hyprpaper >/dev/null 2>&1; then
      hyprpaper >/tmp/sevenos-hyprpaper.log 2>&1 &
      sleep 0.4
    fi
    if command -v hyprctl >/dev/null 2>&1; then
      hyprctl hyprpaper unload all >/dev/null 2>&1 || true
      hyprctl hyprpaper preload "$WALLPAPER_PNG" >/dev/null 2>&1 || true
      hyprctl hyprpaper wallpaper ",$WALLPAPER_PNG" >/dev/null 2>&1 || true
    fi
    if command -v mako >/dev/null 2>&1; then
      mako >/tmp/sevenos-mako.log 2>&1 &
    fi
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "SevenOS desktop refreshed" "Use Super+Space for Hub, Super+A for Apps, Super+/ for Help" || true
    fi
  fi
}

write_hyprpaper_config() {
  log_info "Writing Hyprpaper config with absolute SevenOS wallpaper path..."

  if is_dry_run; then
    printf 'write hyprpaper config %q using %q\n' "$HYPRPAPER_CONFIG" "$WALLPAPER_PNG"
    return 0
  fi

  mkdir -p "$(dirname -- "$HYPRPAPER_CONFIG")"
  {
    printf 'ipc = on\n'
    printf 'preload = %s\n' "$WALLPAPER_PNG"
    printf 'wallpaper = ,%s\n' "$WALLPAPER_PNG"
    printf 'splash = false\n'
  } > "$HYPRPAPER_CONFIG"
}

configure_file_experience() {
  log_info "Configuring SevenOS file experience..."

  if is_dry_run; then
    printf 'xdg-user-dirs-update\n'
    printf 'mkdir -p %q %q %q %q %q %q\n' "$HOME/Documents" "$HOME/Downloads" "$HOME/Pictures" "$HOME/Videos" "$HOME/Music" "$HOME/Projects"
    printf 'xdg-mime default org.gnome.Nautilus.desktop inode/directory\n'
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
}

configure_toolkit_theme() {
  log_info "Configuring SevenOS GTK and Qt theme coherence..."

  if is_dry_run; then
    printf 'copy GTK and Qt SevenOS settings into %q\n' "$CONFIG_HOME"
    printf 'gsettings set org.gnome.desktop.interface color-scheme prefer-dark\n'
    printf 'gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark\n'
    printf 'gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark\n'
    return 0
  fi

  copy_config_dir "$ROOT_DIR/hyprland/gtk-3.0" "$CONFIG_HOME/gtk-3.0"
  copy_config_dir "$ROOT_DIR/hyprland/gtk-4.0" "$CONFIG_HOME/gtk-4.0"
  copy_config_dir "$ROOT_DIR/hyprland/qt5ct" "$CONFIG_HOME/qt5ct"
  copy_config_dir "$ROOT_DIR/hyprland/qt6ct" "$CONFIG_HOME/qt6ct"

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark >/dev/null 2>&1 || true
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
run_cmd cp -r "$ROOT_DIR/identity/patterns" "$DATA_HOME/sevenos/identity/patterns"
render_wallpaper
write_hyprpaper_config
configure_file_experience

install_shell_hook "$HOME/.bashrc"
install_shell_hook "$HOME/.zshrc"
reload_desktop_session

log_success "SevenOS theme applied."
log_info "Use Super+Space for Seven Hub, Super+A for apps, and Super+/ for desktop help."
log_info "Disable terminal country signals with: export SEVENOS_TERMINAL_COUNTRY=0"
