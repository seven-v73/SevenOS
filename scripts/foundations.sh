#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS foundations

Usage:
  seven foundations [status|doctor|plan|json] [--json]
  seven foundation [status|doctor|plan|json] [--json]

This contract keeps Arch, Hyprland, pacman, systemd, libvirt and other low-level
tools visible as technical foundations, while presenting SevenOS-owned surfaces
as the normal user workflow.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown foundations option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

foundations_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import shutil
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def executable(rel: str) -> bool:
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


def file_ok(rel: str) -> bool:
    path = root / rel
    return path.is_file() and path.stat().st_size > 0


def command_ok(command: str) -> bool:
    return shutil.which(command) is not None


def run_ok(command, timeout=4) -> bool:
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except Exception:
        return False
    return result.returncode == 0


def layer(key, public, backend, surface, route, backend_ready, surface_ready, strict=True):
    if backend_ready and surface_ready:
        state = "OK"
    elif surface_ready or (backend_ready and not strict):
        state = "PART"
    else:
        state = "MISS"
    return {
        "key": key,
        "public_name": public,
        "backend": backend,
        "surface": surface,
        "route": route,
        "backend_ready": bool(backend_ready),
        "surface_ready": bool(surface_ready),
        "state": state,
    }


layers = [
    layer(
        "identity",
        "SevenOS Identity",
        "os-release, issue, MOTD, branding files",
        "About, Welcome, installer portal",
        "seven about",
        file_ok("branding/sevenos-release") and file_ok("branding/issue"),
        executable("bin/seven-welcome") and file_ok("scripts/about.sh"),
    ),
    layer(
        "software",
        "SevenOS Software",
        "pacman, Flatpak, yay/paru",
        "SevenStore, SevenOS Update, SevenPkg, profile bundles",
        "seven update",
        command_ok("pacman") or command_ok("flatpak"),
        executable("bin/seven-store-native") and file_ok("scripts/update.sh") and executable("bin/sevenpkg"),
    ),
    layer(
        "window-system",
        "Seven Smart Window System",
        "Hyprland, Wayland, Lua-generated config",
        "Window controls, Settings, profile layouts",
        "seven window",
        command_ok("hyprctl") or bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")),
        file_ok("hyprland/lua/init.lua") and file_ok("hyprland/conf/sevenos-lua-generated.conf"),
    ),
    layer(
        "shell",
        "SevenOS Shell",
        "Waybar, Rofi, GTK/libadwaita surfaces",
        "Hub, Control Center, Launchpad, Spotlight",
        "seven hub",
        command_ok("waybar") or command_ok("rofi"),
        executable("bin/seven-hub-native") and executable("bin/seven-launchpad-native") and executable("bin/seven-spotlight"),
    ),
    layer(
        "settings",
        "SevenOS Settings",
        "gsettings, xdg, NetworkManager, PipeWire, Hyprland outputs",
        "Settings, Control Center, Quick Settings",
        "seven-settings",
        command_ok("gsettings") or command_ok("nmcli") or command_ok("wpctl"),
        executable("bin/seven-settings-native") and executable("bin/seven-waybar-center-native"),
        strict=False,
    ),
    layer(
        "mini-os-runtime",
        "SevenOS Mini OS Runtime",
        "LAPA, cgroups, bubblewrap, profile roots",
        "Profile Center, Launchpad, runtime manifests",
        "seven profile status",
        file_ok("profiles/catalog.json"),
        executable("bin/seven-profile-run") and executable("bin/seven-mini-os-center"),
    ),
    layer(
        "security",
        "Shield Security Runtime",
        "UFW, firejail, bubblewrap, security tools",
        "Shield Center, Scope, Network Guard, Tool Doctor",
        "seven shield status",
        command_ok("firejail") or command_ok("bwrap") or command_ok("ufw"),
        executable("bin/seven-shield-center-native") and file_ok("security/shield-status.sh"),
        strict=False,
    ),
    layer(
        "windows-bridge",
        "Windows Bridge",
        "Wine, Bottles, libvirt, QEMU/KVM",
        "Windows Assistant, VM lifecycle, app resolver",
        "seven windows status",
        command_ok("virsh") or command_ok("qemu-system-x86_64") or command_ok("wine"),
        executable("bin/seven-windows-assistant") and file_ok("vm/windows-mode.sh"),
        strict=False,
    ),
    layer(
        "installer",
        "SevenOS Installer",
        "Archiso, Archinstall, Calamares route",
        "Installer Portal, release gate",
        "seven installer status",
        file_ok("archiso/profile/profiledef.sh") or command_ok("archinstall"),
        executable("bin/seven-installer") and file_ok("scripts/installer-stack.sh"),
        strict=False,
    ),
    layer(
        "maintenance",
        "SevenOS Lifecycle",
        "systemd, journalctl, manifest backups, repair scripts",
        "Lifecycle, Doctor, Repair, Release Gate",
        "seven lifecycle",
        command_ok("systemctl") or command_ok("journalctl"),
        file_ok("scripts/lifecycle.sh") and file_ok("scripts/doctor.sh") and file_ok("scripts/repair.sh"),
        strict=False,
    ),
]

ok = sum(1 for item in layers if item["state"] == "OK")
part = sum(1 for item in layers if item["state"] == "PART")
miss = sum(1 for item in layers if item["state"] == "MISS")
score = round((ok + part * 0.5) / max(len(layers), 1) * 100)
state = "sevenos-owned" if score >= 90 else "mostly-owned" if score >= 75 else "backend-visible"

print(json.dumps({
    "schema": "sevenos.foundations.v1",
    "state": state,
    "score": score,
    "summary": {
        "layers": len(layers),
        "ok": ok,
        "partial": part,
        "missing": miss,
    },
    "principle": "SevenOS owns the workflow; backend projects remain documented foundations.",
    "layers": layers,
    "issues": [item for item in layers if item["state"] != "OK"],
    "commands": {
        "status": "seven foundations",
        "doctor": "seven foundations doctor",
        "product": "seven product",
        "state": "seven state --json",
    },
}, indent=2))
PY
}

print_human() {
  FOUNDATIONS_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["FOUNDATIONS_JSON"])
print("SevenOS Foundations")
print("===================")
print(f"State: {data.get('state')}")
print(f"Score: {data.get('score')}%")
print(f"Rule:  {data.get('principle')}")
print()
for item in data.get("layers", []):
    print(f"{item.get('state','MISS'):<4} {item.get('public_name')}")
    print(f"     Surface: {item.get('surface')}")
    print(f"     Route:   {item.get('route')}")
    print(f"     Backend: {item.get('backend')}")
PY
}

print_plan() {
  FOUNDATIONS_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["FOUNDATIONS_JSON"])
print("SevenOS Foundations Plan")
print("========================")
issues = data.get("issues", [])
if not issues:
    print("No foundation ownership issues.")
for item in issues:
    print(f"- {item.get('public_name')}")
    if not item.get("surface_ready"):
        print(f"  finish surface: {item.get('surface')}")
    if not item.get("backend_ready"):
        print(f"  prepare backend: {item.get('backend')}")
    print(f"  route: {item.get('route')}")
PY
}

payload="$(foundations_json)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
  exit 0
fi

case "$ACTION" in
  status) print_human "$payload" ;;
  plan) print_plan "$payload" ;;
  doctor)
    print_human "$payload"
    score="$(FOUNDATIONS_JSON="$payload" python - <<'PY'
import json, os
print(json.loads(os.environ["FOUNDATIONS_JSON"]).get("score", 0))
PY
)"
    if [[ "$score" -ge 90 ]]; then
      log_success "SevenOS owns the public workflow for its foundations."
      exit 0
    fi
    log_error "Some foundations still expose backend-first workflows."
    exit 1
    ;;
esac
