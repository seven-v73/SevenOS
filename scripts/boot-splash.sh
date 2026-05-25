#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

THEME_SRC="$ROOT_DIR/branding/plymouth/sevenos"
THEME_DST="/usr/share/plymouth/themes/sevenos"
CMDLINE_ARGS=(
  quiet
  splash
  loglevel=3
  rd.udev.log_level=3
  vt.global_cursor_default=0
  systemd.show_status=false
  udev.log_priority=3
)

usage() {
  cat <<'EOF'
SevenOS boot splash

Usage:
  seven boot-splash status
  seven boot-splash doctor
  seven boot-splash apply [--yes]
  seven boot-splash theme

This installs the SevenOS Plymouth theme, enables quiet kernel parameters
for systemd-boot/GRUB when detected, and refreshes initramfs.
EOF
}

for option in "$@"; do
  case "$option" in
    --yes|-y) export SEVENOS_YES=1 ;;
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
  esac
done

need_root_command() {
  if is_dry_run; then
    printf 'sudo'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    if [[ ! -t 0 ]] && ! sudo -n true >/dev/null 2>&1; then
      log_error "Administrator permission is required, but no interactive password prompt is available."
      log_info "Open Seven Terminal and run:"
      log_info "  cd $ROOT_DIR"
      log_info "  ./install.sh boot-splash --yes"
      log_info "Preview first with: seven boot-splash doctor"
      return 1
    fi
    sudo "$@"
  fi
}

ensure_plymouth() {
  if command -v plymouth >/dev/null 2>&1 && package_is_satisfied plymouth; then
    return 0
  fi
  if ! command -v pacman >/dev/null 2>&1; then
    log_warn "Plymouth is not installed and pacman is unavailable."
    log_info "Install package manually: plymouth"
    return 0
  fi
  log_info "Installing Plymouth for SevenOS quiet boot"
  if is_dry_run; then
    if assume_yes; then
      printf 'sudo pacman -S --needed --noconfirm plymouth\n'
    else
      printf 'sudo pacman -S --needed plymouth\n'
    fi
    return 0
  fi
  if assume_yes; then
    need_root_command pacman -S --needed --noconfirm plymouth
  else
    need_root_command pacman -S --needed plymouth
  fi
}

install_theme() {
  if [[ ! -d "$THEME_SRC" ]]; then
    log_error "Missing Plymouth theme source: $THEME_SRC"
    return 1
  fi
  log_info "Installing SevenOS Plymouth theme"
  need_root_command install -d "$THEME_DST"
  need_root_command install -m 0644 "$THEME_SRC/sevenos.plymouth" "$THEME_DST/sevenos.plymouth"
  need_root_command install -m 0644 "$THEME_SRC/sevenos.script" "$THEME_DST/sevenos.script"
  need_root_command install -m 0644 "$THEME_SRC/seven-prism.png" "$THEME_DST/seven-prism.png"
}

set_plymouth_theme() {
  if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
    log_warn "plymouth-set-default-theme not found. Install package: plymouth"
    return 1
  fi
  log_info "Selecting SevenOS Plymouth theme"
  if is_dry_run; then
    printf 'sudo plymouth-set-default-theme sevenos\n'
    return 0
  fi
  need_root_command plymouth-set-default-theme sevenos
}

update_mkinitcpio_hooks() {
  local file="/etc/mkinitcpio.conf"
  [[ -f "$file" ]] || return 0
  if grep -Eq '^HOOKS=.*plymouth' "$file"; then
    log_info "mkinitcpio already includes plymouth hook"
    return 0
  fi
  log_info "Adding plymouth hook to mkinitcpio"
  need_root_command cp "$file" "$(backup_path "$file")"
  need_root_command python - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
out = []
changed = False
for line in lines:
    if line.startswith("HOOKS=(") and "plymouth" not in line:
        inner = line.removeprefix("HOOKS=(").removesuffix(")")
        hooks = inner.split()
        if "udev" in hooks:
            hooks.insert(hooks.index("udev") + 1, "plymouth")
        elif "systemd" in hooks:
            hooks.insert(hooks.index("systemd") + 1, "plymouth")
        else:
            hooks.insert(0, "plymouth")
        line = "HOOKS=(" + " ".join(hooks) + ")"
        changed = True
    out.append(line)
if changed:
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
}

refresh_initramfs() {
  if command -v mkinitcpio >/dev/null 2>&1; then
    log_info "Refreshing initramfs"
    if is_dry_run; then
      printf 'sudo mkinitcpio -P\n'
      return 0
    fi
    need_root_command mkinitcpio -P
  else
    log_warn "mkinitcpio not found; initramfs refresh skipped"
  fi
}

configure_services() {
  command -v systemctl >/dev/null 2>&1 || return 0
  local unit
  for unit in plymouth-quit.service plymouth-quit-wait.service; do
    if systemctl list-unit-files "$unit" >/dev/null 2>&1; then
      log_info "Enabling $unit"
      if is_dry_run; then
        printf 'sudo systemctl enable %q\n' "$unit"
      else
        need_root_command systemctl enable "$unit" >/dev/null 2>&1 || true
      fi
    fi
  done
}

cmdline_string() {
  printf '%s ' "${CMDLINE_ARGS[@]}" | sed 's/[[:space:]]$//'
}

merge_cmdline() {
  python - "$@" <<'PY'
import sys

existing = sys.argv[1].split()
needed = sys.argv[2:]
for item in needed:
    key = item.split("=", 1)[0]
    existing = [value for value in existing if value.split("=", 1)[0] != key]
    existing.append(item)
print(" ".join(existing))
PY
}

update_grub() {
  local file="/etc/default/grub"
  [[ -f "$file" ]] || return 0
  log_info "Updating GRUB quiet boot parameters"
  need_root_command cp "$file" "$(backup_path "$file")"
  local merged
  merged="$(python - "$file" "$(cmdline_string)" <<'PY'
from pathlib import Path
import shlex
import sys

path = Path(sys.argv[1])
needed = sys.argv[2].split()
current = ""
for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
    if raw.startswith("GRUB_CMDLINE_LINUX_DEFAULT="):
        _, value = raw.split("=", 1)
        current = value.strip().strip('"').strip("'")
        break
existing = current.split()
for item in needed:
    key = item.split("=", 1)[0]
    existing = [value for value in existing if value.split("=", 1)[0] != key]
    existing.append(item)
print(" ".join(existing))
PY
)"
  need_root_command python - "$file" "$merged" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
merged = sys.argv[2]
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
written = False
out = []
for line in lines:
    if line.startswith("GRUB_CMDLINE_LINUX_DEFAULT="):
        out.append(f'GRUB_CMDLINE_LINUX_DEFAULT="{merged}"')
        written = True
    else:
        out.append(line)
if not written:
    out.append(f'GRUB_CMDLINE_LINUX_DEFAULT="{merged}"')
path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
  if command -v grub-mkconfig >/dev/null 2>&1 && [[ -d /boot/grub ]]; then
    need_root_command grub-mkconfig -o /boot/grub/grub.cfg
  fi
}

update_systemd_boot() {
  local entries_dir="/boot/loader/entries"
  [[ -d "$entries_dir" ]] || return 0
  log_info "Updating systemd-boot entries"
  local entry
  while IFS= read -r -d '' entry; do
    need_root_command cp "$entry" "$(backup_path "$entry")"
    need_root_command python - "$entry" "$(cmdline_string)" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
needed = sys.argv[2].split()
lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
out = []
written = False
for line in lines:
    if line.startswith("options "):
        existing = line.removeprefix("options ").split()
        for item in needed:
            key = item.split("=", 1)[0]
            existing = [value for value in existing if value.split("=", 1)[0] != key]
            existing.append(item)
        out.append("options " + " ".join(existing))
        written = True
    else:
        out.append(line)
if not written:
    out.append("options " + " ".join(needed))
path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
  done < <(find "$entries_dir" -maxdepth 1 -type f -name '*.conf' -print0)
}

status() {
  printf 'SevenOS Boot Splash\n'
  printf 'Theme source: %s\n' "$([[ -d "$THEME_SRC" ]] && printf OK || printf MISS)"
  printf 'Prism asset:   %s\n' "$([[ -s "$THEME_SRC/seven-prism.png" ]] && printf OK || printf MISS)"
  printf 'Plymouth:     %s\n' "$(command -v plymouth >/dev/null 2>&1 && printf OK || printf MISS)"
  printf 'Theme active: '
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme 2>/dev/null || true
  else
    printf 'unknown\n'
  fi
  printf 'Services:     '
  if command -v systemctl >/dev/null 2>&1; then
    local quit_state wait_state
    quit_state="$(systemctl is-enabled plymouth-quit.service 2>/dev/null || true)"
    wait_state="$(systemctl is-enabled plymouth-quit-wait.service 2>/dev/null || true)"
    printf 'quit=%s wait=%s\n' "${quit_state:-unknown}" "${wait_state:-unknown}"
  else
    printf 'unknown\n'
  fi
  printf 'Kernel args:  %s\n' "$(cmdline_string)"
}

doctor_check_file() {
  local label="$1"
  local path="$2"
  if [[ -s "$path" ]]; then
    printf '[OK] %s\n' "$label"
    return 0
  fi
  printf '[FAIL] %s: missing %s\n' "$label" "$path" >&2
  return 1
}

doctor_check_text() {
  local label="$1"
  local pattern="$2"
  local path="$3"
  if grep -q -- "$pattern" "$path" 2>/dev/null; then
    printf '[OK] %s\n' "$label"
    return 0
  fi
  printf '[FAIL] %s: expected %s in %s\n' "$label" "$pattern" "$path" >&2
  return 1
}

doctor() {
  local failed=0
  local script_file="$THEME_SRC/sevenos.script"
  local theme_file="$THEME_SRC/sevenos.plymouth"
  local prism_file="$THEME_SRC/seven-prism.png"
  local archiso_hook="$ROOT_DIR/archiso/profile/airootfs/root/customize_airootfs.sh"

  printf 'SevenOS Boot Splash Doctor\n'
  doctor_check_file "Plymouth theme descriptor" "$theme_file" || failed=1
  doctor_check_file "Plymouth script" "$script_file" || failed=1
  doctor_check_file "Seven Prism boot asset" "$prism_file" || failed=1

  doctor_check_text "Theme declares SevenOS name" 'Name=SevenOS' "$theme_file" || failed=1
  doctor_check_text "Theme uses script module" 'ModuleName=script' "$theme_file" || failed=1
  doctor_check_text "Script loads the Seven Prism PNG" 'Image("seven-prism.png")' "$script_file" || failed=1
  doctor_check_text "Script exposes a refresh callback" 'Plymouth.SetRefreshFunction' "$script_file" || failed=1
  doctor_check_text "Script exposes a ready callback" 'Plymouth.SetQuitFunction' "$script_file" || failed=1
  doctor_check_text "Script keeps SevenOS as boot brand" 'Image.Text("SevenOS"' "$script_file" || failed=1
  doctor_check_text "Installer copies the Prism asset" 'seven-prism.png' "$0" || failed=1
  doctor_check_text "Installer explains non-interactive sudo" 'no interactive password prompt' "$0" || failed=1
  doctor_check_text "Archiso copies the Prism asset" 'seven-prism.png' "$archiso_hook" || failed=1

  if command -v identify >/dev/null 2>&1 && [[ -s "$prism_file" ]]; then
    local dimensions
    dimensions="$(identify -format '%wx%h' "$prism_file" 2>/dev/null || true)"
    if [[ "$dimensions" == "192x192" ]]; then
      printf '[OK] Prism PNG dimensions are stable: %s\n' "$dimensions"
    else
      printf '[FAIL] Prism PNG should be 192x192, got %s\n' "${dimensions:-unknown}" >&2
      failed=1
    fi
  elif [[ -s "$prism_file" ]]; then
    printf '[OK] Prism PNG exists; install ImageMagick for dimension checks\n'
  fi

  if (( failed )); then
    return 1
  fi
  log_success "SevenOS boot splash contract is complete"
}

apply() {
  ensure_plymouth
  install_theme
  set_plymouth_theme || true
  configure_services
  update_mkinitcpio_hooks
  update_grub
  update_systemd_boot
  refresh_initramfs
  log_success "SevenOS quiet boot configured. Reboot to see the splash."
}

action="${1:-status}"
shift || true
case "$action" in
  status) status ;;
  doctor) doctor ;;
  theme) install_theme; set_plymouth_theme || true ;;
  apply) apply "$@" ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown boot-splash action: $action"; usage; exit 1 ;;
esac
