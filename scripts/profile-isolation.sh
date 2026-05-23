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
    "caddy.service": ["forge"],
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
    "equinox": ["seven", "seven-files", "seven-hub", "kitty", "python", "python3"],
    "baobab": ["seven", "seven-files", "seven-hub", "seven-reader", "foliate", "calibre", "ebook-viewer", "espeak-ng", "festival", "trans"],
    "forge": ["git", "gh", "node", "npm", "pnpm", "python", "pip", "pipx", "rustc", "cargo", "go", "docker", "docker-compose", "podman", "buildah", "skopeo", "caddy", "jq", "rsync", "ssh", "seven-deploy", "helix", "hx", "nvim", "code", "tmux", "make", "cmake", "ninja", "gcc", "clang", "lldb", "sqlite3", "psql", "valkey-server"],
    "shield": ["nmap", "wireshark", "tcpdump", "nc", "john", "hashcat", "hydra", "medusa", "sqlmap", "nikto", "msfconsole", "gobuster", "zaproxy", "masscan", "impacket-secretsdump", "whois", "dig", "traceroute", "openvpn", "wg", "binwalk", "volatility3", "yara", "sleuthkit", "foremost", "testdisk", "exiftool", "gdb", "strace", "ltrace", "radare2", "rizin", "cutter", "ghidra", "jadx", "afl-fuzz", "aircrack-ng", "bettercap", "ettercap", "macchanger", "firejail", "bwrap", "bandit"],
    "studio": ["gimp", "krita", "inkscape", "blender", "kdenlive", "obs", "obs-studio", "audacity", "ardour", "lmms", "darktable", "rawtherapee", "scribus", "magick", "ffmpeg", "handbrake"],
    "windows": ["wine", "winetricks", "lutris", "protontricks", "bottles", "virt-manager", "virt-install", "virt-viewer", "qemu-system-x86_64"],
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

profile_overlays = {
    key: {
        "upper": str(Path.home() / ".local/share/sevenos/profile-overlays" / key / "upper"),
        "work": str(Path.home() / ".local/share/sevenos/profile-overlays" / key / "work"),
        "merged": str(Path.home() / ".local/share/sevenos/profile-overlays" / key / "merged"),
        "state": "prepared",
        "selected": key in selected,
    }
    for key in profiles
}

profile_containers = {
    key: {
        "config": str(Path.home() / ".config/sevenos/profiles" / key),
        "home": str(Path.home() / ".local/share/sevenos/profile-containers" / key / "home"),
        "cache": str(Path.home() / ".local/share/sevenos/profile-containers" / key / "cache"),
        "data": str(Path.home() / ".local/share/sevenos/profile-containers" / key / "data"),
        "state": "prepared",
        "selected": key in selected,
        "launch_mode": "available-via-seven-profile-run-container",
        "exec": f"seven-profile-run --profile {key} --container <command>",
        "engine": "bubblewrap" if shutil.which("bwrap") else "planned",
    }
    for key in profiles
}

profile_workspace_names = {
    "equinox": "SevenOS",
    "baobab": "Baobab",
    "forge": "Forge",
    "shield": "ShieldLab",
    "studio": "Studio",
    "windows": "WindowsMode",
    "pulse": "Pulse",
}

manifest_root = Path.home() / ".local/share/sevenos/profile-runtime-manifests"
strict_runtime = {}
has_bwrap = shutil.which("bwrap") is not None
has_systemd_run = shutil.which("systemd-run") is not None
for key, item in profile_containers.items():
    score = 40
    if item.get("state") == "prepared":
        score += 20
    if has_bwrap:
        score += 25
    if has_systemd_run:
        score += 10
    if key in profiles:
        score += 5
    strict_runtime[key] = {
        "state": "ready" if has_bwrap else "partial",
        "score": min(score, 100),
        "engine": item.get("engine", "planned"),
        "app_data": "profile-home-cache-data",
        "workspace": "explicit-bind-only",
        "workspace_mount": "/workspace",
        "ephemeral": "available",
        "ephemeral_command": f"seven-profile-run --profile {key} --container --ephemeral <command>",
        "profile_workspace": str(Path.home() / profile_workspace_names.get(key, "SevenOS")),
        "profile_workspace_command": f"seven-profile-run --profile {key} --container --workspace-profile <command>",
        "manifest": str(manifest_root / f"{key}.json"),
        "manifest_command": f"seven-profile-run --profile {key} --manifest",
        "packages": "global-pacman-store",
        "runtime_scope": "systemd-user-scope" if has_systemd_run else "direct-process",
        "command": item.get("exec"),
        "selected": item.get("selected", False),
    }

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
        "runtime_manifests": str(manifest_root),
    },
    "activation_depth": {
        "current": "profile-scoped activation with global pacman store, per-profile config roots, command shims, prepared overlay roots and prepared bubblewrap HOME/cache/data roots",
        "commands": "inactive profile commands are routed through seven-profile-run and blocked unless selected",
        "services": "profile-owned services are allowed only for the selected runtime",
        "containers": "all mini OS config/HOME/cache/data roots are prepared; profile commands can run through seven-profile-run --profile <profile> --container with bubblewrap app-data isolation",
        "next": "mounted overlay package roots and CRIU rollback snapshots",
    },
    "profile_overlays": profile_overlays,
    "profile_containers": profile_containers,
    "strict_runtime": strict_runtime,
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
    manifest_root.mkdir(parents=True, exist_ok=True)
    for key in profiles:
        roots = profile_containers[key]
        for name in ("upper", "work", "merged"):
            (overlay_root / key / name).mkdir(parents=True, exist_ok=True)
        Path(roots.get("config", state_dir / "profiles" / key)).mkdir(parents=True, exist_ok=True)
        for name in ("home", "cache", "data"):
            (container_root / key / name).mkdir(parents=True, exist_ok=True)
        marker = container_root / key / "README.txt"
        if not marker.exists():
            marker.write_text(
                f"SevenOS isolated data root for the {key} mini OS.\n"
                f"Use `seven-profile-run --profile {key} --container <command>` to launch a command with this HOME/cache/data boundary.\n",
                encoding="utf-8",
            )
        workspace = Path.home() / profile_workspace_names.get(key, "SevenOS")
        manifest = {
            "schema": "sevenos.profile-runtime-manifest.v1",
            "profile": key,
            "selected": key in selected,
            "engine": roots.get("engine", "planned"),
            "roots": {
                "config": roots.get("config"),
                "home": roots.get("home"),
                "cache": roots.get("cache"),
                "data": roots.get("data"),
            },
            "workspace": {
                "default": str(workspace),
                "exists": workspace.is_dir(),
                "sandbox_path": "/workspace",
                "policy": "explicit-bind-only",
            },
            "commands": {
                "inspect": f"seven-profile-run --profile {key} --manifest",
                "strict_shell": f"seven profile exec {key} --container sh",
                "workspace_shell": f"seven profile exec {key} --container --workspace-profile sh",
                "ephemeral_shell": f"seven profile exec {key} --ephemeral sh",
                "run_app": f"seven profile exec {key} --container <command>",
            },
            "policy": {
                "packages": "global-pacman-store",
                "app_data": "profile-config-home-cache-data",
                "workspace": "explicit-bind-only",
                "ephemeral": "temporary-home-cache-data",
                "runtime": "systemd-user-scope" if has_systemd_run else "direct-process",
            },
        }
        write_text(manifest_root / f"{key}.json", json.dumps(manifest, indent=2) + "\n")

    runner = root / "bin" / "seven-profile-run"
    protected_commands = {
        "seven",
        "seven-files",
        "seven-hub",
        "kitty",
        "python",
        "python3",
        "env",
        "bash",
        "sh",
        "bwrap",
        "bubblewrap",
        "firejail",
    }
    for command in all_commands:
        if command in protected_commands:
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
    profile_doctor = {}
    for key, item in strict_runtime.items():
        profile_doctor[key] = {
            "state": item.get("state"),
            "score": item.get("score"),
            "container_root": "OK" if key in profile_containers else "MISS",
            "command": item.get("command"),
        }
    payload["doctor"] = {
        "catalog": "OK" if catalog_path.is_file() else "MISS",
        "bubblewrap": "OK" if shutil.which("bwrap") else "MISS",
        "systemd": "OK" if shutil.which("systemctl") else "MISS",
        "criu": "OK" if shutil.which("criu") else "MISS",
        "overlayfs": "OK" if Path("/proc/filesystems").read_text(encoding="utf-8", errors="ignore").find("overlay") >= 0 else "MISS",
        "runner": "OK" if (root / "bin" / "seven-profile-run").is_file() else "MISS",
        "state": "OK" if (state_dir / "profile-isolation.json").is_file() else "MISS",
        "profiles": profile_doctor,
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
print("Strict runtime:")
strict = data.get("strict_runtime", {})
for key in sorted(strict):
    item = strict[key]
    marker = "selected" if item.get("selected") else item.get("state", "ready")
    print(f"- {key:<8} {marker:<8} score={item.get('score', 0):>3}% {item.get('engine'):<10} {item.get('command')}")
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
