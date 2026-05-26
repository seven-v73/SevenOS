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

package_alternatives() {
  case "$1" in
    code) printf '%s\n' visual-studio-code-bin vscodium-bin vscodium ;;
    p7zip) printf '%s\n' 7zip ;;
    7zip) printf '%s\n' p7zip ;;
  esac
}

package_is_satisfied() {
  local package="$1"
  local alternative

  if [[ "$package" == "glaze" &&
        -f "$HOME/.local/lib/sevenos/glaze/include/glaze/glaze.hpp" &&
        -f "$HOME/.local/lib/sevenos/glaze/lib/pkgconfig/glaze.pc" ]]; then
    return 0
  fi

  pacman -Qq "$package" >/dev/null 2>&1 && return 0
  while IFS= read -r alternative; do
    [[ -n "$alternative" ]] || continue
    pacman -Qq "$alternative" >/dev/null 2>&1 && return 0
  done < <(package_alternatives "$package")

  return 1
}

package_in_repo() {
  local package="$1"
  local alternative

  pacman -Si "$package" >/dev/null 2>&1 && return 0
  while IFS= read -r alternative; do
    [[ -n "$alternative" ]] || continue
    pacman -Si "$alternative" >/dev/null 2>&1 && return 0
  done < <(package_alternatives "$package")

  return 1
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

privileged_backend() {
  if [[ -n "${SEVENOS_AUTH_BACKEND:-}" ]]; then
    command -v "$SEVENOS_AUTH_BACKEND" >/dev/null 2>&1 && printf '%s' "$SEVENOS_AUTH_BACKEND"
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    printf 'sudo'
  elif command -v pkexec >/dev/null 2>&1 && polkit_agent_running; then
    printf 'pkexec'
  else
    printf ''
  fi
}

polkit_agent_running() {
  pgrep -u "${UID:-$(id -u)}" -f 'polkit.*agent|polkit-kde-authentication-agent|lxqt-policykit-agent|mate-polkit|xfce-polkit|polkit-gnome-authentication-agent' >/dev/null 2>&1
}

privileged_backend_label() {
  local backend
  backend="$(privileged_backend)"
  printf '%s' "${backend:-sudo}"
}

run_privileged_cmd() {
  local backend
  backend="$(privileged_backend)"
  if [[ -z "$backend" ]]; then
    log_error "No graphical admin prompt or sudo backend is available."
    return 1
  fi

  if is_dry_run; then
    printf '%q ' "$backend" "$@"
    printf '\n'
    return 0
  fi

  "$backend" "$@"
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
  run_privileged_cmd systemctl enable --now "$service"
}

add_user_to_group() {
  local group="$1"
  local user="${2:-$USER}"

  if is_dry_run; then
    printf '%q usermod -aG %q %q\n' "$(privileged_backend_label)" "$group" "$user"
    return 0
  fi

  if getent group "$group" >/dev/null 2>&1; then
    if ! groups "$user" | grep -qw "$group"; then
      run_privileged_cmd usermod -aG "$group" "$user"
      log_warn "Log out and back in for the '$group' group membership to apply."
    fi
  else
    log_warn "Group not found, skipping membership update: $group"
  fi
}

install_package_file() {
  local package_file="$1"
  local packages=()
  local installable_packages=()
  local missing_repo_packages=()
  local package

  if [[ ! -f "$package_file" ]]; then
    log_error "Package file not found: $package_file"
    exit 1
  fi

  mapfile -t packages < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$package_file")

  if command -v pacman >/dev/null 2>&1; then
    for package in "${packages[@]}"; do
      if package_is_satisfied "$package"; then
        continue
      fi
      if ! package_in_repo "$package"; then
        missing_repo_packages+=("$package")
        continue
      fi
      installable_packages+=("$package")
    done
    packages=("${installable_packages[@]}")
  fi

  if [[ "${#missing_repo_packages[@]}" -gt 0 ]]; then
    log_error "Some packages are not available in the enabled pacman repositories:"
    printf '  - %s\n' "${missing_repo_packages[@]}" >&2
    log_info "Run: sudo pacman -Syu"
    log_info "Then retry the SevenOS install. If these are AUR packages, install the AUR helper route first."
    return 1
  fi

  if [[ "${#packages[@]}" -eq 0 ]]; then
    log_success "Package requirements already satisfied for ${package_file#${SEVENOS_ROOT:-}/}"
    return 0
  fi

  log_info "Installing packages from ${package_file#${SEVENOS_ROOT:-}/}"

  if is_dry_run; then
    if assume_yes; then
      printf '%q pacman -S --needed --noconfirm %s\n' "$(privileged_backend_label)" "${packages[*]}"
    else
      printf '%q pacman -S --needed %s\n' "$(privileged_backend_label)" "${packages[*]}"
    fi
    return 0
  fi

  if assume_yes; then
    run_privileged_cmd pacman -S --needed --noconfirm "${packages[@]}" || {
      log_error "Package installation failed for ${package_file#${SEVENOS_ROOT:-}/}."
      log_info "Common causes: stale mirrors, pacman database lock, broken keyring, or an interrupted previous update."
      log_info "Repair path: sudo pacman -Syu archlinux-keyring && sudo pacman -Syu"
      return 1
    }
  else
    run_privileged_cmd pacman -S --needed "${packages[@]}" || {
      log_error "Package installation failed for ${package_file#${SEVENOS_ROOT:-}/}."
      log_info "Common causes: stale mirrors, pacman database lock, broken keyring, or an interrupted previous update."
      log_info "Repair path: sudo pacman -Syu archlinux-keyring && sudo pacman -Syu"
      return 1
    }
  fi
}

install_aur_package_file() {
  local package_file="$1"
  local helper=""
  local packages=()
  local installable_packages=()
  local package

  if [[ ! -f "$package_file" ]]; then
    log_error "AUR package file not found: $package_file"
    exit 1
  fi

  if command -v paru >/dev/null 2>&1; then
    helper="paru"
  elif command -v yay >/dev/null 2>&1; then
    helper="yay"
  fi

  if [[ -z "$helper" ]]; then
    log_warn "AUR helper missing; skipping ${package_file#${SEVENOS_ROOT:-}/}. Run: ./install.sh aur-helpers --yes"
    return 0
  fi

  mapfile -t packages < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$package_file")

  for package in "${packages[@]}"; do
    if package_is_satisfied "$package"; then
      continue
    fi
    installable_packages+=("$package")
  done

  if [[ "${#installable_packages[@]}" -eq 0 ]]; then
    log_success "AUR package requirements already satisfied for ${package_file#${SEVENOS_ROOT:-}/}"
    return 0
  fi

  log_info "Installing AUR packages from ${package_file#${SEVENOS_ROOT:-}/} with $helper"

  if is_dry_run; then
    if assume_yes; then
      printf '%s -S --needed --noconfirm %s\n' "$helper" "${installable_packages[*]}"
    else
      printf '%s -S --needed %s\n' "$helper" "${installable_packages[*]}"
    fi
    return 0
  fi

  if assume_yes; then
    "$helper" -S --needed --noconfirm "${installable_packages[@]}"
  else
    "$helper" -S --needed "${installable_packages[@]}"
  fi
}

copy_config_dir() {
  local source_dir="$1"
  local target_dir="$2"

  if [[ ! -d "$source_dir" ]]; then
    log_error "Config source not found: $source_dir"
    exit 1
  fi

  log_info "Copying config: ${source_dir#${SEVENOS_ROOT:-}/} -> $target_dir"

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
  log_info "Copying config: ${source_file#${SEVENOS_ROOT:-}/} -> $target_file"

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
