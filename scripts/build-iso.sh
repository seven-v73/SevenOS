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
  check_profile "UEFI boot must hide systemd status text" \
    "efiboot/loader/entries/01-sevenos-live.conf" "systemd.show_status=false"
  check_profile "BIOS boot must be quiet and branded" \
    "syslinux/archiso_sys-linux.cfg" "quiet splash"
  check_profile "SevenOS live service must start the graphical session directly" \
    "airootfs/etc/systemd/system/sevenos-live-session.service" "ExecStart=/usr/local/bin/sevenos-live-session"
  check_profile "SevenOS live session must use the live Hyprland fallback profile" \
    "airootfs/usr/local/bin/sevenos-live-session" "live-hyprland.conf"
  check_profile "SevenOS live profile must relaunch the installer if no window appears" \
    "airootfs/usr/local/bin/sevenos-live-guard" "open_rescue_terminal"
  check_profile "SevenOS live service must run as the live user" \
    "airootfs/etc/systemd/system/sevenos-live-session.service" "User=seven"
  check_profile "Live build must enable the SevenOS live service" \
    "airootfs/root/customize_airootfs.sh" "sevenos-live-session.service"
  check_profile "UEFI boot must expose Safe Graphics" \
    "efiboot/loader/entries/03-sevenos-live-safe.conf" "Safe Graphics"
  check_profile "BIOS boot must expose Safe Graphics" \
    "syslinux/archiso_sys-linux.cfg" "Safe ^Graphics"
  check_profile "Wayland session file must stay available for installed display managers" \
    "airootfs/usr/share/wayland-sessions/sevenos-live.desktop" "sevenos-live-session"
  check_profile "Live session must open the graphical installer portal" \
    "airootfs/usr/local/bin/sevenos-live-ready" "seven-installer gui"
  check_profile "Live session must fall back to Calamares when the portal closes" \
    "airootfs/usr/local/bin/sevenos-live-ready" "SevenOS portal closed; falling back to Calamares"
  check_profile "Live session must launch Calamares directly as a second route" \
    "airootfs/usr/local/bin/sevenos-live-ready" "open_calamares_direct"
  check_profile "Live readiness must confirm real installer windows, not only process ids" \
    "airootfs/usr/local/bin/sevenos-live-ready" "installer_window_visible"
  check_profile "Live session must show a SevenOS background before installer windows appear" \
    "airootfs/etc/sevenos/live-hyprland.conf" "live-hyprpaper.conf"
  check_profile "Live wallpaper config must point to the branded live background" \
    "airootfs/etc/sevenos/live-hyprpaper.conf" "/usr/share/sevenos/live-background.png"
  check_profile "Live background asset must be tracked by the ISO profile" \
    "profiledef.sh" "/usr/share/sevenos/live-background.png"
  check_profile "Live build must install Calamares SevenOS settings" \
    "airootfs/root/customize_airootfs.sh" "/etc/calamares/settings.conf"
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

  check_repo "Calamares must use the standard shellprocess module" \
    "installer/calamares/settings.conf" "- shellprocess"
  check_repo "Calamares shellprocess must finalize SevenOS through the guarded wrapper" \
    "installer/calamares/modules/shellprocess.conf" "/opt/SevenOS/bin/seven-calamares-finalize"
  check_repo "Calamares finalizer must write an install log" \
    "bin/seven-calamares-finalize" "/var/log/sevenos-install.log"
  check_repo "The ISO package list must include the graphical installer" \
    "archiso/profile/packages.x86_64" "calamares"
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

if ! is_dry_run && ! find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -print -quit | grep -q .; then
  log_error "mkarchiso completed, but no ISO file was produced in: $OUT_DIR"
  log_info "The work directory was cleaned before the build; check mkarchiso output above for the failed stage."
  exit 1
fi

log_success "ISO build complete. Output directory: $OUT_DIR"
