#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

copy_system_file() {
  local source_file="$1"
  local target_file="$2"
  local target_dir

  target_dir="$(dirname -- "$target_file")"
  log_info "Installing system branding: ${source_file#$ROOT_DIR/} -> $target_file"

  if is_dry_run; then
    printf '%q mkdir -p %q\n' "$(privileged_backend_label)" "$target_dir"
    if [[ -e "$target_file" ]]; then
      printf '%q cp -a %q %q\n' "$(privileged_backend_label)" "$target_file" "$(backup_path "$target_file")"
    fi
    printf '%q cp %q %q\n' "$(privileged_backend_label)" "$source_file" "$target_file"
    return 0
  fi

  run_privileged_cmd mkdir -p "$target_dir"
  if [[ -e "$target_file" ]]; then
    local backup_file
    backup_file="$(backup_path "$target_file")"
    run_privileged_cmd cp -a "$target_file" "$backup_file"
    log_warn "Existing system file backed up to $backup_file"
  fi
  run_privileged_cmd cp "$source_file" "$target_file"
}

log_info "Applying SevenOS system branding..."

copy_system_file "$ROOT_DIR/branding/sevenos-release" "/etc/sevenos-release"
copy_system_file "$ROOT_DIR/branding/issue" "/etc/issue"
copy_system_file "$ROOT_DIR/branding/motd" "/etc/motd"

log_warn "Not replacing /etc/os-release on host systems. The ISO uses SevenOS os-release directly."

copy_config_dir "$ROOT_DIR/branding/fastfetch" "$CONFIG_HOME/fastfetch"

log_success "SevenOS branding applied."
