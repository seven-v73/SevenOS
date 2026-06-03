#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

PROFILE_SOURCE="$ROOT_DIR/archiso/profile"
BUILD_ROOT="$ROOT_DIR/out/archiso"
PROFILE_BUILD="$BUILD_ROOT/profile"
WORK_DIR="$BUILD_ROOT/work"
OUT_DIR="$ROOT_DIR/out/iso"
LOCAL_REPO_SOURCE="${SEVENOS_LOCAL_REPO:-$ROOT_DIR/archiso/localrepo/x86_64}"
LOCAL_REPO_BUILD="$PROFILE_BUILD/localrepo/x86_64"

usage() {
  cat <<'EOF'
SevenOS ISO builder

Usage:
  ./scripts/build-iso.sh [--dry-run]

Options:
  --dry-run    Show actions without creating build directories or running mkarchiso
  -h, --help   Show this help
EOF
}

profile_has() {
  local path="$1"
  local pattern="$2"
  [[ -s "$PROFILE_SOURCE/$path" ]] && grep -Fq -- "$pattern" "$PROFILE_SOURCE/$path"
}

preflight_graphical_profile() {
  local failures=0

  check_profile() {
    local label="$1"
    local path="$2"
    local pattern="$3"
    if profile_has "$path" "$pattern"; then
      return 0
    fi
    log_error "SevenOS ISO graphical preflight failed: $label"
    log_info "Missing pattern in $path: $pattern"
    failures=$((failures + 1))
  }

  reject_profile() {
    local label="$1"
    local path="$2"
    local pattern="$3"
    if [[ -s "$PROFILE_SOURCE/$path" ]] && grep -Eq -- "$pattern" "$PROFILE_SOURCE/$path"; then
      log_error "SevenOS ISO graphical preflight failed: $label"
      log_info "Rejected pattern in $path: $pattern"
      failures=$((failures + 1))
    fi
  }

  reject_repo() {
    local label="$1"
    local path="$2"
    local pattern="$3"
    if [[ -s "$ROOT_DIR/$path" ]] && grep -Eq -- "$pattern" "$ROOT_DIR/$path"; then
      log_error "SevenOS ISO graphical preflight failed: $label"
      log_info "Rejected pattern in $path: $pattern"
      failures=$((failures + 1))
    fi
  }

  check_repo() {
    local label="$1"
    local path="$2"
    local pattern="$3"
    if [[ -s "$ROOT_DIR/$path" ]] && grep -Fq -- "$pattern" "$ROOT_DIR/$path"; then
      return 0
    fi
    log_error "SevenOS ISO graphical preflight failed: $label"
    log_info "Missing pattern in $path: $pattern"
    failures=$((failures + 1))
  }

  check_profile "UEFI boot must be quiet and branded" \
    "efiboot/loader/entries/01-sevenos-live.conf" "quiet splash"
  check_profile "UEFI boot must provide a readable GRUB route" \
    "profiledef.sh" "uefi.grub"
  check_profile "UEFI GRUB must expose SevenOS Live" \
    "grub/grub.cfg" "SevenOS Live"
  check_profile "UEFI GRUB must expose Safe Graphics" \
    "grub/grub.cfg" "Safe Graphics"
  check_profile "UEFI GRUB must keep the menu visible long enough" \
    "grub/grub.cfg" "set timeout=20"
  check_profile "UEFI GRUB must force readable menu colors" \
    "grub/grub.cfg" "set menu_color_normal=white/black"
  check_profile "UEFI GRUB must highlight the active entry visibly" \
    "grub/grub.cfg" "set menu_color_highlight=black/white"
  check_profile "UEFI GRUB loopback must expose SevenOS Live" \
    "grub/loopback.cfg" "SevenOS Live"
  check_profile "UEFI GRUB loopback must force readable menu colors" \
    "grub/loopback.cfg" "set menu_color_normal=white/black"
  check_profile "UEFI boot must hide systemd status text" \
    "efiboot/loader/entries/01-sevenos-live.conf" "systemd.show_status=false"
  check_profile "UEFI boot must suppress noisy kernel errors in the normal route" \
    "efiboot/loader/entries/01-sevenos-live.conf" "loglevel=0"
  check_profile "UEFI boot must not wait for systemd gpt-auto-root" \
    "efiboot/loader/entries/01-sevenos-live.conf" "systemd.gpt_auto=0"
  check_profile "BIOS boot must be quiet and branded" \
    "syslinux/archiso_sys-linux.cfg" "quiet splash"
  check_profile "BIOS boot menu must use the reliable text menu" \
    "syslinux/archiso_head.cfg" "UI menu.c32"
  check_profile "BIOS boot menu must expose a readable public title" \
    "syslinux/archiso_head.cfg" "SevenOS Boot Menu"
  check_profile "BIOS boot menu must render selected entries with high contrast" \
    "syslinux/archiso_head.cfg" "MENU COLOR sel"
  reject_profile "BIOS boot menu must not use fragile graphical vesamenu backgrounds" \
    "syslinux/archiso_head.cfg" 'UI[[:space:]]+vesamenu\\.c32|MENU BACKGROUND'
  reject_profile "BIOS boot menu must not skip user choice immediately" \
    "syslinux/archiso_head.cfg" '^MENU[[:space:]]+IMMEDIATE'
  check_profile "BIOS boot must suppress noisy kernel errors in the normal route" \
    "syslinux/archiso_sys-linux.cfg" "loglevel=0"
  check_profile "BIOS boot must not wait for systemd gpt-auto-root" \
    "syslinux/archiso_sys-linux.cfg" "systemd.gpt_auto=0"
  check_profile "SevenOS live service must start the graphical session directly" \
    "airootfs/etc/systemd/system/sevenos-live-session.service" "ExecStart=/usr/local/bin/sevenos-live-session"
  check_profile "SevenOS live session must use the live Hyprland fallback profile" \
    "airootfs/usr/local/bin/sevenos-live-session" "live-hyprland.conf"
  check_profile "SevenOS live session must start the branded graphical desktop first" \
    "airootfs/usr/local/bin/sevenos-live-session" "starting SevenOS graphical live desktop"
  reject_profile "SevenOS live session must not use the old fragile installer kiosk" \
    "airootfs/usr/local/bin/sevenos-live-session" "cage -s -- seven-installer open"
  check_profile "SevenOS live profile must relaunch the installer if no window appears" \
    "airootfs/usr/local/bin/sevenos-live-guard" "open_rescue_terminal"
  check_profile "SevenOS live service must run as the live user" \
    "airootfs/etc/systemd/system/sevenos-live-session.service" "User=seven"
  check_profile "SevenOS live service must own tty1 strongly enough to replace boot text" \
    "airootfs/etc/systemd/system/sevenos-live-session.service" "StandardInput=tty-force"
  check_profile "SevenOS live service must keep logs in the journal instead of the console" \
    "airootfs/etc/systemd/system/sevenos-live-session.service" "StandardOutput=journal"
  check_profile "Live build must enable the SevenOS live service" \
    "airootfs/root/customize_airootfs.sh" "sevenos-live-session.service"
  check_profile "Live build must generate SevenOS locales before the graphical session" \
    "airootfs/root/customize_airootfs.sh" "locale-gen"
  check_profile "UEFI boot must expose Safe Graphics" \
    "efiboot/loader/entries/03-sevenos-live-safe.conf" "Safe Graphics"
  check_profile "BIOS boot must expose Safe Graphics" \
    "syslinux/archiso_sys-linux.cfg" "Safe ^Graphics"
  check_profile "Wayland session file must stay available for installed display managers" \
    "airootfs/usr/share/wayland-sessions/sevenos-live.desktop" "sevenos-live-session"
  check_profile "Live session must open Calamares directly for a stable install path" \
    "airootfs/usr/local/bin/sevenos-live-ready" "Opening Calamares directly for a stable graphical installation"
  check_profile "Live session must keep a SevenOS portal fallback if Calamares exits early" \
    "airootfs/usr/local/bin/sevenos-live-ready" "Calamares did not stabilize; trying the SevenOS portal fallback"
  check_profile "Live session must offer a network choice before installation when offline" \
    "airootfs/usr/local/bin/sevenos-live-ready" "Network is not connected; opening SevenOS network choice before installation."
  check_profile "Live session must keep the portal open when Wi-Fi is not connected" \
    "airootfs/usr/local/bin/sevenos-live-ready" "Opening SevenOS installer portal so Wi-Fi, offline install, disks and logs stay available."
  check_profile "Live readiness must confirm real installer windows, not only process ids" \
    "airootfs/usr/local/bin/sevenos-live-ready" "installer_window_visible"
  check_repo "Live installer launcher must focus an existing installer instead of duplicating windows" \
    "bin/seven-installer" "focus_installer_window"
  check_repo "Live installer launcher must lock Calamares startup against duplicate windows" \
    "bin/seven-installer" "calamares-open.lock"
  check_repo "Live installer portal must be singleton to avoid duplicate setup windows" \
    "bin/seven-installer" "installer-portal-open.lock"
  check_repo "Live installer portal must allow an explicit offline install choice" \
    "bin/seven-installer" "Installer hors ligne"
  check_repo "Live installer offline choice must persist for the session" \
    "bin/seven-installer" "live-offline-accepted"
  check_repo "Live installer must own the network action with fallbacks" \
    "bin/seven-installer" "network_command"
  check_repo "Live installer must expose readable installation logs" \
    "bin/seven-installer" "logs_command"
  check_repo "Live installer must own the disk inspection action with fallbacks" \
    "bin/seven-installer" "disks_command"
  check_profile "Live installer desktop entry must expose Wi-Fi as a direct action" \
    "airootfs/usr/share/applications/seven-installer.desktop" "Desktop Action Network"
  check_profile "Live installer desktop entry must expose disk inspection" \
    "airootfs/usr/share/applications/seven-installer.desktop" "Desktop Action Disks"
  check_profile "Live installer desktop entry must expose installation logs" \
    "airootfs/usr/share/applications/seven-installer.desktop" "Desktop Action Logs"
  check_repo "Live installer smoke test must verify the direct Calamares route" \
    "scripts/live-installer-smoke.sh" "Calamares installer is interactive"
  check_profile "Live guard must count installer windows explicitly without launching a duplicate installer" \
    "airootfs/usr/local/bin/sevenos-live-guard" "installer_window_count"
  check_profile "Live session must show a SevenOS background before installer windows appear" \
    "airootfs/etc/sevenos/live-hyprland.conf" "live-hyprpaper.conf"
  check_profile "Live wallpaper config must point to the branded live background" \
    "airootfs/etc/sevenos/live-hyprpaper.conf" "/usr/share/sevenos/live-background.png"
  check_profile "Live background asset must be tracked by the ISO profile" \
    "profiledef.sh" "/usr/share/sevenos/live-background.png"
  check_profile "Live build must install Calamares SevenOS settings" \
    "airootfs/root/customize_airootfs.sh" "/etc/calamares/settings.conf"
  check_profile "Live build must install Calamares unpackfs configuration" \
    "airootfs/root/customize_airootfs.sh" "/etc/calamares/modules/unpackfs.conf"
  check_profile "Live build must install Calamares live cleanup configuration" \
    "airootfs/root/customize_airootfs.sh" "/etc/calamares/modules/shellprocess-livecleanup.conf"
  check_profile "Live build must install the safe Calamares live cleanup helper" \
    "airootfs/root/customize_airootfs.sh" "seven-calamares-livecleanup"
  check_profile "Live build must install Calamares user password policy" \
    "airootfs/root/customize_airootfs.sh" "/etc/calamares/modules/users.conf"
  check_profile "Live build must install Calamares SevenOS branding" \
    "airootfs/root/customize_airootfs.sh" "/usr/share/calamares/branding/sevenos"
  check_profile "Live Hyprland config must delegate window placement to the guard" \
    "airootfs/etc/sevenos/live-hyprland.conf" "Window placement is handled after launch by"
  check_profile "Live guard must arrange the installer window after launch" \
    "airootfs/usr/local/bin/sevenos-live-guard" "arrange_installer_window"
  check_profile "Live session must expose a Kitty rescue terminal shortcut" \
    "airootfs/etc/sevenos/live-hyprland.conf" "SevenOS Live Rescue"
  check_profile "Live guard must prefer the reliable Kitty rescue terminal" \
    "airootfs/usr/local/bin/sevenos-live-guard" "kitty --class SevenOSLiveRescue"
  reject_profile "Live Hyprland config must not use deprecated windowrulev2" \
    "airootfs/etc/sevenos/live-hyprland.conf" '(^|[[:space:]])windowrulev2[[:space:]]*='
  reject_profile "Live Hyprland config must not include window rules" \
    "airootfs/etc/sevenos/live-hyprland.conf" '^[[:space:]]*windowrule'
  reject_profile "Live Hyprland config must not include custom style keys" \
    "airootfs/etc/sevenos/live-hyprland.conf" '^[[:space:]]*style[[:space:]]*='
  reject_repo "Calamares live cleanup must not kill the live installer session" \
    "installer/calamares/modules/shellprocess-livecleanup.conf" 'pkill[[:space:]].*-u[[:space:]]+seven'
  reject_repo "Calamares display manager setup must be handled by SevenOS finalizer" \
    "installer/calamares/settings.conf" '^[[:space:]]*-[[:space:]]*displaymanager[[:space:]]*$'
  reject_repo "Calamares network setup must be handled by SevenOS finalizer" \
    "installer/calamares/settings.conf" '^[[:space:]]*-[[:space:]]*networkcfg[[:space:]]*$'

  check_repo "Calamares must use the standard shellprocess module" \
    "installer/calamares/settings.conf" "- shellprocess"
  check_repo "Calamares must copy the live rootfs explicitly" \
    "installer/calamares/settings.conf" "- unpackfs"
  check_repo "Calamares must clean the live user before creating the installed user" \
    "installer/calamares/settings.conf" "shellprocess@livecleanup"
  check_repo "Calamares unpackfs must use the mounted ArchISO rootfs" \
    "installer/calamares/modules/unpackfs.conf" "/run/archiso/airootfs"
  check_repo "Calamares unpackfs must not use the default CHANGES example" \
    "installer/calamares/modules/unpackfs.conf" "sourcefs: \"file\""
  check_repo "Calamares shellprocess must finalize SevenOS through the copied installed root" \
    "installer/calamares/modules/shellprocess.conf" "/bin/bash /opt/SevenOS/bin/seven-calamares-finalize"
  reject_repo "Calamares finalizer command must not expose shell variables to Calamares interpolation" \
    "installer/calamares/modules/shellprocess.conf" '\\$(log|hook|status)|\\$\\{(log|hook|status)\\}'
  check_repo "Calamares live cleanup must not kill running live-session processes" \
    "installer/calamares/modules/shellprocess-livecleanup.conf" "seven-calamares-livecleanup"
  check_repo "Calamares live cleanup must run through the copied installed root" \
    "installer/calamares/modules/shellprocess-livecleanup.conf" "/bin/bash /opt/SevenOS/bin/seven-calamares-livecleanup"
  reject_repo "Calamares live cleanup command must not expose shell variables to Calamares interpolation" \
    "installer/calamares/modules/shellprocess-livecleanup.conf" '\\$(log|hook|status)|\\$\\{(log|hook|status)\\}'
  check_repo "Calamares live cleanup helper must remove live metadata offline" \
    "bin/seven-calamares-livecleanup" "without touching running live processes"
  check_repo "Calamares live cleanup helper must skip safely when target files are not ready" \
    "bin/seven-calamares-livecleanup" "target passwd file is missing"
  check_repo "Calamares users must accept any non-empty password" \
    "installer/calamares/modules/users.conf" "minLength: 1"
  check_repo "Calamares users must allow weak passwords by default" \
    "installer/calamares/modules/users.conf" "allowWeakPasswordsDefault: true"
  check_repo "Calamares finalizer must write an install log" \
    "bin/seven-calamares-finalize" "/var/log/sevenos-install.log"
  check_repo "Calamares finalizer must remove live ISO services from installed systems" \
    "bin/seven-calamares-finalize" "Clean live ISO residue"
  check_repo "Calamares finalizer must configure NetworkManager safely" \
    "bin/seven-calamares-finalize" "Configure network stack"
  check_repo "Calamares finalizer must configure SevenOS display login safely" \
    "bin/seven-calamares-finalize" "Configure display stack"
  check_repo "Calamares finalizer must stay offline-first after unpackfs" \
    "bin/seven-calamares-finalize" "skipping network package installs during Calamares finalization"
  reject_repo "Calamares finalizer must not reinstall the base system over the network" \
    "bin/seven-calamares-finalize" 'install\\.sh"[[:space:]]+base|install\\.sh[[:space:]]+base'
  check_repo "Calamares branding must define the SevenOS product name" \
    "installer/calamares/branding/sevenos/branding.desc" "productName: SevenOS"
  check_repo "Calamares branding must define a sidebar contract" \
    "installer/calamares/branding/sevenos/branding.desc" "sidebar: widget"
  check_repo "Calamares branding must define a navigation contract" \
    "installer/calamares/branding/sevenos/branding.desc" "navigation: widget"
  check_repo "Calamares branding must define the SevenOS prism asset" \
    "installer/calamares/branding/sevenos/branding.desc" "productLogo: \"seven-prism.png\""
  check_repo "Calamares branding must define a slideshow entry" \
    "installer/calamares/branding/sevenos/branding.desc" "slideshow: \"show.qml\""
  check_repo "Calamares branding must define the slideshow API" \
    "installer/calamares/branding/sevenos/branding.desc" "slideshowAPI: 2"
  check_repo "Calamares slideshow must stay branded as SevenOS" \
    "installer/calamares/branding/sevenos/show.qml" "SevenOS"
  check_repo "The ISO package list must include the graphical installer" \
    "archiso/profile/packages.x86_64" "calamares"
  check_repo "The ISO package list must include GRUB for the Calamares bootloader module" \
    "archiso/profile/packages.x86_64" "grub"
  check_repo "The host ISO tooling manifest must install GRUB for UEFI GRUB images" \
    "scripts/packages-iso.txt" "grub"
  check_repo "The ISO package list must include live ISO initramfs hooks" \
    "archiso/profile/packages.x86_64" "mkinitcpio-archiso"
  check_repo "The live initramfs must use archiso hooks" \
    "archiso/profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf" "archiso_loop_mnt"
  check_repo "The ISO package list must include the display manager" \
    "archiso/profile/packages.x86_64" "sddm"
  check_repo "The ISO package list must include Hyprland" \
    "archiso/profile/packages.x86_64" "hyprland"
  check_repo "The ISO package list must include the live wallpaper renderer" \
    "archiso/profile/packages.x86_64" "hyprpaper"
  check_repo "The ISO package list must include a safe graphics fallback compositor" \
    "archiso/profile/packages.x86_64" "cage"
  check_repo "The ISO package list must include Qt Wayland support for Calamares" \
    "archiso/profile/packages.x86_64" "qt6-wayland"
  check_repo "The ISO package list must include XWayland as a Calamares fallback" \
    "archiso/profile/packages.x86_64" "xorg-xwayland"
  check_repo "The ISO package list must include xhost for root Calamares on XWayland" \
    "archiso/profile/packages.x86_64" "xorg-xhost"
  check_repo "The ISO package list must include a reliable rescue terminal" \
    "archiso/profile/packages.x86_64" "kitty"
  check_repo "The ISO package list must include Mesa for live graphics" \
    "archiso/profile/packages.x86_64" "mesa"

  if [[ "$failures" -gt 0 ]]; then
    log_error "SevenOS ISO graphical preflight found $failures issue(s)."
    exit 1
  fi
}

clean_path() {
  local path="$1"
  if is_dry_run; then
    run_cmd rm -rf "$path"
    return 0
  fi
  if [[ -e "$path" ]]; then
    run_cmd sudo rm -rf "$path"
  else
    run_cmd rm -rf "$path"
  fi
}

delete_old_isos() {
  if is_dry_run; then
    run_cmd find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -delete
    return 0
  fi
  run_cmd sudo find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -delete
}

restore_output_ownership() {
  is_dry_run && return 0
  local user_name group_name
  user_name="${SUDO_USER:-${USER:-}}"
  if [[ -z "$user_name" || "$user_name" == "root" ]]; then
    user_name="$(id -un)"
  fi
  group_name="$(id -gn "$user_name" 2>/dev/null || printf '%s' "$user_name")"
  if [[ -n "$user_name" && "$user_name" != "root" ]]; then
    run_cmd sudo chown -R "$user_name:$group_name" "$OUT_DIR"
  fi
}

verify_iso_boot_menu() {
  is_dry_run && return 0
  local iso_path listing cfg_path cfg_content
  iso_path="$(find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -print -quit)"
  if [[ -z "$iso_path" ]]; then
    log_error "No ISO artifact found for boot menu verification."
    return 1
  fi
  if ! command -v bsdtar >/dev/null 2>&1; then
    log_warn "bsdtar is missing; skipping embedded ISO boot menu verification."
    return 0
  fi

  listing="$(bsdtar -tf "$iso_path" 2>/dev/null || true)"
  if ! grep -Eq '(^|/)grub\.cfg$' <<<"$listing"; then
    log_error "Generated ISO does not expose an embedded GRUB configuration."
    log_info "Refusing to leave a bootable-looking USB image with an empty GRUB menu."
    return 1
  fi

  for cfg_path in boot/grub/grub.cfg EFI/BOOT/grub.cfg grub/grub.cfg; do
    cfg_content="$(bsdtar -xOf "$iso_path" "$cfg_path" 2>/dev/null || true)"
    if [[ -n "$cfg_content" ]]; then
      if grep -Fq "SevenOS Live" <<<"$cfg_content" &&
         grep -Fq "set menu_color_normal=white/black" <<<"$cfg_content"; then
        log_success "Verified embedded GRUB menu: $cfg_path"
        return 0
      fi
    fi
  done

  log_error "Generated ISO has GRUB files, but not the readable SevenOS GRUB menu."
  log_info "Expected: SevenOS Live entries and high-contrast menu colors."
  return 1
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

require_arch
require_command rsync
"$ROOT_DIR/scripts/system-assets.sh" doctor >/dev/null
"$ROOT_DIR/scripts/identity-assets.sh" doctor >/dev/null

if ! is_dry_run; then
  if ! command -v mkarchiso >/dev/null 2>&1; then
    log_error "mkarchiso is missing. Install ISO tooling first with: ./install.sh iso-tools"
    exit 1
  fi
  if grep -Fq "uefi.grub" "$PROFILE_SOURCE/profiledef.sh" && ! command -v grub-install >/dev/null 2>&1; then
    log_error "grub-install is missing, but the SevenOS ISO now uses the UEFI GRUB boot route."
    log_info "Install the complete ISO tooling first:"
    log_info "  ./install.sh iso-tools"
    log_info "Then rebuild the ISO:"
    log_info "  ./install.sh iso"
    exit 1
  fi
  require_command sudo
  if ! sudo -n true >/dev/null 2>&1; then
    if [[ -t 0 ]]; then
      log_info "SevenOS needs administrator rights to run mkarchiso."
      sudo -v
    else
      log_error "mkarchiso needs sudo, but this session has no interactive password prompt."
      log_info "Run the same command from a terminal, or refresh sudo first with: sudo -v"
      exit 1
    fi
  fi
fi

if [[ ! -d "$PROFILE_SOURCE" ]]; then
  log_error "Archiso profile not found: $PROFILE_SOURCE"
  exit 1
fi

if [[ ! -d "$PROFILE_SOURCE/syslinux" ]]; then
  log_error "Archiso profile is missing syslinux boot files: $PROFILE_SOURCE/syslinux"
  log_info "Copy a current Archiso template or run the SevenOS profile repair before building."
  exit 1
fi

if [[ ! -d "$PROFILE_SOURCE/efiboot/loader/entries" ]]; then
  log_error "Archiso profile is missing UEFI loader entries: $PROFILE_SOURCE/efiboot/loader/entries"
  log_info "Copy a current Archiso template or run the SevenOS profile repair before building."
  exit 1
fi

preflight_graphical_profile

log_info "Preparing SevenOS archiso profile..."
clean_path "$PROFILE_BUILD"
clean_path "$WORK_DIR"
run_cmd mkdir -p "$PROFILE_BUILD" "$WORK_DIR" "$OUT_DIR"
delete_old_isos
run_cmd rsync -a --delete "$PROFILE_SOURCE"/ "$PROFILE_BUILD"/

if [[ -s "$LOCAL_REPO_SOURCE/sevenos-local.db.tar.gz" ]]; then
  log_info "Injecting SevenOS local package repository..."
  run_cmd mkdir -p "$LOCAL_REPO_BUILD"
  run_cmd rsync -a "$LOCAL_REPO_SOURCE"/ "$LOCAL_REPO_BUILD"/
  run_cmd bash -lc "cat >>$(printf '%q' "$PROFILE_BUILD/pacman.conf") <<'EOF'

[sevenos-local]
SigLevel = Optional TrustAll
Server = file://$LOCAL_REPO_BUILD
EOF
"
else
  package_list_for_check="$PROFILE_BUILD/packages.x86_64"
  if is_dry_run; then
    package_list_for_check="$PROFILE_SOURCE/packages.x86_64"
  fi
  if grep -Fxq "calamares" "$package_list_for_check" && ! timeout 4 pacman -Si calamares >/dev/null 2>&1; then
    log_error "Calamares is listed for the ISO, but no package source is available."
    log_info "Preview: seven installer iso-runtime build-local-repo --dry-run"
    log_info "Build:   seven installer iso-runtime build-local-repo --yes"
    exit 1
  fi
fi

log_info "Injecting SevenOS repository into live ISO profile..."
run_cmd mkdir -p "$PROFILE_BUILD/airootfs/opt"
run_cmd rsync -a \
  --exclude '.git' \
  --exclude '__pycache__' \
  --exclude 'out' \
  "$ROOT_DIR"/ "$PROFILE_BUILD/airootfs/opt/SevenOS"/

log_info "Building ISO with mkarchiso..."
run_cmd sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_BUILD"
restore_output_ownership

if ! is_dry_run && ! find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -print -quit | grep -q .; then
  log_error "mkarchiso completed, but no ISO file was produced in: $OUT_DIR"
  log_info "The work directory was cleaned before the build; check mkarchiso output above for the failed stage."
  exit 1
fi

verify_iso_boot_menu

log_success "ISO build complete. Output directory: $OUT_DIR"
