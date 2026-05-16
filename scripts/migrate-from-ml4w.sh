#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_ROOT="${SEVENOS_MIGRATION_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sevenos/migrations}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS ML4W migration

Usage:
  seven migrate-ml4w plan
  seven migrate-ml4w backup
  seven migrate-ml4w remove
  seven migrate-ml4w switch

Commands:
  plan     Show ML4W/Hyprland paths that may conflict with SevenOS.
  backup   Copy detected paths into a timestamped migration backup.
  remove   Move detected ML4W paths out of the active config tree.
  switch   Backup, remove ML4W paths, apply SevenOS theme and restart session.

Nothing is permanently deleted. "remove" quarantines active ML4W paths under:
  ~/.local/share/sevenos/migrations/ml4w-<timestamp>/
EOF
}

stamp() {
  date +%Y%m%d-%H%M%S
}

candidate_paths() {
  cat <<EOF
$CONFIG_HOME/ml4w
$DATA_HOME/ml4w
$CACHE_HOME/ml4w
$HOME/.ml4w
$CONFIG_HOME/hypr
$CONFIG_HOME/waybar
$CONFIG_HOME/rofi
$CONFIG_HOME/kitty
$CONFIG_HOME/mako
$CONFIG_HOME/gtk-3.0
$CONFIG_HOME/gtk-4.0
$CONFIG_HOME/qt5ct
$CONFIG_HOME/qt6ct
$CONFIG_HOME/Kvantum
$CONFIG_HOME/wlogout
$CONFIG_HOME/swaync
$CONFIG_HOME/fastfetch
$CONFIG_HOME/dunst
$CONFIG_HOME/eww
$CONFIG_HOME/ags
$CONFIG_HOME/autostart/ml4w-welcome.desktop
$CONFIG_HOME/autostart/ml4w-dotfiles.desktop
$CONFIG_HOME/systemd/user/ml4w.service
$CONFIG_HOME/systemd/user/ml4w*.service
EOF
}

has_marker() {
  local path="$1"
  [[ -e "$path" ]] || return 1

  case "$(basename -- "$path")" in
    ml4w|.ml4w|ml4w-welcome.desktop|ml4w-dotfiles.desktop|ml4w.service)
      return 0
      ;;
  esac

  if [[ -d "$path" ]]; then
    if find "$path" -maxdepth 3 -type f 2>/dev/null | head -200 | xargs -r grep -IiqE 'ml4w|mylinuxforwork'; then
      return 0
    fi
  elif grep -IiqE 'ml4w|mylinuxforwork' "$path" 2>/dev/null; then
    return 0
  fi

  return 1
}

detected_paths() {
  local raw path
  while IFS= read -r raw; do
    [[ -n "$raw" ]] || continue
    for path in $raw; do
      [[ -e "$path" ]] || continue
      if has_marker "$path"; then
        printf '%s\n' "$path"
      fi
    done
  done < <(candidate_paths)
}

relative_path() {
  local path="$1"
  path="${path#"$HOME"/}"
  path="${path#/}"
  printf '%s\n' "$path"
}

backup_detected() {
  local backup_dir="${1:-$BACKUP_ROOT/ml4w-$(stamp)}"
  local count=0 path target

  log_info "Backing up ML4W-related paths to: $backup_dir"
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$backup_dir"
  else
    mkdir -p "$backup_dir"
  fi

  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    target="$backup_dir/$(relative_path "$path")"
    if is_dry_run; then
      printf 'mkdir -p %q\n' "$(dirname -- "$target")"
      printf 'cp -a %q %q\n' "$path" "$target"
    else
      mkdir -p "$(dirname -- "$target")"
      cp -a "$path" "$target"
    fi
    count=$((count + 1))
  done < <(detected_paths | sort -u)

  if [[ "$count" -eq 0 ]]; then
    log_warn "No active ML4W markers detected."
  else
    log_success "ML4W paths backed up: $count"
  fi
}

plan() {
  printf 'SevenOS ML4W migration plan\n'
  printf 'Backup root: %s\n\n' "$BACKUP_ROOT"
  local count=0 path
  while IFS= read -r path; do
    printf '[ml4w] %s\n' "$path"
    count=$((count + 1))
  done < <(detected_paths | sort -u)
  if [[ "$count" -eq 0 ]]; then
    printf '[ok] No ML4W-marked active config paths detected.\n'
  fi
}

remove_detected() {
  local quarantine_dir="${1:-$BACKUP_ROOT/ml4w-$(stamp)}"
  local count=0 path target

  backup_detected "$quarantine_dir"
  log_info "Moving ML4W paths out of the active config tree..."

  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    target="$quarantine_dir/active/$(relative_path "$path")"
    if is_dry_run; then
      printf 'mkdir -p %q\n' "$(dirname -- "$target")"
      printf 'mv %q %q\n' "$path" "$target"
    else
      mkdir -p "$(dirname -- "$target")"
      mv "$path" "$target"
    fi
    count=$((count + 1))
  done < <(detected_paths | sort -u)

  if [[ "$count" -eq 0 ]]; then
    log_warn "No ML4W paths moved."
  else
    log_success "ML4W paths quarantined: $count"
  fi
}

switch_to_sevenos() {
  local quarantine_dir="$BACKUP_ROOT/ml4w-$(stamp)"
  remove_detected "$quarantine_dir"
  log_info "Applying SevenOS desktop layer..."
  "$ROOT_DIR/install.sh" theme
  log_info "Restarting SevenOS session services..."
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user restart sevenos-session.target >/dev/null 2>&1 || true
  fi
  "$ROOT_DIR/bin/seven-session" >/tmp/sevenos-session.log 2>&1 || true
  log_success "SevenOS is now the active Hyprland desktop layer."
  log_info "Log out and choose the SevenOS session if your display manager still starts another session."
  log_info "Quarantine backup: $quarantine_dir"
}

command="${1:-plan}"
case "$command" in
  plan) plan ;;
  backup) backup_detected ;;
  remove) remove_detected ;;
  switch) switch_to_sevenos ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
