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
  "$ROOT_DIR/scripts/post-install.sh" \
  "$ROOT_DIR/scripts/install-cli.sh" \
  "$ROOT_DIR/scripts/apply-theme.sh" \
  "$ROOT_DIR/scripts/build-iso.sh" \
  "$ROOT_DIR/scripts/dashboard.sh" \
  "$ROOT_DIR/scripts/readiness.sh" \
  "$ROOT_DIR/scripts/improve.sh" \
  "$ROOT_DIR/scripts/repair.sh" \
  "$ROOT_DIR/scripts/ux-check.sh" \
  "$ROOT_DIR/scripts/phase-gate.sh" \
  "$ROOT_DIR/scripts/ecosystem.sh" \
  "$ROOT_DIR/server/seven-server.sh" \
  "$ROOT_DIR/server/seven-deploy.sh" \
  "$ROOT_DIR/branding/shell/terminal-country.sh" \
  "$ROOT_DIR/branding/apply-branding.sh" \
  "$ROOT_DIR/bin/seven" \
  "$ROOT_DIR/bin/seven-country" \
  "$ROOT_DIR/bin/seven-power" \
  "$ROOT_DIR/bin/seven-welcome" \
  "$ROOT_DIR/bin/seven-waybar-profile" \
  "$ROOT_DIR/bin/seven-waybar-security" \
  "$ROOT_DIR/bin/sevenpkg" \
  "$ROOT_DIR/bin/sevenosctl" \
  "$ROOT_DIR/security/hardening.sh" \
  "$ROOT_DIR/security/cyber-audit.sh" \
  "$ROOT_DIR/security/cyber-lab.sh" \
  "$ROOT_DIR/security/blackarch.sh" \
  "$ROOT_DIR/vm/check.sh" \
  "$ROOT_DIR/vm/network.sh" \
  "$ROOT_DIR/vm/windows-mode.sh" \
  "$ROOT_DIR/vm/windows-vm.sh" \
  "$ROOT_DIR/installer/plan.sh" \
  "$ROOT_DIR/installer/validate-plan.sh" \
  "$ROOT_DIR/installer/generate-script.sh" \
  "$ROOT_DIR/seven-hub/install.sh" \
  "$ROOT_DIR/seven-hub/bin/seven-hub"
bash -n "$ROOT_DIR/security/hardening.sh"

log_info "Checking desktop config syntax..."
PYTHONDONTWRITEBYTECODE=1 python -m py_compile "$ROOT_DIR/bin/seven" "$ROOT_DIR/bin/sevenpkg"
python -m json.tool "$ROOT_DIR/sevenpkg/metapackages.json" >/dev/null

for doc in VISION.md PRODUCT_STRATEGY.md UX_PRINCIPLES.md VOCABULARY.md OS_CRITERIA.md DEPLOYMENT.md ECOSYSTEM.md PHASE_GATE.md TEST_MACHINE.md PRE_PUSH.md; do
  if [[ ! -s "$ROOT_DIR/docs/$doc" ]]; then
    log_error "Missing product direction document: docs/$doc"
    exit 1
  fi
done

if command -v jq >/dev/null 2>&1; then
  jq empty "$ROOT_DIR/hyprland/waybar/config.jsonc"
  jq empty "$ROOT_DIR/branding/fastfetch/config.jsonc"
  jq empty "$ROOT_DIR/archiso/profile/airootfs/etc/skel/.config/fastfetch/config.jsonc"
  jq empty "$ROOT_DIR/archiso/profile/airootfs/root/.config/fastfetch/config.jsonc"
else
  log_warn "jq not found; skipping Waybar JSON check."
fi

if ! grep -q 'seven ecosystem' "$ROOT_DIR/branding/motd"; then
  log_error "Branding MOTD must expose the SevenOS ecosystem entrypoint."
  exit 1
fi

if grep -Eq 'sevenosctl (status|doctor|hub)' \
  "$ROOT_DIR/branding/motd" \
  "$ROOT_DIR/archiso/profile/airootfs/root/README-SevenOS.txt" \
  "$ROOT_DIR/archiso/profile/airootfs/usr/local/bin/sevenos-welcome" \
  "$ROOT_DIR/archiso/profile/airootfs/etc/motd"; then
  log_error "Branding/welcome files should prefer 'seven' over legacy 'sevenosctl'."
  exit 1
fi

for live_branding in \
  "$ROOT_DIR/archiso/profile/airootfs/etc/issue" \
  "$ROOT_DIR/archiso/profile/airootfs/etc/sevenos-release" \
  "$ROOT_DIR/archiso/profile/airootfs/etc/os-release"; do
  if ! grep -q 'ecosystem' "$live_branding"; then
    log_error "Live branding missing ecosystem identity: ${live_branding#$ROOT_DIR/}"
    exit 1
  fi
done

if command -v rofi >/dev/null 2>&1; then
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/sevenos.rasi" -dump-theme >/dev/null
  rofi -no-config -theme "$ROOT_DIR/hyprland/rofi/power.rasi" -dump-theme >/dev/null
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

if command -v kitty >/dev/null 2>&1; then
  kitty +runpy 'from kitty.config import load_config; load_config("hyprland/kitty/kitty.conf")' >/dev/null 2>&1 || {
    log_error "Kitty config failed to parse."
    exit 1
  }
else
  log_warn "kitty not found; skipping Kitty config parse."
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
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" post-install >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cli --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-power" lock >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-welcome" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-country" plain >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-profile" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-waybar-security" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/dashboard.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/post-install.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/readiness.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/readiness.sh" --json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/readiness.sh" --record >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/improve.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/improve.sh" security >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/improve.sh" security --apply --yes >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/improve.sh" deployment >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/repair.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/repair.sh" security >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/repair.sh" deployment --apply --yes >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ux-check.sh" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" roadmap >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/scripts/ecosystem.sh" doctor >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/server/seven-server.sh" status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/server/seven-server.sh" doctor >/dev/null || true
SEVENOS_DRY_RUN=1 "$ROOT_DIR/server/seven-server.sh" install-user-service >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/server/seven-deploy.sh" detect "$ROOT_DIR" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/server/seven-deploy.sh" plan "$ROOT_DIR" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/server/seven-deploy.sh" status >/dev/null
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
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run welcome >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven-country" open >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run dashboard >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run post-install >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run ecosystem >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run ecosystem roadmap >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run phase-gate >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run readiness >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run readiness --json >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run readiness --record >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run improve security >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run improve security --apply --yes >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run improve deployment >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run repair >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run repair security --apply --yes >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run doctor fix deployment >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run server status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run server doctor >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run deploy detect "$ROOT_DIR" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run deploy plan "$ROOT_DIR" >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run profile shield >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run shield audit >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run vm start windows >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run windows status >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/bin/seven" --dry-run windows start >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" branding --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" security --dry-run --yes >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" theme --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" iso --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" vm-network --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" vm-windows --iso /tmp/windows.iso --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" vm-windows --iso /tmp/windows.iso --virtio-iso /tmp/virtio.iso --os win10 --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" windows-mode status --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" windows-mode start --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" server --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cybersecurity core --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cybersecurity sandbox --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-audit --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-lab --name check --offline --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-lab --preset web --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" cyber-lab --preset forensics --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" blackarch-setup --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" blackarch-category webapp --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" blackarch-tool feroxbuster --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" installer-plan --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" installer-check --dry-run >/dev/null
SEVENOS_DRY_RUN=1 "$ROOT_DIR/install.sh" installer-script --dry-run >/dev/null

log_success "All checks passed."
