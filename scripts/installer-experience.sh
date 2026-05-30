#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
ACTION="status"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS Installer Experience

Usage:
  seven installer experience [status|doctor|plan|json] [--json]

Shows the public installation experience contract:
graphical installer, hardware detection, GPU driver hints, preset profiles and
post-install assistant.
EOF
}

for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

payload_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def run(command, timeout=5):
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
            env={**os.environ, "SEVENOS_ROOT": str(root)},
        )
        return result.stdout.strip()
    except Exception:
        return ""


def run_json(command, fallback=None, timeout=10):
    fallback = fallback or {}
    out = run(command, timeout)
    try:
        return json.loads(out) if out else fallback
    except Exception:
        return fallback


def exists(path):
    return (root / path).exists()


def executable(path):
    return os.access(root / path, os.X_OK)


def command(name):
    return shutil.which(name) is not None


def detect_hardware():
    lspci = run(["lspci"], 4)
    cpu = run(["lscpu"], 4)
    disks = run(["lsblk", "-J", "-o", "NAME,TYPE,SIZE,MODEL,TRAN"], 4)
    mem_gib = None
    try:
        meminfo = Path("/proc/meminfo").read_text(encoding="utf-8", errors="ignore")
        match = re.search(r"MemTotal:\s+(\d+)", meminfo)
        if match:
            mem_gib = round(int(match.group(1)) / 1024 / 1024, 1)
    except Exception:
        pass
    gpu_vendor = "unknown"
    gpu_text = "\n".join(line for line in lspci.splitlines() if re.search(r"VGA|3D|Display", line, re.I))
    lowered = gpu_text.lower()
    if "nvidia" in lowered:
        gpu_vendor = "nvidia"
    elif "advanced micro devices" in lowered or re.search(r"\b(amd|ati)\b", lowered):
        gpu_vendor = "amd"
    elif "intel" in lowered:
        gpu_vendor = "intel"
    elif gpu_text:
        gpu_vendor = "other"

    return {
        "cpu": next((line.split(":", 1)[1].strip() for line in cpu.splitlines() if line.startswith("Model name:")), ""),
        "memory_gib": mem_gib,
        "gpu_vendor": gpu_vendor,
        "gpu_summary": gpu_text,
        "virtualized": bool(run(["systemd-detect-virt"], 2)),
        "storage_probe": "OK" if disks else "MISS",
        "tools": {
            "lspci": command("lspci"),
            "lscpu": command("lscpu"),
            "lsblk": command("lsblk"),
            "inxi": command("inxi"),
            "fastfetch": command("fastfetch"),
        },
    }


def gpu_driver_hint(vendor):
    hints = {
        "nvidia": {
            "packages": ["nvidia", "nvidia-utils", "lib32-nvidia-utils"],
            "note": "Use the matching NVIDIA driver for the installed kernel; keep nouveau fallback documented.",
            "command": "seven installer experience plan",
        },
        "amd": {
            "packages": ["mesa", "vulkan-radeon", "lib32-mesa", "lib32-vulkan-radeon"],
            "note": "AMD GPUs normally use Mesa/RADV; multilib improves Pulse and Wine/Proton.",
            "command": "seven profile requirements pulse --apply --yes",
        },
        "intel": {
            "packages": ["mesa", "vulkan-intel", "intel-media-driver", "lib32-mesa"],
            "note": "Intel graphics use Mesa/ANV plus media driver for hardware decoding.",
            "command": "seven profile requirements pulse --apply --yes",
        },
        "other": {
            "packages": ["mesa", "vulkan-tools"],
            "note": "Keep Mesa and Vulkan diagnostics available; use vendor documentation if needed.",
            "command": "seven health doctor",
        },
        "unknown": {
            "packages": ["mesa", "vulkan-tools"],
            "note": "GPU vendor was not detected from lspci; install base Mesa and rerun hardware detection.",
            "command": "seven installer experience doctor",
        },
    }
    return hints.get(vendor, hints["unknown"])


def preset_profiles(hardware):
    memory = hardware.get("memory_gib") or 0
    low_power = memory and memory < 8
    return [
        {
            "key": "developer",
            "title": "Forge Developer",
            "mini_os": "forge",
            "goal": "Code, containers, Git, web deployment and local services.",
            "command": "seven profile activate forge",
            "recommended": not low_power,
        },
        {
            "key": "gamer",
            "title": "Pulse Gaming",
            "mini_os": "pulse",
            "goal": "Vulkan, GameMode, Wine/Proton route and performance posture.",
            "command": "seven profile activate pulse",
            "recommended": hardware.get("gpu_vendor") in {"amd", "intel", "nvidia"},
        },
        {
            "key": "creator",
            "title": "Studio Creator",
            "mini_os": "studio",
            "goal": "Images, video, audio, streaming and asset creation packs.",
            "command": "seven profile activate studio",
            "recommended": memory >= 12,
        },
        {
            "key": "server",
            "title": "Forge Server",
            "mini_os": "forge",
            "goal": "Local hosting, Caddy, deploy panel, logs and rollback flows.",
            "command": "seven profile activate forge && seven deploy panel",
            "recommended": not hardware.get("virtualized", False),
        },
        {
            "key": "balanced",
            "title": "Equinox Balance",
            "mini_os": "equinox",
            "goal": "Daily desktop, settings, files, store, helper and updates.",
            "command": "seven profile activate equinox",
            "recommended": True,
        },
    ]


installer = run_json([str(root / "scripts/installer-stack.sh"), "release", "--json"], {})
graphical = run_json([str(root / "scripts/installer-stack.sh"), "graphical", "--json"], {})
first_run = run_json([str(root / "bin/seven"), "first-run", "verify", "--json"], {})
hardware = detect_hardware()
gpu = gpu_driver_hint(hardware.get("gpu_vendor", "unknown"))
profiles = preset_profiles(hardware)

checks = [
    {
        "key": "graphical-installer",
        "title": "Modern graphical installer",
        "state": "OK" if (installer.get("installer") or {}).get("state") == "graphical-ready" or graphical.get("state") in {"graphical-profile-ready", "graphical-ready"} else "PART",
        "detail": "Calamares route, live desktop launcher and installer portal.",
        "command": "seven installer graphical",
    },
    {
        "key": "hardware-detection",
        "title": "Automatic hardware detection",
        "state": "OK" if hardware["tools"]["lspci"] and hardware["tools"]["lsblk"] else "PART",
        "detail": f"GPU={hardware.get('gpu_vendor')} · RAM={hardware.get('memory_gib')} GiB · storage={hardware.get('storage_probe')}",
        "command": "seven installer experience doctor",
    },
    {
        "key": "profile-presets",
        "title": "Preset profiles",
        "state": "OK" if len(profiles) >= 5 and exists("profiles/catalog.json") else "PART",
        "detail": "Developer, gamer, creator, server and balanced presets.",
        "command": "seven universes",
    },
    {
        "key": "gpu-drivers",
        "title": "GPU driver guidance",
        "state": "OK" if gpu.get("packages") else "PART",
        "detail": f"{hardware.get('gpu_vendor')}: {', '.join(gpu.get('packages', [])[:4])}",
        "command": gpu.get("command", "seven installer experience plan"),
    },
    {
        "key": "post-install-assistant",
        "title": "Post-install assistant",
        "state": "OK" if executable("scripts/new-device.sh") and executable("scripts/post-install.sh") and first_run.get("score", 0) >= 90 else "PART",
        "detail": "New-device setup, first-run verifier and post-install diagnostics.",
        "command": "seven setup new-device --yes",
    },
]

ready = sum(1 for item in checks if item["state"] == "OK")
state = "ready" if ready == len(checks) else "attention"
score = round(ready / len(checks) * 100)

print(json.dumps({
    "schema": "sevenos.installer-experience.v1",
    "state": state,
    "score": score,
    "summary": {
        "checks": len(checks),
        "ready": ready,
        "gpu_vendor": hardware.get("gpu_vendor"),
        "recommended_profile": next((item["key"] for item in profiles if item.get("recommended")), "balanced"),
    },
    "checks": checks,
    "hardware": hardware,
    "gpu": gpu,
    "profiles": profiles,
    "post_install": {
        "first_run": "seven first-run verify",
        "assistant": "seven setup new-device --yes",
        "doctor": "seven post-install",
        "repair": "seven repair ux --apply",
    },
    "commands": {
        "status": "seven installer experience",
        "doctor": "seven installer experience doctor",
        "plan": "seven installer experience plan",
        "graphical": "seven-installer open",
        "hardware": "seven installer experience --json",
        "profiles": "seven universes",
        "post_install": "seven setup new-device --yes",
    },
}, ensure_ascii=False, indent=2))
PY
}

print_status() {
  PAYLOAD="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PAYLOAD"])
summary = data.get("summary", {})
print("SevenOS Installer Experience")
print("============================")
print(f"State: {data.get('state')} · Score: {data.get('score')}% · Ready: {summary.get('ready')}/{summary.get('checks')}")
print(f"GPU: {summary.get('gpu_vendor')} · Recommended profile: {summary.get('recommended_profile')}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state', 'PART'):<4} {item.get('title')}: {item.get('detail')}")
    print(f"     {item.get('command')}")
PY
}

print_plan() {
  PAYLOAD="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PAYLOAD"])
print("SevenOS Installer Experience Plan")
print("=================================")
for item in data.get("checks", []):
    if item.get("state") != "OK":
        print(f"- {item.get('title')}: {item.get('command')}")
print()
print("Preset profiles:")
for item in data.get("profiles", []):
    mark = "*" if item.get("recommended") else "-"
    print(f"{mark} {item.get('title')}: {item.get('goal')}")
print()
gpu = data.get("gpu", {})
print("GPU hint:")
print(f"  packages: {', '.join(gpu.get('packages', []))}")
print(f"  note: {gpu.get('note')}")
PY
}

payload="$(payload_json)"
case "$ACTION" in
  status|json)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then printf '%s\n' "$payload"; else print_status "$payload"; fi
    ;;
  plan)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then printf '%s\n' "$payload"; else print_plan "$payload"; fi
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then printf '%s\n' "$payload"; else print_status "$payload"; echo; print_plan "$payload"; fi
    PAYLOAD="$payload" python - <<'PY'
import json
import os
import sys
data = json.loads(os.environ["PAYLOAD"])
sys.exit(0 if data.get("score", 0) >= 80 else 1)
PY
    ;;
esac
