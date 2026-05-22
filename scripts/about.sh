#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS about contract

Usage:
  seven about [status|plan|json|doctor] [--json]
  ./scripts/about.sh [status|plan|json|doctor] [--json]

This is the public "About SevenOS" identity surface. It describes SevenOS as a
distribution product first, while keeping Arch/Hyprland/QEMU/pacman visible only
as technical foundations for advanced users.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|plan|json|doctor) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown about option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

about_json() {
  local tmp
  tmp="$(mktemp -d)"
  local pid_profile
  if [[ "${SEVENOS_ABOUT_FAST:-0}" == "1" ]]; then
    python - <<'PY' >"$tmp/profile.json" 2>/dev/null || printf '{}\n' >"$tmp/profile.json" &
import json
from pathlib import Path

path = Path.home() / ".config/sevenos/profile.json"
if path.is_file():
    print(path.read_text(encoding="utf-8"))
else:
    print(json.dumps({
        "key": "equinox",
        "title": "Equinox Balance",
        "short_label": "EQX",
        "role": "Balance",
        "accent_color": "#8B7CFF",
        "workspace": str(Path.home() / "SevenOS"),
    }))
PY
    pid_profile=$!
  else
    SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/bin/seven" profile current --json >"$tmp/profile.json" 2>/dev/null || printf '{}\n' >"$tmp/profile.json" &
    pid_profile=$!
  fi
  SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/channel.sh" json >"$tmp/channel.json" 2>/dev/null || printf '{}\n' >"$tmp/channel.json" &
  local pid_channel=$!
  SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/distribution.sh" json >"$tmp/distribution.json" 2>/dev/null || printf '{}\n' >"$tmp/distribution.json" &
  local pid_distribution=$!
  SEVENOS_DRY_RUN=0 timeout 8 "$ROOT_DIR/scripts/platform.sh" json >"$tmp/platform.json" 2>/dev/null || printf '{}\n' >"$tmp/platform.json" &
  local pid_platform=$!
  wait "$pid_profile" "$pid_channel" "$pid_distribution" "$pid_platform" || true

  SEVENOS_ROOT="$ROOT_DIR" \
  PROFILE_JSON="$tmp/profile.json" \
  CHANNEL_JSON="$tmp/channel.json" \
  DISTRIBUTION_JSON="$tmp/distribution.json" \
  PLATFORM_JSON="$tmp/platform.json" \
  python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def load_path(name):
    try:
        data = json.loads(Path(os.environ[name]).read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def first_existing(paths):
    for rel in paths:
        path = root / rel
        if path.exists():
            return str(path)
    return ""


profile = load_path("PROFILE_JSON")
channel = load_path("CHANNEL_JSON")
distribution = load_path("DISTRIBUTION_JSON")
platform = load_path("PLATFORM_JSON")

edition = "SevenOS Daily"
state = distribution.get("state", "unknown")
if state == "public-release-candidate":
    edition = "SevenOS Release Candidate"
elif profile.get("key") == "shield":
    edition = "SevenOS Shield"
elif profile.get("key") == "windows":
    edition = "SevenOS Windows Bridge"
elif profile.get("key") == "pulse":
    edition = "SevenOS Pulse"

checks = [
    {
        "key": "identity",
        "state": "OK" if (root / "branding/sevenos-release").exists() else "PART",
        "title": "SevenOS identity",
        "detail": "Public shell and release identity use SevenOS vocabulary.",
    },
    {
        "key": "profile",
        "state": "OK" if profile.get("key") else "PART",
        "title": "Active mini OS",
        "detail": profile.get("title", "Unknown active profile"),
    },
    {
        "key": "distribution",
        "state": "OK" if distribution.get("daily_driver_ready") else "PART",
        "title": "Distribution gate",
        "detail": f"{distribution.get('state', 'unknown')} at {distribution.get('score', 'unknown')}%.",
    },
    {
        "key": "channel",
        "state": "OK" if channel.get("schema") == "sevenos.release-channel.v1" else "PART",
        "title": "Release channel",
        "detail": f"{channel.get('channel', 'unknown')} / {channel.get('state', 'unknown')}.",
    },
    {
        "key": "platform",
        "state": "OK" if platform.get("state") == "masked" else "PART",
        "title": "Masked platform facade",
        "detail": f"{platform.get('state', 'unknown')}.",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
about_ready = ok == len(checks)

print(json.dumps({
    "schema": "sevenos.about.v1",
    "name": "SevenOS",
    "pretty_name": "SevenOS Linux",
    "edition": edition,
    "tagline": "Beyond the Desktop",
    "state": "ready" if about_ready else "partial",
    "about_ready": about_ready,
    "distribution_state": distribution.get("state", "unknown"),
    "daily_driver_ready": bool(distribution.get("daily_driver_ready")),
    "public_release_ready": bool(distribution.get("public_release_ready")),
    "release": {
        "channel": channel.get("channel", "unknown"),
        "state": channel.get("state", "unknown"),
        "branch": channel.get("branch", "unknown"),
        "commit": channel.get("commit", "unknown"),
        "dirty_count": channel.get("dirty_count", distribution.get("summary", {}).get("dirty_count", 0)),
    },
    "active_mini_os": {
        "key": profile.get("key", "unknown"),
        "title": profile.get("title", "Unknown"),
        "short_label": profile.get("short_label", ""),
        "role": profile.get("role", ""),
        "accent": profile.get("accent_color", profile.get("accent", "")),
        "workspace": profile.get("workspace", ""),
    },
    "product_layers": [
        "Seven Hub",
        "SevenOS Settings",
        "SevenStore",
        "Seven Files",
        "Seven Reader",
        "Seven Smart Window System",
        "Seven Mini OS Runtime",
        "Windows Bridge",
        "Shield Cybersecurity",
    ],
    "technical_foundations": [
        "Linux",
        "Arch package ecosystem",
        "Hyprland/Wayland",
        "systemd user services",
        "pacman/Flatpak/AUR backends",
        "QEMU/KVM/libvirt",
    ],
    "public_policy": [
        "Normal workflows should start from SevenOS surfaces.",
        "Backend names remain available for advanced users and diagnostics.",
        "Public release is blocked until installer, release freeze and graphical ISO gates pass.",
    ],
    "files": {
        "release": first_existing(["branding/sevenos-release", "archiso/profile/airootfs/etc/os-release"]),
        "distribution_doc": str(root / "docs/DISTRIBUTION_AUTONOMY.md"),
        "readme": str(root / "README.md"),
    },
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "commands": {
        "about": "seven about",
        "plan": "seven about plan",
        "doctor": "seven about doctor",
        "distribution": "seven distribution",
        "channel": "seven channel",
        "profile": "seven profile current",
        "settings": "seven settings general",
    },
}, indent=2))
PY
  rm -rf "$tmp"
}

print_human() {
  ABOUT_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["ABOUT_JSON"])
profile = data.get("active_mini_os", {})
release = data.get("release", {})
print("About SevenOS")
print("=============")
print(f"Name:           {data.get('pretty_name')}")
print(f"Edition:        {data.get('edition')}")
print(f"Tagline:        {data.get('tagline')}")
print(f"Mini OS:        {profile.get('title')} ({profile.get('short_label')})")
print(f"Distribution:   {data.get('distribution_state')}")
print(f"Daily driver:   {str(data.get('daily_driver_ready')).lower()}")
print(f"Public release: {str(data.get('public_release_ready')).lower()}")
print(f"Channel:        {release.get('channel')} / {release.get('state')}")
print(f"Commit:         {release.get('commit')} ({release.get('dirty_count')} dirty path(s))")
print()
print("Product layers:")
for item in data.get("product_layers", []):
    print(f"- {item}")
print()
print("Technical foundations:")
for item in data.get("technical_foundations", []):
    print(f"- {item}")
PY
}

print_plan() {
  ABOUT_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["ABOUT_JSON"])
issues = data.get("issues", [])
print("SevenOS About Plan")
print("==================")
print(f"State: {data.get('state', 'unknown')}")
print(f"Ready: {str(data.get('about_ready', False)).lower()}")
print()
if not issues:
    print("No About identity blockers.")
else:
    print("Next actions:")
    for item in issues:
        print(f"- {item.get('title', item.get('key', 'About check'))}")
        print(f"  {item.get('detail', '')}")
        command = data.get("commands", {}).get(item.get("key", ""), "seven about")
        print(f"  command: {command}")
PY
}

payload="$(about_json)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
else
  case "$ACTION" in
    status) print_human "$payload" ;;
    plan) print_plan "$payload" ;;
    doctor)
      print_human "$payload"
      ABOUT_JSON="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["ABOUT_JSON"])
sys.exit(0 if data.get("about_ready") and data.get("state") == "ready" else 1)
PY
      ;;
    json) print_human "$payload" ;;
  esac
fi
