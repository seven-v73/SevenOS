#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

log_info "Installing SevenOS WINDOWS compatibility layer..."
install_package_file "$ROOT_DIR/scripts/packages-windows.txt"
install_aur_package_file "$ROOT_DIR/scripts/packages-windows-aur.txt" || log_warn "Windows Bridge AUR helpers were skipped."

log_info "Configuring virtualization services..."
enable_service libvirtd.service || log_warn "libvirtd could not be enabled."
add_user_to_group libvirt "$USER"

if command -v flatpak >/dev/null 2>&1 || is_dry_run; then
  log_info "Configuring Flathub for Bottles..."
  run_cmd flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  install_flatpak_app flathub com.usebottles.bottles || log_warn "Bottles Flatpak install failed."
else
  log_warn "Flatpak is not available yet. Re-run './install.sh windows' after package installation to install Bottles."
fi

log_warn "GPU passthrough is not automated in Phase 1. See vm/README.md for the planned path."
log_warn "If libvirt group membership changed, log out and back in before using Windows Mode."
log_info "Next checks: ./install.sh post-install && seven windows status && seven windows provision"
log_success "WINDOWS compatibility layer installed."
