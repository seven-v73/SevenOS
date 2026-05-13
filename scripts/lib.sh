#!/usr/bin/env bash

log_info() {
  printf '[SevenOS] %s\n' "$*"
}

log_success() {
  printf '[SevenOS] OK: %s\n' "$*"
}

log_warn() {
  printf '[SevenOS] WARN: %s\n' "$*" >&2
}

log_error() {
  printf '[SevenOS] ERROR: %s\n' "$*" >&2
}

is_dry_run() {
  [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]
}

assume_yes() {
  [[ "${SEVENOS_YES:-0}" == "1" ]]
}

backup_path() {
  local path="$1"
  printf '%s.sevenos.bak.%s' "$path" "$(date +%Y%m%d-%H%M%S)"
}

run_cmd() {
  if is_dry_run; then
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    log_error "Required command not found: $command_name"
    exit 1
  fi
}

require_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    log_error "SevenOS Phase 1 expects Arch Linux or an Arch-based system."
    exit 1
  fi
}

enable_service() {
  local service="$1"
  log_info "Enabling service: $service"
  run_cmd sudo systemctl enable --now "$service"
}

add_user_to_group() {
  local group="$1"
  local user="${2:-$USER}"

  if is_dry_run; then
    printf 'sudo usermod -aG %q %q\n' "$group" "$user"
    return 0
  fi

  if getent group "$group" >/dev/null 2>&1; then
    if ! groups "$user" | grep -qw "$group"; then
      sudo usermod -aG "$group" "$user"
      log_warn "Log out and back in for the '$group' group membership to apply."
    fi
  else
    log_warn "Group not found, skipping membership update: $group"
  fi
}

install_package_file() {
  local package_file="$1"

  if [[ ! -f "$package_file" ]]; then
    log_error "Package file not found: $package_file"
    exit 1
  fi

  mapfile -t packages < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$package_file")

  if [[ "${#packages[@]}" -eq 0 ]]; then
    log_warn "No packages listed in $package_file"
    return 0
  fi

  log_info "Installing packages from ${package_file#$SEVENOS_ROOT/}"

  if is_dry_run; then
    if assume_yes; then
      printf 'sudo pacman -S --needed --noconfirm %s\n' "${packages[*]}"
    else
      printf 'sudo pacman -S --needed %s\n' "${packages[*]}"
    fi
    return 0
  fi

  if assume_yes; then
    sudo pacman -S --needed --noconfirm "${packages[@]}"
  else
    sudo pacman -S --needed "${packages[@]}"
  fi
}

copy_config_dir() {
  local source_dir="$1"
  local target_dir="$2"

  if [[ ! -d "$source_dir" ]]; then
    log_error "Config source not found: $source_dir"
    exit 1
  fi

  log_info "Copying config: ${source_dir#$SEVENOS_ROOT/} -> $target_dir"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$target_dir"
    if [[ -e "$target_dir" ]]; then
      printf 'cp -a %q %q\n' "$target_dir" "$(backup_path "$target_dir")"
    fi
    printf 'cp -r %q/. %q/\n' "$source_dir" "$target_dir"
    return 0
  fi

  mkdir -p "$target_dir"
  if [[ -e "$target_dir" ]]; then
    local backup_dir
    backup_dir="$(backup_path "$target_dir")"
    cp -a "$target_dir" "$backup_dir"
    log_warn "Existing config backed up to $backup_dir"
  fi
  cp -r "$source_dir"/. "$target_dir"/
}

copy_config_file() {
  local source_file="$1"
  local target_file="$2"
  local target_dir

  if [[ ! -f "$source_file" ]]; then
    log_error "Config source not found: $source_file"
    exit 1
  fi

  target_dir="$(dirname -- "$target_file")"
  log_info "Copying config: ${source_file#$SEVENOS_ROOT/} -> $target_file"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$target_dir"
    if [[ -e "$target_file" ]]; then
      printf 'cp -a %q %q\n' "$target_file" "$(backup_path "$target_file")"
    fi
    printf 'cp %q %q\n' "$source_file" "$target_file"
    return 0
  fi

  mkdir -p "$target_dir"
  if [[ -e "$target_file" ]]; then
    local backup_file
    backup_file="$(backup_path "$target_file")"
    cp -a "$target_file" "$backup_file"
    log_warn "Existing config backed up to $backup_file"
  fi
  cp "$source_file" "$target_file"
}

install_flatpak_app() {
  local remote="$1"
  local app_id="$2"

  if ! is_dry_run; then
    require_command flatpak
  fi

  log_info "Installing Flatpak app: $app_id"
  run_cmd flatpak install -y "$remote" "$app_id"
}
