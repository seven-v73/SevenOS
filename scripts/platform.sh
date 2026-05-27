#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS platform facade

Usage:
  seven platform [status|json|doctor] [--json]

This is the public SevenOS vocabulary for low-level backends. It lets user
surfaces say "SevenOS Window System" or "SevenOS Software" first, while keeping
Arch, Hyprland, pacman and systemd as implementation details.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|json|doctor) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown platform option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

platform_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import shutil
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def command_state(command):
    return "OK" if shutil.which(command) else "MISS"


def file_state(rel):
    path = root / rel
    return "OK" if path.exists() and path.stat().st_size > 0 else "MISS"


def run_state(parts, timeout=4):
    try:
        result = subprocess.run(
            parts,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except Exception:
        return "MISS"
    return "OK" if result.returncode == 0 else "PART"


layers = [
    {
        "key": "software",
        "public_name": "SevenOS Software",
        "user_surface": "SevenStore, sevenpkg",
        "backend": "pacman, Flatpak, AUR helpers",
        "state": "OK" if (root / "bin/sevenpkg").is_file() and (root / "bin/seven-store-native").is_file() else "MISS",
        "masking": "backend-hidden",
    },
    {
        "key": "window-system",
        "public_name": "Seven Smart Window System",
        "user_surface": "Smart Window controls, Settings, Lua profile engine",
        "backend": "Hyprland, Wayland, generated conf",
        "state": "OK" if file_state("hyprland/lua/init.lua") == "OK" and file_state("hyprland/conf/sevenos-lua-generated.conf") == "OK" else "PART",
        "masking": "sevenos-first",
    },
    {
        "key": "session",
        "public_name": "SevenOS Session",
        "user_surface": "Seven Hub, Waybar, session target",
        "backend": "systemd user services",
        "state": "OK" if file_state("systemd/user/sevenos-session.target") == "OK" else "PART",
        "masking": "service-hidden",
    },
    {
        "key": "profiles",
        "public_name": "SevenOS Mini OS Runtime",
        "user_surface": "Profile Center, Launchpad, runtime manifests",
        "backend": "LAPA, cgroups, shims, bubblewrap, profile roots",
        "state": "OK" if file_state("profiles/catalog.json") == "OK" and (root / "bin/seven-profile-run").is_file() else "PART",
        "masking": "profile-first",
    },
    {
        "key": "installer",
        "public_name": "SevenOS Installer",
        "user_surface": "Install SevenOS, release gate",
        "backend": "Calamares profile, Archiso, Archinstall planner",
        "state": "OK" if (root / "bin/seven-installer").is_file() and file_state("installer/calamares/settings.conf") == "OK" else "PART",
        "masking": "route-ready",
    },
    {
        "key": "runtime-core",
        "public_name": "Seven Core",
        "user_surface": "Doctor, Hub, state contracts",
        "backend": "SevenDaemon, shell contracts, JSON bus",
        "state": "OK" if (root / "bin/seven-daemon").is_file() and file_state("systemd/user/seven-daemon.service") == "OK" else "PART",
        "masking": "contract-first",
    },
    {
        "key": "windows",
        "public_name": "Atlas Explorer",
        "user_surface": "Windows mini OS, assistant, VM lifecycle",
        "backend": "Wine, Bottles, libvirt, QEMU/KVM",
        "state": "OK" if (root / "scripts/packages-atlas.txt").is_file() else "PART",
        "masking": "vm-first",
    },
]

ok = sum(1 for item in layers if item["state"] == "OK")
part = sum(1 for item in layers if item["state"] == "PART")
score = round((ok + part * 0.5) / len(layers) * 100)

print(json.dumps({
    "schema": "sevenos.platform.v1",
    "state": "masked" if score >= 85 else "visible-backends" if score >= 65 else "backend-exposed",
    "score": score,
    "public_rule": "SevenOS names first, backend names second.",
    "summary": {
        "layers": len(layers),
        "ok": ok,
        "partial": part,
        "missing": sum(1 for item in layers if item["state"] == "MISS"),
    },
    "layers": layers,
    "commands": {
        "status": "seven platform",
        "autonomy": "seven autonomy",
        "state": "seven state --json",
    },
}, indent=2))
PY
}

payload="$(platform_json)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
  exit 0
fi

case "$ACTION" in
  status)
    PLATFORM_JSON="$payload" python - <<'PY'
import json, os
data=json.loads(os.environ["PLATFORM_JSON"])
print("SevenOS Platform")
print("================")
print(f"State: {data.get('state')}")
print(f"Score: {data.get('score')}%")
print(f"Rule:  {data.get('public_rule')}")
print()
for item in data.get("layers", []):
    print(f"{item.get('state','MISS'):<4} {item.get('public_name')}")
    print(f"     Surface: {item.get('user_surface')}")
    print(f"     Backend: {item.get('backend')}")
PY
    ;;
  doctor)
    PLATFORM_JSON="$payload" python - <<'PY'
import json, os, sys
data=json.loads(os.environ["PLATFORM_JSON"])
print(f"SevenOS Platform: {data.get('state')} ({data.get('score')}%)")
sys.exit(0 if data.get("score", 0) >= 85 else 1)
PY
    ;;
esac
