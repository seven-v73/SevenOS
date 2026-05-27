#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
ACTION="${1:-doctor}"
JSON_OUTPUT=0

case "${2:-}" in
  --json|json) JSON_OUTPUT=1 ;;
esac

asset_state() {
  local path="$1"
  [[ -s "$ROOT_DIR/$path" ]] && printf OK || printf MISS
}

package_contains() {
  local package="$1"
  local file="$2"
  grep -Fxq "$package" "$ROOT_DIR/$file"
}

json_report() {
  local state=OK
  local checks_json
  ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
checks = []

def file_check(path: str):
    full = root / path
    checks.append({"path": path, "state": "OK" if full.is_file() and full.stat().st_size > 0 else "MISS"})

def text_check(path: str, needle: str, label: str):
    full = root / path
    ok = full.is_file() and needle in full.read_text(encoding="utf-8", errors="ignore")
    checks.append({"path": label, "state": "OK" if ok else "MISS"})

def package_check(path: str, package: str):
    full = root / path
    ok = full.is_file() and package in {line.strip() for line in full.read_text(encoding="utf-8", errors="ignore").splitlines() if line.strip() and not line.lstrip().startswith("#")}
    checks.append({"path": f"{path}:{package}", "state": "OK" if ok else "MISS"})

for path in [
    "branding/plymouth/sevenos/sevenos.plymouth",
    "branding/plymouth/sevenos/sevenos.script",
    "branding/plymouth/sevenos/seven-prism.png",
    "branding/sddm/sevenos/Main.qml",
    "branding/sddm/sevenos/theme.conf",
    "branding/sddm/sevenos/metadata.desktop",
    "branding/sddm/sevenos/assets/seven-prism.png",
    "scripts/boot-splash.sh",
    "scripts/login-theme.sh",
    "scripts/packages-identity.txt",
]:
    file_check(path)

for path, needle, label in [
    ("scripts/boot-splash.sh", "generate_localized_script", "boot splash localized generator"),
    ("scripts/login-theme.sh", "generate_theme_config", "login theme generated config"),
    ("scripts/login-theme.sh", "active_profile_color", "login theme active profile colors"),
    ("archiso/profile/airootfs/root/customize_airootfs.sh", "boot-splash.sh theme", "ISO applies boot splash identity"),
    ("archiso/profile/airootfs/root/customize_airootfs.sh", "login-theme.sh apply", "ISO applies login theme identity"),
    ("archiso/profile/airootfs/root/customize_airootfs.sh", "systemctl enable sddm.service", "ISO enables SDDM login manager"),
    ("scripts/new-device.sh", "scripts/packages-identity.txt", "new-device knows identity packages"),
    ("scripts/new-device.sh", "scripts/login-theme.sh", "new-device applies login theme"),
    ("scripts/build-iso.sh", "identity-assets.sh", "ISO build validates identity assets"),
    ("scripts/system-install.sh", "identity-assets.sh", "system install validates identity assets"),
]:
    text_check(path, needle, label)

for package in ["plymouth", "sddm", "xorg-server", "xorg-xauth", "polkit-kde-agent", "qt5-declarative", "qt6-declarative"]:
    package_check("scripts/packages-identity.txt", package)
for package in ["plymouth", "sddm", "xorg-server", "xorg-xauth", "polkit-kde-agent", "qt6-declarative"]:
    package_check("archiso/profile/packages.x86_64", package)

state = "OK" if all(check["state"] == "OK" for check in checks) else "MISS"
print(json.dumps({
    "schema": "sevenos.identity-assets.v1",
    "state": state,
    "install_target": "/opt/SevenOS",
    "contract": "SevenOS boot splash and SDDM login identity must be present on fresh installs and ISO builds.",
    "checks": checks,
}, ensure_ascii=False, indent=2))
PY
}

case "$ACTION" in
  status|doctor|json)
    if [[ "$JSON_OUTPUT" -eq 1 || "$ACTION" == json ]]; then
      json_report
    else
      report="$(json_report)"
      state="$(printf '%s' "$report" | python -c 'import json,sys; print(json.load(sys.stdin)["state"])')"
      printf 'SevenOS identity assets: %s\n' "$state"
      REPORT="$report" python - <<'PY'
import json
import os
data = json.loads(os.environ["REPORT"])
for check in data["checks"]:
    print(f"  {check['state']:4} {check['path']}")
PY
      [[ "$state" == OK ]]
    fi
    ;;
  *)
    printf 'Usage: scripts/identity-assets.sh [doctor|status|json] [--json]\n' >&2
    exit 1
    ;;
esac
