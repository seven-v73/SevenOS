#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS masking contract

Usage:
  seven mask [status|doctor|plan|json] [--json]
  ./scripts/mask.sh [status|doctor|plan|json] [--json]

This checks whether public SevenOS surfaces present SevenOS first while keeping
Arch, Hyprland, pacman, systemd and other foundations as backend details.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown mask option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

mask_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import re
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def exists(rel):
    return (root / rel).exists()


def executable(rel):
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


def read(rel):
    try:
        return (root / rel).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def run_json(parts, timeout=6):
    try:
        result = subprocess.run(
            [str(root / parts[0]), *parts[1:]],
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
            env={**os.environ, "SEVENOS_ROOT": str(root), "SEVENOS_DRY_RUN": "0"},
        )
    except Exception:
        return {}
    if result.returncode != 0:
        return {}
    try:
        return json.loads(result.stdout)
    except Exception:
        return {}


def desktop_name(rel):
    text = read(rel)
    match = re.search(r"^Name=(.+)$", text, re.MULTILINE)
    return match.group(1).strip() if match else ""


platform = run_json(["scripts/platform.sh", "json"])
channel = run_json(["scripts/channel.sh", "json"])
installer = run_json(["bin/seven-installer", "status", "--json"])

public_desktop_entries = [
    "seven-hub/seven-hub.desktop",
    "seven-hub/seven-hub-native.desktop",
    "seven-hub/seven-files.desktop",
    "seven-hub/seven-reader.desktop",
    "seven-hub/seven-store.desktop",
    "seven-hub/seven-terminal.desktop",
    "seven-hub/seven-settings.desktop",
    "seven-hub/seven-mini-boundaries.desktop",
    "archiso/profile/airootfs/usr/share/applications/seven-installer.desktop",
]
leak_terms = ("Arch", "Hyprland", "pacman", "systemd")
desktop_leaks = []
for rel in public_desktop_entries:
    name = desktop_name(rel)
    if not name:
        desktop_leaks.append({"path": rel, "reason": "missing Name"})
    elif any(term.lower() in name.lower() for term in leak_terms):
        desktop_leaks.append({"path": rel, "name": name, "reason": "backend term in public name"})

public_copy_checks = [
    {
        "path": "README.md",
        "sample": "\n".join(read("README.md").splitlines()[:8]),
    },
    {
        "path": "archiso/profile/airootfs/root/README-SevenOS.txt",
        "sample": read("archiso/profile/airootfs/root/README-SevenOS.txt"),
    },
    {
        "path": "archiso/profile/airootfs/usr/local/bin/sevenos-welcome",
        "sample": read("archiso/profile/airootfs/usr/local/bin/sevenos-welcome"),
    },
]
public_copy_leaks = []
public_copy_forbidden = (
    "Arch Linux based",
    "modern Hyprland desktop",
    "early Archiso foundation",
    "Repository:\n",
)
for item in public_copy_checks:
    sample = item["sample"]
    for term in public_copy_forbidden:
        if term.lower() in sample.lower():
            public_copy_leaks.append({"path": item["path"], "term": term})

public_interface_files = [
    "session/sevenos.desktop",
    "seven-hub/seven-hub-native.desktop",
    "seven-hub/seven-wallpaper.desktop",
    "seven-hub/seven-store.desktop",
    "seven-hub/seven-terminal.desktop",
    "seven-hub/bin/seven-hub",
    "bin/seven",
    "bin/seven-installer",
    "bin/seven-help",
    "bin/seven-help-native",
    "bin/seven-hub-native",
    "bin/seven-reader-native",
    "bin/seven-quick-settings-native",
    "bin/seven-session-status",
    "bin/seven-shell-panel",
    "bin/seven-spotlight",
    "bin/seven-waybar-action",
    "bin/seven-waybar-center-native",
    "bin/seven-settings-native",
    "bin/seven-store-native",
    "bin/seven-shield-center-native",
    "bin/seven-welcome",
    "scripts/distribution.sh",
    "scripts/seven_ai_provider.py",
    "scripts/seven_ai_agent.py",
    "identity/i18n/en.json",
    "identity/i18n/fr.json",
    "archiso/profile/airootfs/usr/local/bin/sevenos-welcome",
    "archiso/profile/airootfs/root/README-SevenOS.txt",
]
public_interface_forbidden = (
    "SevenOS Hyprland session",
    "DesktopNames=SevenOS;Hyprland",
    "Exec=Hyprland",
    "Seven Hub Native",
    "prototype",
    "Hyprland session",
    "Apply the selected image to the SevenOS Hyprland session",
    "Update Arch packages",
    "pacman, Flatpak",
    "AUR packages",
    "Kali / BlackArch Bridge",
    "NetworkManager tools unavailable",
    "Hyprland display configuration",
    "Reload Hyprland",
    "Hyprland fallback rules",
    "editing Hyprland files",
    "Repository:\n",
    "Waybar and Control Center",
    "Waybar et panneau de contrôle",
    "Reload Desktop",
    "Recharger le bureau",
    "Reapply Hyprland config",
    "Open Hyprland windows",
    "Hyprland SevenOS",
    "NetworkManager controls",
    "NetworkManager tools are missing",
    "PipeWire status",
    "Mixer and PipeWire controls",
    "Explain Bottles and KVM Windows paths",
    "Open Bottles for Windows applications",
    "Open Bottles for Windows apps",
    "Open Bottles or Virt Manager",
    "Explain Bottles, Wine and KVM paths",
    "BlackArch Setup",
    "Preview optional BlackArch bridge",
    "Show Calamares and Archinstall readiness",
    "Show Calamares integration plan",
    "Rofi is required for Spotlight fallback",
    "Rofi is not installed",
    "native Seven Hub prototype",
    "SevenOS Flatpak bridge controls",
    "Hyprland-based intelligent Linux experience",
    "based on Hyprland",
    "Waybar cockpit",
    "Atlas Explorer native mini OS, with documents, maps and OCR",
    "Mini OS Atlas natif orienté documents, cartes et OCR",
    "SevenStore Native",
    "Seven Reader Native",
    "SevenOS Hyprland premium ecosystem",
    "Calamares:",
    "Archinstall:",
    "Calamares runtime:",
)
interface_leaks = []
for rel in public_interface_files:
    sample = read(rel)
    for term in public_interface_forbidden:
        if term.lower() in sample.lower():
            interface_leaks.append({"path": rel, "term": term.strip()})

checks = [
    {
        "key": "platform-facade",
        "state": "OK" if platform.get("state") == "masked" else "PART",
        "title": "SevenOS public platform facade",
        "detail": f"Platform state: {platform.get('state', 'unknown')}.",
        "command": "seven platform",
    },
    {
        "key": "release-channel",
        "state": "OK" if channel.get("schema") == "sevenos.release-channel.v1" else "PART",
        "title": "SevenOS release channel vocabulary",
        "detail": f"Channel: {channel.get('channel', 'unknown')} / {channel.get('state', 'unknown')}.",
        "command": "seven channel",
    },
    {
        "key": "installer-portal",
        "state": "OK" if installer.get("schema") == "sevenos.installer-portal.v1" else "PART",
        "title": "SevenOS installer portal",
        "detail": f"Installer route: {installer.get('route', 'unknown')}.",
        "command": "seven-installer status --json",
    },
    {
        "key": "action-runner",
        "state": "OK" if executable("bin/seven-action-runner") else "MISS",
        "title": "Native action execution",
        "detail": "UI actions can run with SevenOS logs/notifications instead of terminal-first workflows.",
        "command": "seven-action-runner --dry-run -- seven status",
    },
    {
        "key": "desktop-names",
        "state": "OK" if not desktop_leaks else "PART",
        "title": "Public desktop names",
        "detail": "Launcher names should present SevenOS surfaces before backend names.",
        "command": "grep -R '^Name=' seven-hub archiso/profile/airootfs/usr/share/applications",
        "leaks": desktop_leaks,
    },
    {
        "key": "public-copy",
        "state": "OK" if not public_copy_leaks else "PART",
        "title": "SevenOS-first public copy",
        "detail": "README and live welcome text should introduce SevenOS before naming backend projects.",
        "command": "seven about",
        "leaks": public_copy_leaks,
    },
    {
        "key": "personal-os-copy",
        "state": "OK" if not interface_leaks else "PART",
        "title": "Personal OS interface vocabulary",
        "detail": "Normal surfaces should say SevenOS first and hide backend/rice vocabulary from primary copy.",
        "command": "seven mask",
        "leaks": interface_leaks,
    },
    {
        "key": "identity-files",
        "state": "OK" if all([
            "SevenOS" in read("branding/motd"),
            "SevenOS" in read("branding/issue"),
            "SevenOS" in read("branding/sevenos-release"),
            "SevenOS" in read("archiso/profile/airootfs/etc/os-release"),
        ]) else "PART",
        "title": "Boot and terminal identity",
        "detail": "Live and installed identity files should identify SevenOS before the base.",
        "command": "seven identity",
    },
    {
        "key": "software-surface",
        "state": "OK" if executable("bin/seven-store-native") and executable("bin/sevenpkg") else "MISS",
        "title": "SevenOS software surface",
        "detail": "Users install and discover software through SevenStore/sevenpkg before backend package commands.",
        "command": "seven store",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
score = round((ok + part * 0.5) / max(len(checks), 1) * 100)
state = "masked" if score >= 90 else "mostly-masked" if score >= 75 else "backend-visible"

print(json.dumps({
    "schema": "sevenos.mask.v1",
    "state": state,
    "score": score,
    "rule": "SevenOS names first, backend names second.",
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "next": [item for item in checks if item["state"] != "OK"][:5],
}, indent=2))
PY
}

print_human() {
  MASK_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["MASK_JSON"])
print("SevenOS Mask")
print("============")
print(f"State: {data.get('state')}")
print(f"Score: {data.get('score')}%")
print(f"Rule:  {data.get('rule')}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state','MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

print_plan() {
  MASK_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["MASK_JSON"])
print("SevenOS Mask Plan")
print("=================")
if not data.get("next"):
    print("No masking issues.")
for item in data.get("next", []):
    print(f"- {item.get('title')}")
    print(f"  {item.get('detail')}")
    print(f"  command: {item.get('command')}")
PY
}

payload="$(mask_json)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
  exit 0
fi

case "$ACTION" in
  status) print_human "$payload" ;;
  plan) print_plan "$payload" ;;
  doctor)
    print_human "$payload"
    score="$(MASK_JSON="$payload" python - <<'PY'
import json, os
print(json.loads(os.environ["MASK_JSON"]).get("score", 0))
PY
)"
    if [[ "$score" -ge 90 ]]; then
      log_success "SevenOS public masking contract is coherent."
      exit 0
    fi
    log_error "SevenOS public masking contract still exposes too many backend details."
    exit 1
    ;;
esac
