#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
export SEVENOS_ROOT="$ROOT_DIR"
source "$ROOT_DIR/scripts/lib.sh"

host_home() {
  local home="${SEVENOS_HOST_HOME:-$HOME}"
  if [[ -n "${SEVENOS_HOST_HOME:-}" ]]; then
    printf '%s\n' "$home"
    return 0
  fi
  case "$home" in
    */.local/share/sevenos/profile-containers/*/home)
      printf '%s\n' "${home%%/.local/share/sevenos/profile-containers/*}"
      return 0
      ;;
  esac
  if [[ -n "${USER:-}" && -d "/home/$USER" ]]; then
    printf '/home/%s\n' "$USER"
  else
    printf '%s\n' "$home"
  fi
}

HOST_HOME="$(host_home)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
FONT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/SevenOS"
FONT_CONFIG_DIR="$CONFIG_HOME/fontconfig"
FONT_PREFS="$CONFIG_HOME/sevenos/fonts.conf"
HOST_CONFIG_HOME="${SEVENOS_HOST_CONFIG_HOME:-$HOST_HOME/.config}"
HOST_DATA_HOME="${SEVENOS_HOST_DATA_HOME:-$HOST_HOME/.local/share}"

default_prefs() {
  local interface="Inter"
  local text="Inter"
  local mono="JetBrainsMono Nerd Font"
  local cyber="JetBrainsMono Nerd Font"
  local brand="Inter"

  cat <<EOF
interface="$interface"
text="$text"
mono="$mono"
cyber="$cyber"
brand="$brand"
EOF
}

ensure_core_prefs() {
  if is_dry_run; then
    printf 'ensure SevenOS Core font preferences in %q\n' "$FONT_PREFS"
    return 0
  fi
  mkdir -p "$(dirname -- "$FONT_PREFS")"
  if [[ ! -f "$FONT_PREFS" ]] ||
     grep -Eq '^(interface|text|mono|brand)="SF (Pro|Mono)' "$FONT_PREFS"; then
    default_prefs > "$FONT_PREFS"
  fi
}

family_match() {
  local family="$1"
  if ! command -v fc-match >/dev/null 2>&1; then
    printf 'MISS'
    return 0
  fi
  fc-match "$family" 2>/dev/null | sed 's/:.*//' | sed 's/[[:space:]]*$//' || printf 'MISS'
}

family_ready() {
  local family="$1"
  if ! command -v fc-match >/dev/null 2>&1; then
    return 1
  fi
  local matched
  matched="$(fc-match "$family" 2>/dev/null || true)"
  [[ "${matched,,}" == *"${family,,}"* ]]
}

copy_fonts_from() {
  local source="$1"
  local target="$FONT_HOME/Imported"

  if [[ ! -e "$source" ]]; then
    log_error "Font source not found: $source"
    exit 1
  fi

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$target"
    printf 'copy font files from %q into %q\n' "$source" "$target"
    return 0
  fi

  mkdir -p "$target"
  if [[ -d "$source" ]]; then
    find "$source" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \) -exec cp -n {} "$target"/ \;
  else
    case "${source,,}" in
      *.ttf|*.otf|*.ttc) cp -n "$source" "$target"/ ;;
      *) log_error "Unsupported font file: $source"; exit 1 ;;
    esac
  fi
}

install_local_sources() {
  local target="$FONT_HOME/SanFrancisco"
  local source

  if is_dry_run; then
    printf 'install local SF Pro/SF UI/SF Mono fonts into %q when available\n' "$target"
    return 0
  fi

  mkdir -p "$target"
  for source in \
    "$HOME/Downloads/font" \
    "$HOME/.local/share/fonts/SF-Pro" \
    "/usr/share/fonts/apple" \
    "$HOME/.local/share/fonts/SevenOS/SFMono" \
    "$HOME/Files/Personal/Computer Files/SF-Mono.dmg" \
    "$HOST_HOME/Downloads/font" \
    "$HOST_HOME/.local/share/fonts/SF-Pro" \
    "$HOST_HOME/.local/share/fonts/SevenOS/SFMono" \
    "$HOST_HOME/Files/Personal/Computer Files/SF-Mono.dmg"; do
    [[ -e "$source" ]] || continue
    if [[ -d "$source" ]]; then
      find "$source" -type f \( -iname 'SF*.ttf' -o -iname 'SF*.otf' -o -iname 'SF*.ttc' \) -exec cp -n {} "$target"/ \;
    elif [[ "${source,,}" == *.dmg && -x /usr/bin/7z && -x /usr/bin/bsdtar ]]; then
      local work
      work="$(mktemp -d)"
      if 7z x "$source" -o"$work/dmg" >/dev/null 2>&1 &&
         find "$work/dmg" -iname '*.pkg' -print -quit | grep -q .; then
        local pkg
        pkg="$(find "$work/dmg" -iname '*.pkg' -print -quit)"
        mkdir -p "$work/pkg" "$work/payload"
        7z x "$pkg" -o"$work/pkg" >/dev/null 2>&1 || true
        if [[ -f "$work/pkg/SFMonoFonts.pkg/Payload" ]]; then
          bsdtar -xf "$work/pkg/SFMonoFonts.pkg/Payload" -C "$work/payload" >/dev/null 2>&1 || true
          find "$work/payload" -type f \( -iname 'SF*.otf' -o -iname 'SF*.ttf' \) -exec cp -n {} "$target"/ \;
        fi
      fi
      rm -rf "$work"
    fi
  done
}

with_font_targets() {
  local config_home="$1"
  local data_home="$2"
  shift 2

  CONFIG_HOME="$config_home" \
  DATA_HOME="$data_home" \
  XDG_CONFIG_HOME="$config_home" \
  XDG_DATA_HOME="$data_home" \
  FONT_HOME="$data_home/fonts/SevenOS" \
  FONT_CONFIG_DIR="$config_home/fontconfig" \
  FONT_PREFS="$config_home/sevenos/fonts.conf" \
  "$@"
}

write_fontconfig() {
  local interface="Inter"
  local text="Inter"
  local mono="JetBrainsMono Nerd Font"
  local cyber="JetBrainsMono Nerd Font"
  local brand="Inter"

  if [[ -f "$FONT_PREFS" ]]; then
    # shellcheck disable=SC1090
    source "$FONT_PREFS"
  fi

  if is_dry_run; then
    printf 'write dynamic SevenOS fontconfig aliases into %q\n' "$FONT_CONFIG_DIR/fonts.conf"
    return 0
  fi

  mkdir -p "$FONT_CONFIG_DIR" "$(dirname -- "$FONT_PREFS")"
  [[ -f "$FONT_PREFS" ]] || default_prefs > "$FONT_PREFS"
  cat > "$FONT_CONFIG_DIR/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias><family>SF Pro Display</family><prefer><family>$interface</family><family>Noto Sans</family></prefer></alias>
  <alias><family>SF UI Display</family><prefer><family>$interface</family><family>Noto Sans</family></prefer></alias>
  <alias><family>SF Pro Text</family><prefer><family>$text</family><family>Noto Sans</family></prefer></alias>
  <alias><family>SF UI Text</family><prefer><family>$text</family><family>Noto Sans</family></prefer></alias>
  <alias><family>SF Pro Rounded</family><prefer><family>$brand</family><family>Noto Sans</family></prefer></alias>
  <alias><family>San Francisco</family><prefer><family>$interface</family><family>Noto Sans</family></prefer></alias>
  <alias><family>SF Mono</family><prefer><family>$mono</family><family>Noto Sans Mono</family></prefer></alias>
  <alias><family>sans-serif</family><prefer><family>$text</family><family>Noto Sans</family><family>Noto Sans CJK JP</family><family>Noto Color Emoji</family></prefer></alias>
  <alias><family>system-ui</family><prefer><family>$interface</family><family>Noto Sans</family><family>Noto Color Emoji</family></prefer></alias>
  <alias><family>ui-sans-serif</family><prefer><family>$text</family><family>Noto Sans</family><family>Noto Color Emoji</family></prefer></alias>
  <alias><family>monospace</family><prefer><family>$mono</family><family>Noto Sans Mono</family></prefer></alias>
  <alias><family>JetBrains Mono</family><prefer><family>$mono</family></prefer></alias>
  <alias><family>SevenOS UI</family><prefer><family>$interface</family><family>Noto Sans</family></prefer></alias>
  <alias><family>SevenOS Text</family><prefer><family>$text</family><family>Noto Sans</family></prefer></alias>
  <alias><family>SevenOS Display</family><prefer><family>$interface</family><family>Noto Sans</family></prefer></alias>
  <alias><family>SevenOS Mono</family><prefer><family>$mono</family><family>Noto Sans Mono</family></prefer></alias>
  <alias><family>SevenOS Cyber</family><prefer><family>$cyber</family><family>Noto Sans Mono</family></prefer></alias>
  <alias><family>SevenOS Brand</family><prefer><family>$brand</family><family>Noto Sans</family></prefer></alias>
</fontconfig>
EOF
}

refresh_cache() {
  if is_dry_run; then
    printf 'fc-cache -f %q %q\n' "$FONT_HOME" "$FONT_CONFIG_DIR"
    return 0
  fi
  command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$DATA_HOME/fonts" "$FONT_CONFIG_DIR" >/dev/null 2>&1 || true
}

apply_gsettings() {
  local interface="Inter"
  local text="Inter"
  local mono="JetBrainsMono Nerd Font"

  if [[ -f "$FONT_PREFS" ]]; then
    # shellcheck disable=SC1090
    source "$FONT_PREFS"
  fi

  if is_dry_run; then
    printf 'gsettings set interface/document/monospace font roles\n'
    return 0
  fi
  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings set org.gnome.desktop.interface font-name "$interface 10" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface document-font-name "$text 10" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface monospace-font-name "$mono 10" >/dev/null 2>&1 || true
}

status_json() {
  local interface text mono cyber brand sf_display sf_text sf_mono
  interface="$(family_match "SF Pro Display")"
  text="$(family_match "SF Pro Text")"
  mono="$(family_match "SF Mono")"
  cyber="$(family_match "JetBrainsMono Nerd Font")"
  brand="$(family_match "SevenOS Brand")"
  sf_display="$(family_match "SevenOS Display")"
  sf_text="$(family_match "SevenOS Text")"
  sf_mono="$(family_match "SevenOS Mono")"
  printf '{"schema":"sevenos.fonts.v1","interface":"%s","text":"%s","mono":"%s","cyber":"%s","brand":"%s","sevenos_display":"%s","sevenos_text":"%s","sevenos_mono":"%s","font_home":"%s"}\n' \
    "$interface" "$text" "$mono" "$cyber" "$brand" "$sf_display" "$sf_text" "$sf_mono" "$FONT_HOME"
}

status_human() {
  printf 'SevenOS Fonts\n'
  printf '=============\n'
  printf 'Interface: %s\n' "$(family_match "SF Pro Display")"
  printf 'Text:      %s\n' "$(family_match "SF Pro Text")"
  printf 'Terminal:  %s\n' "$(family_match "SF Mono")"
  printf 'Cyber:     %s\n' "$(family_match "JetBrainsMono Nerd Font")"
  printf 'Brand:     %s\n' "$(family_match "SevenOS Brand")"
  printf 'Core UI:   %s\n' "$(family_match "SevenOS UI")"
  printf 'Folder:    %s\n' "$FONT_HOME"
}

apply_default() {
  install_local_sources
  refresh_cache
  ensure_core_prefs
  write_fontconfig
  refresh_cache
  apply_gsettings

  if [[ "$CONFIG_HOME" != "$HOST_CONFIG_HOME" || "$DATA_HOME" != "$HOST_DATA_HOME" ]]; then
    log_info "Also applying font roles to host user config outside the active profile sandbox."
    with_font_targets "$HOST_CONFIG_HOME" "$HOST_DATA_HOME" "$ROOT_DIR/scripts/fonts.sh" apply-default-host
  fi

  log_success "SevenOS font roles applied."
}

case "${1:-status}" in
  status)
    if [[ "${2:-}" == "--json" ]]; then
      status_json
    else
      status_human
    fi
    ;;
  apply|apply-default)
    apply_default
    ;;
  apply-default-host)
    install_local_sources
    refresh_cache
    ensure_core_prefs
    write_fontconfig
    refresh_cache
    apply_gsettings
    ;;
  refresh)
    refresh_cache
    log_success "Font cache refreshed."
    ;;
  import)
    shift
    if [[ "$#" -eq 0 ]]; then
      log_error "Usage: seven fonts import <font-file-or-folder> [...]"
      exit 1
    fi
    for source in "$@"; do
      copy_fonts_from "$source"
    done
    refresh_cache
    log_success "Fonts imported."
    ;;
  open)
    mkdir -p "$FONT_HOME/Imported"
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$FONT_HOME" >/dev/null 2>&1 &
    else
      printf '%s\n' "$FONT_HOME"
    fi
    ;;
  prefs)
    mkdir -p "$(dirname -- "$FONT_PREFS")"
    [[ -f "$FONT_PREFS" ]] || default_prefs > "$FONT_PREFS"
    ${EDITOR:-nano} "$FONT_PREFS"
    ;;
  *)
    cat <<'EOF'
SevenOS Fonts

Usage:
  seven fonts status [--json]
  seven fonts apply-default
  seven fonts import <font-file-or-folder> [...]
  seven fonts refresh
  seven fonts open
  seven fonts prefs
EOF
    exit 1
    ;;
esac
