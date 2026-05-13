#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

require_arch
require_command pacman

log_info "Checking shell syntax..."
bash -n \
  "$ROOT_DIR/install.sh" \
  "$ROOT_DIR/bootstrap.sh" \
  "$ROOT_DIR"/profiles/*.sh \
  "$ROOT_DIR/scripts/lib.sh" \
  "$ROOT_DIR/scripts/doctor.sh" \
  "$ROOT_DIR/scripts/status.sh" \
  "$ROOT_DIR/scripts/install-cli.sh" \
  "$ROOT_DIR/scripts/apply-theme.sh" \
  "$ROOT_DIR/scripts/build-iso.sh" \
  "$ROOT_DIR/branding/apply-branding.sh" \
  "$ROOT_DIR/bin/seven" \
  "$ROOT_DIR/bin/sevenpkg" \
  "$ROOT_DIR/bin/sevenosctl" \
  "$ROOT_DIR/security/hardening.sh" \
  "$ROOT_DIR/security/cyber-audit.sh" \
  "$ROOT_DIR/security/cyber-lab.sh" \
  "$ROOT_DIR/security/blackarch.sh" \
  "$ROOT_DIR/vm/check.sh" \
  "$ROOT_DIR/vm/network.sh" \
  "$ROOT_DIR/vm/windows-vm.sh" \
  "$ROOT_DIR/installer/plan.sh" \
  "$ROOT_DIR/installer/validate-plan.sh" \
  "$ROOT_DIR/installer/generate-script.sh" \
  "$ROOT_DIR/seven-hub/install.sh" \
  "$ROOT_DIR/seven-hub/bin/seven-hub"
bash -n "$ROOT_DIR/security/hardening.sh"

log_info "Checking desktop config syntax..."
python -m py_compile "$ROOT_DIR/bin/seven" "$ROOT_DIR/bin/sevenpkg"
python -m json.tool "$ROOT_DIR/sevenpkg/metapackages.json" >/dev/null

if command -v jq >/dev/null 2>&1; then
  jq empty "$ROOT_DIR/hyprland/waybar/config.jsonc"
  jq empty "$ROOT_DIR/branding/fastfetch/config.jsonc"
  jq empty "$ROOT_DIR/archiso/profile/airootfs/etc/skel/.config/fastfetch/config.jsonc"
  jq empty "$ROOT_DIR/archiso/profile/airootfs/root/.config/fastfetch/config.jsonc"
else
  log_warn "jq not found; skipping Waybar JSON check."
fi

if command -v rofi >/dev/null 2>&1; then
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/sevenos.rasi" -dump-theme >/dev/null
else
  log_warn "rofi not found; skipping Rofi theme check."
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  hypr_errors="$(hyprctl configerrors | sed '/^[[:space:]]*$/d')"
  if [[ -n "$hypr_errors" && "$hypr_errors" != "no errors" ]]; then
    printf '%s\n' "$hypr_errors"
    log_error "Hyprland reports config errors in the active session."
    exit 1
  fi
else
  log_warn "Hyprland session not detected; skipping live Hyprland config check."
fi

log_info "Checking package names against pacman metadata..."
missing=0

for package_file in "$ROOT_DIR"/scripts/packages-*.txt; do
  while IFS= read -r package; do
    package="${package%%#*}"
    package="${package//[[:space:]]/}"

    [[ -z "$package" ]] && continue

    if ! pacman -Si "$package" >/dev/null 2>&1; then
      printf '%s: missing package: %s\n' "${package_file#$ROOT_DIR/}" "$package" >&2
      missing=1
    fi
  done < "$package_file"
done

while IFS= read -r package; do
  [[ -z "$package" ]] && continue
  if ! pacman -Si "$package" >/dev/null 2>&1; then
    printf 'sevenpkg/metapackages.json: missing package: %s\n' "$package" >&2
    missing=1
  fi
done < <(
  python - "$ROOT_DIR/sevenpkg/metapackages.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

for meta in manifest.values():
    if meta.get("kind") == "pacman":
        for package in meta.get("packages", []):
            print(package)
PY
)

if [[ "$missing" -ne 0 ]]; then
  log_error "Some packages were not found in enabled pacman repositories."
  exit 1
fi

log_info "Checking installer dry-run..."
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" all --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cli --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" meta >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" sources >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" --dry-run install forge >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" --dry-run install shield core >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" --dry-run install horizon >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" --dry-run install nmap hashcat >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" --dry-run remove nmap hashcat >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/sevenpkg" info shield >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run profile list >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run profile status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run profile shield >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run shield audit >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run vm start windows >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" branding --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" theme --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" iso --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" vm-network --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" vm-windows --iso /tmp/windows.iso --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" vm-windows --iso /tmp/windows.iso --virtio-iso /tmp/virtio.iso --os win10 --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cybersecurity core --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cybersecurity sandbox --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-audit --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-lab --name check --offline --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" blackarch-setup --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" blackarch-category webapp --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" blackarch-tool feroxbuster --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" installer-plan --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" installer-check --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" installer-script --dry-run >/dev/null

log_success "All checks passed."
