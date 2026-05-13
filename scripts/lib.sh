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
    printf 'sudo pacman -S --needed %s\n' "${packages[*]}"
    return 0
  fi

  sudo pacman -S --needed "${packages[@]}"
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
    printf 'cp -r %q/. %q/\n' "$source_dir" "$target_dir"
    return 0
  fi

  mkdir -p "$target_dir"
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
    printf 'cp %q %q\n' "$source_file" "$target_file"
    return 0
  fi

  mkdir -p "$target_dir"
  cp "$source_file" "$target_file"
}
