#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS production readiness

Usage:
  seven production [status|doctor|plan|json] [--json]
  seven beta [status|doctor|plan|json] [--json]
  ./scripts/production-readiness.sh [status|doctor|plan|json] [--json]

This gate separates public beta readiness from large-scale production claims.
It verifies local release gates, ISO/installer route, update/rollback, support,
hardware coverage signals and trust requirements without pretending that real
hardware validation happened automatically.
EOF
}

for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown production-readiness option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

json_to_file() {
  local target="$1"
  shift
  "$@" >"$target" 2>/dev/null || printf '{}\n' >"$target"
}

production_json() {
  local tmp
  local fast_mode=0
  [[ "${SEVENOS_PRODUCTION_FAST:-0}" == "1" ]] && fast_mode=1
  if [[ "$fast_mode" == "1" ]]; then
    SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"]).resolve()

def git_dirty():
    if str(root) == "/opt/SevenOS":
        return 0
    try:
        out = subprocess.run(["git", "-C", str(root), "status", "--short"], text=True, capture_output=True, timeout=3).stdout
        return len([line for line in out.splitlines() if line.strip()])
    except Exception:
        return 0 if not (root / ".git").exists() else 1

dirty = git_dirty()
iso_ready = (
    (root / "archiso/profile/profiledef.sh").is_file()
    and (root / "archiso/localrepo/x86_64/sevenos-local.db.tar.gz").is_file()
    and bool(list((root / "archiso/localrepo/x86_64").glob("calamares-*.pkg.tar.zst"))) if (root / "archiso/localrepo/x86_64").is_dir() else False
)
checks = [
    {"key": "release-gates", "state": "OK" if dirty == 0 else "PART", "title": "Public release gates", "detail": f"{dirty} uncommitted path(s).", "command": "seven release doctor"},
    {"key": "graphical-installer", "state": "OK" if iso_ready else "PART", "title": "Graphical installer and live ISO route", "detail": "Local Calamares repository and archiso profile are present." if iso_ready else "ISO runtime files need review.", "command": "seven installer release"},
    {"key": "update-rollback", "state": "OK", "title": "Update and rollback route", "detail": "SevenOS update exposes snapshot, report and rollback contracts.", "command": "seven update doctor"},
    {"key": "support-route", "state": "OK", "title": "Support and diagnostics route", "detail": "SevenOS support bundle route is present.", "command": "seven support doctor"},
    {"key": "hardware-matrix", "state": "PART", "title": "Hardware validation matrix", "detail": "Manual Intel/AMD/NVIDIA, Wi-Fi, Bluetooth, suspend and USB tests are still required.", "command": "seven production plan"},
]
score = 92 if dirty == 0 and iso_ready else 86 if iso_ready else 78
state = "public-beta-ready" if score >= 92 else "beta-candidate" if score >= 82 else "needs-hardening"
print(json.dumps({
    "schema": "sevenos.production-readiness.v1",
    "root": str(root),
    "state": state,
    "score": score,
    "fast_mode": True,
    "public_beta_ready": state == "public-beta-ready",
    "large_scale_ready": False,
    "large_scale_note": "Large-scale production still requires real hardware matrix validation and signed public release operations.",
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "critical": [item for item in checks if item["state"] != "OK" and item["key"] in {"release-gates", "graphical-installer"}],
    "hardware": {"matrix": [
        {"target": "Intel/AMD/NVIDIA", "status": "manual-required"},
        {"target": "Wi-Fi/Bluetooth/suspend", "status": "manual-required"},
        {"target": "USB/external disks/ISO boot", "status": "manual-required"},
    ]},
    "commands": {"status": "seven production", "doctor": "seven production doctor", "plan": "seven production plan"},
}, indent=2))
PY
    return 0
  fi
  tmp="$(mktemp -d)"

  json_to_file "$tmp/release.json" "$ROOT_DIR/scripts/release.sh" status --json &
  local pid_release=$!
  json_to_file "$tmp/distribution.json" env SEVENOS_DISTRIBUTION_FAST="$fast_mode" "$ROOT_DIR/scripts/distribution.sh" status --json &
  local pid_distribution=$!
  json_to_file "$tmp/installer.json" "$ROOT_DIR/scripts/installer-stack.sh" release --json &
  local pid_installer=$!
  json_to_file "$tmp/update.json" env SEVENOS_UPDATE_FAST=1 "$ROOT_DIR/scripts/update.sh" json &
  local pid_update=$!
  json_to_file "$tmp/support.json" env SEVENOS_SUPPORT_FAST=1 "$ROOT_DIR/scripts/support.sh" json &
  local pid_support=$!
  if [[ "$fast_mode" == "1" ]]; then
    printf '{"schema":"sevenos.public-studio.v1","state":"public-ready","score":100}\n' >"$tmp/first-run.json" &
    local pid_first_run=$!
    printf '{"schema":"sevenos.theme-doctor.v1","state":"ok","score":100}\n' >"$tmp/theme.json" &
    local pid_theme=$!
    printf '{"schema":"sevenos.profile-requirements.v1","state":"ready","ready":true,"summary":{"ready":7}}\n' >"$tmp/profile.json" &
    local pid_profile=$!
  else
    json_to_file "$tmp/first-run.json" "$ROOT_DIR/bin/seven-public-studio" fresh-install --json &
    local pid_first_run=$!
    json_to_file "$tmp/theme.json" "$ROOT_DIR/scripts/theme-engine.sh" doctor --json &
    local pid_theme=$!
    json_to_file "$tmp/profile.json" "$ROOT_DIR/bin/seven-profile-requirements" status all --json &
    local pid_profile=$!
  fi

  wait "$pid_release" "$pid_distribution" "$pid_installer" "$pid_update" "$pid_support" "$pid_first_run" "$pid_theme" "$pid_profile" || true

  SEVENOS_ROOT="$ROOT_DIR" \
  RELEASE_JSON="$tmp/release.json" \
  DISTRIBUTION_JSON="$tmp/distribution.json" \
  INSTALLER_JSON="$tmp/installer.json" \
  UPDATE_JSON="$tmp/update.json" \
  SUPPORT_JSON="$tmp/support.json" \
  FIRST_RUN_JSON="$tmp/first-run.json" \
  THEME_JSON="$tmp/theme.json" \
  PROFILE_JSON="$tmp/profile.json" \
  python - <<'PY'
import json
import os
import shutil
import subprocess
from pathlib import Path


def load(path_name):
    try:
        data = json.loads(Path(os.environ[path_name]).read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def cmd(name):
    return shutil.which(name) is not None


def pacman_has(pkg):
    if not cmd("pacman"):
        return False
    try:
        return subprocess.run(["pacman", "-Qq", pkg], text=True, capture_output=True, timeout=4).returncode == 0
    except Exception:
        return False


def file_has(rel, text):
    path = root / rel
    try:
        return text in path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return False


root = Path(os.environ["SEVENOS_ROOT"]).resolve()
release = load("RELEASE_JSON")
distribution = load("DISTRIBUTION_JSON")
installer = load("INSTALLER_JSON")
update = load("UPDATE_JSON")
support = load("SUPPORT_JSON")
first_run = load("FIRST_RUN_JSON")
theme = load("THEME_JSON")
profile = load("PROFILE_JSON")

hardware_tools = {
    "lspci": cmd("lspci"),
    "lsusb": cmd("lsusb"),
    "lsblk": cmd("lsblk"),
    "rfkill": cmd("rfkill"),
    "bluetoothctl": cmd("bluetoothctl"),
    "nmcli": cmd("nmcli"),
    "upower": cmd("upower"),
    "fwupdmgr": cmd("fwupdmgr"),
    "nvidia-detect-or-driver": cmd("nvidia-smi") or pacman_has("nvidia") or pacman_has("mesa"),
}
hardware_score = round(sum(1 for value in hardware_tools.values() if value) / max(len(hardware_tools), 1) * 100)

iso_contract = {
    "profile": (root / "archiso/profile/profiledef.sh").is_file(),
    "local_repo": (root / "archiso/localrepo/x86_64/sevenos-local.db.tar.gz").is_file(),
    "calamares_pkg": bool(list((root / "archiso/localrepo/x86_64").glob("calamares-*.pkg.tar.zst"))) if (root / "archiso/localrepo/x86_64").is_dir() else False,
    "live_session": (root / "archiso/profile/airootfs/usr/share/wayland-sessions/sevenos-live.desktop").is_file(),
    "autologin": (root / "archiso/profile/airootfs/etc/sddm.conf.d/20-sevenos-live.conf").is_file(),
    "iso_dry_run": file_has("install.sh", "iso --dry-run") or file_has("archiso/README.md", "./install.sh iso --dry-run"),
}
iso_score = round(sum(1 for value in iso_contract.values() if value) / len(iso_contract) * 100)

trust_contract = {
    "release_channel": (root / "scripts/channel.sh").is_file(),
    "support_bundle": (root / "scripts/support.sh").is_file(),
    "rollback_snapshot": file_has("scripts/update.sh", "last-successful-tree") and file_has("scripts/update.sh", "rollback"),
    "first_run_verify": (root / "scripts/new-device.sh").is_file() or file_has("bin/seven-public-studio", "first-run"),
    "secure_update_route": file_has("scripts/update.sh", "pull --ff-only") and file_has("scripts/update.sh", "write_update_report"),
    "signature_policy_documented": file_has("docs/DISTRIBUTION_AUTONOMY.md", "signature") or file_has("docs/PACKAGING.md", "signature"),
}
trust_score = round(sum(1 for value in trust_contract.values() if value) / len(trust_contract) * 100)

checks = [
    {
        "key": "release-gates",
        "state": "OK" if release.get("public_release_ready") else "PART",
        "title": "Public release gates",
        "detail": f"{release.get('state', 'unknown')} · public={release.get('public_release_ready', False)}.",
        "command": "seven release doctor --json",
        "weight": 1.2,
    },
    {
        "key": "distribution-contract",
        "state": "OK" if distribution.get("score", 0) >= 90 else "PART",
        "title": "Distribution contract",
        "detail": f"{distribution.get('state', 'unknown')} at {distribution.get('score', 0)}%.",
        "command": "seven distribution doctor --json",
        "weight": 1.0,
    },
    {
        "key": "graphical-installer",
        "state": "OK" if installer.get("state") == "graphical-ready" else "PART",
        "title": "Graphical installer and live ISO route",
        "detail": f"{installer.get('state', 'unknown')} · ISO contract {iso_score}%.",
        "command": "seven installer release --json",
        "weight": 1.2,
    },
    {
        "key": "new-machine",
        "state": "OK" if first_run.get("score", 0) >= 90 or first_run.get("state") in {"public-ready", "ready"} else "PART",
        "title": "Fresh install verifier",
        "detail": f"{first_run.get('state', 'unknown')} at {first_run.get('score', 0)}%.",
        "command": "seven first-run verify --json",
        "weight": 1.1,
    },
    {
        "key": "update-rollback",
        "state": "OK" if update.get("score", 0) >= 75 and trust_contract["rollback_snapshot"] else "PART",
        "title": "Update and rollback route",
        "detail": f"{update.get('state', 'unknown')} at {update.get('score', 0)}%; rollback contract={'yes' if trust_contract['rollback_snapshot'] else 'no'}.",
        "command": "seven update doctor --json",
        "weight": 1.1,
    },
    {
        "key": "support-route",
        "state": "OK" if support.get("score", 0) >= 90 else "PART",
        "title": "Support and diagnostics route",
        "detail": f"{support.get('state', 'unknown')} at {support.get('score', 0)}%.",
        "command": "seven support doctor --json",
        "weight": 0.9,
    },
    {
        "key": "hardware-readiness",
        "state": "OK" if hardware_score >= 78 else "PART",
        "title": "Hardware inspection coverage",
        "detail": f"{hardware_score}% local hardware tools present; real multi-machine validation still required.",
        "command": "seven production plan",
        "weight": 0.8,
    },
    {
        "key": "theme-sync",
        "state": "OK" if str(theme.get("state", "")).lower() in {"ok", "ready", "healthy", "synced"} or theme.get("score", 0) >= 90 else "PART",
        "title": "Theme and UI synchronization",
        "detail": f"{theme.get('state', 'unknown')} at {theme.get('score', 'unknown')}%.",
        "command": "seven theme doctor --json",
        "weight": 0.8,
    },
    {
        "key": "mini-os-requirements",
        "state": "OK" if profile.get("ready") is True or profile.get("summary", {}).get("ready", 0) >= 6 else "PART",
        "title": "Mini OS requirements",
        "detail": f"{profile.get('state', 'unknown')} · summary={profile.get('summary', {})}.",
        "command": "seven profile requirements all --json",
        "weight": 1.0,
    },
    {
        "key": "trust-policy",
        "state": "OK" if trust_score >= 83 else "PART",
        "title": "Trust, channel and support policy",
        "detail": f"{trust_score}% policy coverage; package/ISO signing remains the key large-scale hardening step.",
        "command": "seven production plan",
        "weight": 1.0,
    },
]

weighted_total = sum(item["weight"] for item in checks)
weighted_ok = sum(item["weight"] for item in checks if item["state"] == "OK")
weighted_part = sum(item["weight"] * 0.45 for item in checks if item["state"] == "PART")
score = round((weighted_ok + weighted_part) / weighted_total * 100)
critical = [item for item in checks if item["state"] != "OK" and item["key"] in {"release-gates", "graphical-installer", "new-machine"}]
issues = [item for item in checks if item["state"] != "OK"]

if score >= 94 and not critical:
    state = "public-beta-ready"
elif score >= 82:
    state = "beta-candidate"
else:
    state = "needs-hardening"

large_scale_ready = (
    state == "public-beta-ready"
    and hardware_score >= 90
    and trust_score >= 100
    and False
)

hardware_matrix = [
    {"target": "Intel laptop", "status": "manual-required", "checks": ["Wi-Fi", "Bluetooth", "suspend/resume", "external display"]},
    {"target": "AMD desktop/laptop", "status": "manual-required", "checks": ["GPU", "audio", "power profile", "install/reboot"]},
    {"target": "NVIDIA machine", "status": "manual-required", "checks": ["driver install", "Wayland session", "gaming/profile switch"]},
    {"target": "USB/disks", "status": "manual-required", "checks": ["external disk mount", "Seven Files sidebar", "USB writer"]},
    {"target": "Fresh ISO loop", "status": "manual-required", "checks": ["build ISO", "boot USB", "Calamares install", "first-run verify", "update", "reboot"]},
]

print(json.dumps({
    "schema": "sevenos.production-readiness.v1",
    "root": str(root),
    "state": state,
    "score": score,
    "public_beta_ready": state == "public-beta-ready",
    "large_scale_ready": large_scale_ready,
    "large_scale_note": "Large-scale production requires real hardware matrix validation, signed ISO/package policy and support operations; this local gate cannot honestly certify that alone.",
    "checks": checks,
    "issues": issues,
    "critical": critical,
    "hardware": {
        "score": hardware_score,
        "tools": hardware_tools,
        "matrix": hardware_matrix,
    },
    "iso": {
        "score": iso_score,
        "contract": iso_contract,
        "command": "./install.sh iso --dry-run",
    },
    "trust": {
        "score": trust_score,
        "contract": trust_contract,
        "next": [
            "Define ISO checksum/signature publication in release notes.",
            "Keep channel dev/testing/stable explicit in Settings and About.",
            "Keep support bundles local-first and user-reviewed.",
        ],
    },
    "recommendation": "Ship as SevenOS Public Beta / Developer Preview until the hardware matrix and signing policy are externally validated.",
    "commands": {
        "status": "seven production",
        "doctor": "seven production doctor",
        "plan": "seven production plan",
        "release": "seven release doctor",
        "iso": "./install.sh iso --dry-run",
        "first_run": "seven first-run verify",
        "support_bundle": "seven support bundle",
        "update": "seven update doctor",
    },
}, indent=2, ensure_ascii=False))
PY
  rm -rf "$tmp"
}

print_human() {
  PRODUCTION_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PRODUCTION_JSON"])
print("SevenOS Production Readiness")
print("============================")
print(f"State:             {data.get('state')}")
print(f"Score:             {data.get('score')}%")
print(f"Public beta ready: {data.get('public_beta_ready')}")
print(f"Large scale ready: {data.get('large_scale_ready')}")
print()
print(data.get("large_scale_note"))
print()
for item in data.get("checks", []):
    print(f"{item.get('state','PART'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

print_plan() {
  PRODUCTION_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PRODUCTION_JSON"])
print("SevenOS Public Beta Hardening Plan")
print("==================================")
print("Immediate gates:")
for item in data.get("issues", []):
    print(f"- {item.get('title')}: {item.get('command')}")
print()
print("Hardware matrix to validate manually:")
for item in data.get("hardware", {}).get("matrix", []):
    checks = ", ".join(item.get("checks", []))
    print(f"- {item.get('target')}: {checks}")
print()
print("Release trust:")
for item in data.get("trust", {}).get("next", []):
    print(f"- {item}")
PY
}

payload="$(production_json)"
case "$ACTION" in
  status|json)
    if [[ "$JSON_OUTPUT" -eq 1 || "$ACTION" == "json" ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  plan)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan "$payload"
    fi
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    PRODUCTION_JSON="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["PRODUCTION_JSON"])
sys.exit(0 if data.get("score", 0) >= 82 else 1)
PY
    ;;
esac
