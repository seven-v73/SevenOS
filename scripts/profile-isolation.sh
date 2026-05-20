#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
shift || true

JSON_OUTPUT=0
APPLY=0
YES=0
PRIMARY=""
CAPABILITIES=()

usage() {
  cat <<'EOF'
SevenOS Profile Isolation
=========================

Usage:
  seven profile isolation status [--json]
  seven profile isolation plan [profile] [capability ...] [--json]
  seven profile isolation apply [profile] [capability ...] [--yes] [--json]
  seven profile isolation doctor [--json]

This does not pretend pacman is per-profile. Instead it makes package
activation profile-aware: installed packages are global, while SevenOS exposes
only the active profile capabilities, writes runtime allowlists, generates app
shims, and starts/stops owned services according to the active LAPA runtime.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|plan|apply|doctor) ACTION="$1" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      if [[ -z "$PRIMARY" ]]; then
        PRIMARY="$1"
      else
        CAPABILITIES+=("$1")
      fi
      ;;
  esac
  shift
done

state_dir() {
  printf '%s/sevenos\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

active_profile() {
  local state_file
  state_file="$(state_dir)/profile.env"
  if [[ -f "$state_file" ]]; then
    # shellcheck disable=SC1090
    source "$state_file"
    printf '%s' "${SEVENOS_ACTIVE_PROFILE:-equinox}"
  else
    printf 'equinox'
  fi
}

runtime_capabilities() {
  local runtime_file
  runtime_file="$(state_dir)/runtime.json"
  if [[ -s "$runtime_file" ]]; then
    python - "$runtime_file" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    data = {}
for item in data.get("capabilities", []):
    if isinstance(item, dict) and item.get("key"):
        print(item["key"])
PY
  fi
}

[[ -n "$PRIMARY" ]] || PRIMARY="$(active_profile)"
if [[ "${#CAPABILITIES[@]}" -eq 0 && "$ACTION" == "status" ]]; then
  mapfile -t CAPABILITIES < <(runtime_capabilities)
fi

capabilities_json() {
  CAPABILITIES_PAYLOAD="$(printf '%s\n' "${CAPABILITIES[@]}")" python - <<'PY'
import json
import os
items = [line.strip() for line in os.environ.get("CAPABILITIES_PAYLOAD", "").splitlines() if line.strip()]
print(json.dumps(items))
PY
}

json_payload() {
  SEVENOS_ROOT="$ROOT_DIR" \
  ACTION="$ACTION" \
  PRIMARY="$PRIMARY" \
  CAPABILITIES_JSON="$(capabilities_json)" \
  APPLY="$APPLY" \
  YES="$YES" \
  DRY_RUN="${SEVENOS_DRY_RUN:-0}" \
  STATE_DIR="$(state_dir)" \
  python - <<'PY'
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
state_dir = Path(os.environ["STATE_DIR"])
catalog_path = root / "profiles" / "catalog.json"
action = os.environ.get("ACTION", "status")
primary = os.environ.get("PRIMARY") or "equinox"
capabilities = json.loads(os.environ.get("CAPABILITIES_JSON", "[]"))
apply_requested = os.environ.get("APPLY") == "1" or action == "apply"
yes = os.environ.get("YES") == "1"
dry_run = os.environ.get("DRY_RUN") == "1"

with catalog_path.open(encoding="utf-8") as handle:
    catalog = json.load(handle)

profiles = catalog.get("profiles", {})
core_package_files = catalog.get("core_package_files") or ["scripts/packages-base.txt"]
valid = [key for key in [primary, *capabilities] if key in profiles]
invalid = [key for key in [primary, *capabilities] if key and key not in profiles]
if not valid:
    valid = [catalog.get("default_profile", "equinox")]
primary = valid[0]
capabilities = []
for key in valid[1:]:
    if key != primary and key not in capabilities:
        capabilities.append(key)
selected = [primary, *capabilities]

def read_packages(relative_paths):
    packages = []
    for rel in relative_paths:
        path = root / rel
        if not path.is_file():
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            item = raw.split("#", 1)[0].strip()
            if item and item not in packages:
                packages.append(item)
    return packages

package_owners = {}
profile_packages = {}
optional_packages = {}
core_packages = read_packages(core_package_files)
for package in core_packages:
    package_owners.setdefault(package, []).append("sevenos-core")

for key, meta in profiles.items():
    required = read_packages(meta.get("package_files", []))
    optional = read_packages(meta.get("optional_package_files", []))
    profile_packages[key] = required
    optional_packages[key] = optional
    for package in required:
        package_owners.setdefault(package, []).append(key)
    for package in optional:
        package_owners.setdefault(package, []).append(f"{key}:optional")

active_packages = []
for package in core_packages:
    if package not in active_packages:
        active_packages.append(package)
for key in selected:
    for package in profile_packages.get(key, []):
        if package not in active_packages:
            active_packages.append(package)

inactive_packages = []
for package, owners in package_owners.items():
    owners_base = [owner.split(":", 1)[0] for owner in owners]
    if package in active_packages:
        continue
    if "sevenos-core" in owners_base:
        continue
    inactive_packages.append({"package": package, "owners": owners})

service_owners = {
    "NetworkManager.service": ["sevenos-core"],
    "bluetooth.service": ["sevenos-core"],
    "ufw.service": ["sevenos-core", "shield"],
    "docker.service": ["forge"],
    "postgresql.service": ["forge"],
    "valkey.service": ["forge"],
    "caddy.service": ["horizon"],
    "libvirtd.service": ["windows"],
    "virtqemud.service": ["windows"],
    "virtlogd.service": ["windows"],
    "gamemoded.service": ["pulse"],
}

selected_set = set(selected) | {"sevenos-core"}
service_policy = []
for service, owners in service_owners.items():
    allowed = bool(selected_set.intersection(owners))
    exists = shutil.which("systemctl") is not None and subprocess.run(
        ["systemctl", "list-unit-files", service, "--no-legend"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    ).stdout.strip() != ""
    service_policy.append({
        "service": service,
        "owners": owners,
        "allowed": allowed,
        "exists": exists,
        "desired": "enabled-or-unchanged" if allowed else "disabled-when-profile-inactive",
    })

profile_commands = {
    "equinox": ["seven", "seven-files", "seven-hub", "kitty"],
    "baobab": ["seven", "seven-files", "seven-hub", "seven-reader", "foliate", "calibre", "ebook-viewer", "espeak-ng", "festival", "trans"],
    "forge": ["git", "gh", "node", "npm", "pnpm", "python", "pip", "pipx", "rustc", "cargo", "go", "docker", "docker-compose", "helix", "hx", "nvim", "code", "tmux", "make", "cmake", "ninja", "gcc", "clang", "lldb", "sqlite3", "psql", "valkey-server"],
    "shield": ["nmap", "wireshark", "tcpdump", "nc", "john", "hashcat", "hydra", "medusa", "sqlmap", "nikto", "msfconsole", "gobuster", "zaproxy", "masscan", "impacket-secretsdump", "whois", "dig", "traceroute", "openvpn", "wg", "binwalk", "volatility3", "yara", "sleuthkit", "foremost", "testdisk", "exiftool", "gdb", "strace", "ltrace", "radare2", "rizin", "cutter", "ghidra", "jadx", "afl-fuzz", "aircrack-ng", "bettercap", "ettercap", "macchanger", "firejail", "bwrap", "bandit"],
    "studio": ["gimp", "krita", "inkscape", "blender", "kdenlive", "obs", "obs-studio", "audacity", "ardour", "lmms", "darktable", "rawtherapee", "scribus", "magick", "ffmpeg", "handbrake"],
    "windows": ["wine", "winetricks", "lutris", "protontricks", "bottles", "virt-manager", "virt-install", "virt-viewer", "qemu-system-x86_64"],
    "horizon": ["go", "podman", "buildah", "skopeo", "caddy", "jq", "rsync", "ssh", "seven-deploy"],
    "pulse": ["gamemoderun", "game-mode", "gamescope", "mangohud", "vulkaninfo", "lutris"],
}

active_commands = []
for command in profile_commands.get("equinox", []):
    if command not in active_commands:
        active_commands.append(command)
for key in selected:
    for command in profile_commands.get(key, []):
        if command not in active_commands:
            active_commands.append(command)

all_commands = []
for commands in profile_commands.values():
    for command in commands:
        if command not in all_commands:
            all_commands.append(command)

inactive_commands = [command for command in all_commands if command not in active_commands]

payload = {
    "schema": "sevenos.profile-isolation.v1",
    "model": "global-install-profile-activation",
    "generated_at": int(time.time()),
    "primary": primary,
    "capabilities": capabilities,
    "selected_profiles": selected,
    "invalid_profiles": invalid,
    "policy": {
        "pacman": "global package store",
        "sevenos": "profile-scoped activation, service policy, runtime slices, app shims",
        "rule": "Installed does not mean active. Profiles own capabilities; SevenOS activates only the selected runtime.",
    },
    "paths": {
        "state": str(state_dir / "profile-isolation.json"),
        "env": str(state_dir / "profile-isolation.env"),
        "active_packages": str(state_dir / "active-packages.txt"),
        "inactive_packages": str(state_dir / "inactive-packages.json"),
        "service_policy": str(state_dir / "profile-services.json"),
        "shims": str(Path.home() / ".local/share/sevenos/profile-shims"),
    },
    "activation_depth": {
        "current": "profile-scoped activation with global pacman store, per-profile command shims, prepared overlay roots and optional bubblewrap homes",
        "commands": "inactive profile commands are routed through seven-profile-run and blocked unless selected",
        "services": "profile-owned services are allowed only for the selected runtime",
        "containers": "profile commands can run with per-profile HOME/cache/data through seven-profile-run --container when bubblewrap is available",
        "next": "mounted overlay package roots and CRIU rollback snapshots",
    },
    "profile_overlays": {
        key: {
            "upper": str(Path.home() / ".local/share/sevenos/profile-overlays" / key / "upper"),
            "work": str(Path.home() / ".local/share/sevenos/profile-overlays" / key / "work"),
            "merged": str(Path.home() / ".local/share/sevenos/profile-overlays" / key / "merged"),
            "state": "planned" if key not in selected else "prepared",
        }
        for key in profiles
    },
    "profile_containers": {
        key: {
            "home": str(Path.home() / ".local/share/sevenos/profile-containers" / key / "home"),
            "cache": str(Path.home() / ".local/share/sevenos/profile-containers" / key / "cache"),
            "data": str(Path.home() / ".local/share/sevenos/profile-containers" / key / "data"),
            "state": "planned" if key not in selected else "prepared",
            "engine": "bubblewrap" if shutil.which("bwrap") else "planned",
        }
        for key in profiles
    },
    "core_package_files": core_package_files,
    "active_packages": active_packages,
    "active_package_count": len(active_packages),
    "inactive_packages": inactive_packages,
    "inactive_package_count": len(inactive_packages),
    "package_owners": package_owners,
    "service_policy": service_policy,
    "active_commands": active_commands,
    "inactive_commands": inactive_commands,
    "safe_execution": {
        "apply_requested": apply_requested,
        "yes": yes,
        "applied": False,
        "system_service_changes": [],
        "requires_sudo_for_system_services": True,
    },
}

def write_text(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")

def apply_state():
    shims_dir = Path.home() / ".local/share/sevenos/profile-shims"
    shims_dir.mkdir(parents=True, exist_ok=True)
    state_dir.mkdir(parents=True, exist_ok=True)
    for stale in shims_dir.iterdir():
        if stale.is_file() or stale.is_symlink():
            stale.unlink()

    write_text(state_dir / "profile-isolation.json", json.dumps(payload, indent=2) + "\n")
    write_text(state_dir / "profile-isolation.env", "\n".join([
        f'SEVENOS_ISOLATION_PRIMARY="{primary}"',
        f'SEVENOS_ISOLATION_CAPABILITIES="{",".join(capabilities)}"',
        f'SEVENOS_PROFILE_SHIMS="{shims_dir}"',
        "",
    ]))
    write_text(state_dir / "active-packages.txt", "\n".join(active_packages) + "\n")
    write_text(state_dir / "inactive-packages.json", json.dumps(inactive_packages, indent=2) + "\n")
    write_text(state_dir / "profile-services.json", json.dumps(service_policy, indent=2) + "\n")
    overlay_root = Path.home() / ".local/share/sevenos/profile-overlays"
    container_root = Path.home() / ".local/share/sevenos/profile-containers"
    for key in selected:
        for name in ("upper", "work", "merged"):
            (overlay_root / key / name).mkdir(parents=True, exist_ok=True)
        for name in ("home", "cache", "data"):
            (container_root / key / name).mkdir(parents=True, exist_ok=True)

    runner = root / "bin" / "seven-profile-run"
    for command in all_commands:
        if command in {"seven", "seven-files", "seven-hub", "kitty"}:
            continue
        shim = shims_dir / command
        shim.write_text(
            "#!/usr/bin/env bash\n"
            f"exec {runner} {command!r} \"$@\"\n",
            encoding="utf-8",
        )
        shim.chmod(0o755)

    changes = []
    if yes and shutil.which("systemctl"):
        for item in service_policy:
            if item["allowed"] or not item["exists"]:
                continue
            service = item["service"]
            result = subprocess.run(
                ["sudo", "-n", "systemctl", "disable", "--now", service],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            changes.append({
                "service": service,
                "command": f"sudo -n systemctl disable --now {service}",
                "returncode": result.returncode,
                "stderr": result.stderr.strip(),
            })
    payload["safe_execution"]["system_service_changes"] = changes
    payload["safe_execution"]["applied"] = True
    write_text(state_dir / "profile-isolation.json", json.dumps(payload, indent=2) + "\n")

if apply_requested and not dry_run:
    apply_state()
elif apply_requested and dry_run:
    payload["safe_execution"]["would_write"] = list(payload["paths"].values())
    payload["safe_execution"]["would_generate_shims"] = all_commands

if action == "doctor":
    payload["doctor"] = {
        "catalog": "OK" if catalog_path.is_file() else "MISS",
        "bubblewrap": "OK" if shutil.which("bwrap") else "MISS",
        "systemd": "OK" if shutil.which("systemctl") else "MISS",
        "criu": "OK" if shutil.which("criu") else "MISS",
        "overlayfs": "OK" if Path("/proc/filesystems").read_text(encoding="utf-8", errors="ignore").find("overlay") >= 0 else "MISS",
        "runner": "OK" if (root / "bin" / "seven-profile-run").is_file() else "MISS",
        "state": "OK" if (state_dir / "profile-isolation.json").is_file() else "MISS",
    }

print(json.dumps(payload, indent=2))
PY
}

print_human() {
  ISOLATION_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["ISOLATION_JSON"])
print("SevenOS Profile Isolation")
print("=========================")
print(f"model:    {data.get('model')}")
print(f"primary:  {data.get('primary')}")
print(f"caps:     {', '.join(data.get('capabilities') or []) or 'none'}")
print(f"packages: {data.get('active_package_count')} active · {data.get('inactive_package_count')} inactive/profile-owned")
print()
print("Policy:")
print(f"- pacman:  {data['policy']['pacman']}")
print(f"- SevenOS: {data['policy']['sevenos']}")
print()
print("Service policy:")
for item in data.get("service_policy", []):
    marker = "allow" if item.get("allowed") else "quiet"
    exists = "exists" if item.get("exists") else "missing"
    print(f"- {item['service']:<20} {marker:<5} {exists:<7} owners={','.join(item.get('owners', []))}")
print()
print("State paths:")
for key, value in data.get("paths", {}).items():
    print(f"- {key}: {value}")
safe = data.get("safe_execution", {})
if safe.get("applied"):
    print("\nApplied: profile activation policy is written.")
elif safe.get("apply_requested"):
    print("\nPreview: add --yes outside dry-run to apply service quieting.")
PY
}

payload="$(json_payload)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
else
  print_human "$payload"
fi
