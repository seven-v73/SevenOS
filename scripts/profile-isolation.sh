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

host_home() {
  local home="${SEVENOS_HOST_HOME:-$HOME}"
  if [[ -n "${SEVENOS_HOST_HOME:-}" ]]; then
    printf '%s\n' "$home"
    return 0
  fi
  case "$home" in
    */.local/share/sevenos/profile-containers/*/home)
      printf '%s\n' "${home%%/.local/share/sevenos/profile-containers/*}"
      return 0
      ;;
  esac
  if [[ -n "${USER:-}" && -d "/home/$USER" ]]; then
    printf '/home/%s\n' "$USER"
  else
    printf '%s\n' "$home"
  fi
}

HOST_HOME="$(host_home)"
HOST_CONFIG_HOME="${SEVENOS_HOST_CONFIG_HOME:-$HOST_HOME/.config}"

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
  printf '%s/sevenos\n' "$HOST_CONFIG_HOME"
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
  HOST_HOME="$HOST_HOME" \
  python - <<'PY'
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
state_dir = Path(os.environ["STATE_DIR"])
host_home = Path(os.environ["HOST_HOME"])
SYSTEM_PROFILE = "equinox"
catalog_path = root / "profiles" / "catalog.json"
action = os.environ.get("ACTION", "status")
primary = os.environ.get("PRIMARY") or "equinox"
capabilities = json.loads(os.environ.get("CAPABILITIES_JSON", "[]"))
apply_requested = os.environ.get("APPLY") == "1" or action == "apply"
yes = os.environ.get("YES") == "1"
dry_run = os.environ.get("DRY_RUN") == "1"
global_package_policy_path = state_dir / "global-package-policy.json"

with catalog_path.open(encoding="utf-8") as handle:
    catalog = json.load(handle)

def load_global_package_policy():
    if not global_package_policy_path.is_file():
        return {"schema": "sevenos.global-package-policy.v1", "packages": {}}
    try:
        with global_package_policy_path.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {"schema": "sevenos.global-package-policy.v1", "packages": {}}
    data.setdefault("schema", "sevenos.global-package-policy.v1")
    data.setdefault("packages", {})
    return data

global_package_policy = load_global_package_policy()

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
system_selected = primary == SYSTEM_PROFILE

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
package_profile_scope = profiles if system_selected else selected
for key in package_profile_scope:
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
    "gamemoded.service": ["pulse"],
}

selected_set = (set(profiles) if system_selected else set(selected)) | {"sevenos-core"}
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
    active = False
    enabled = False
    if exists and shutil.which("systemctl"):
        active = subprocess.run(
            ["systemctl", "is-active", "--quiet", service],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0
        enabled = subprocess.run(
            ["systemctl", "is-enabled", "--quiet", service],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0
    service_policy.append({
        "service": service,
        "owners": owners,
        "allowed": allowed,
        "exists": exists,
        "active": active,
        "enabled": enabled,
        "desired": "enabled-or-unchanged" if allowed else "disabled-when-profile-inactive",
        "state": "OK" if allowed or not active else "WARN",
        "quiet_command": f"sudo -n systemctl disable --now {service}",
    })

profile_commands = {
    "equinox": ["seven", "seven-files", "seven-hub", "seven-mini-os-center", "seven-terminal", "kitty", "python", "python3"],
    "baobab": ["seven", "seven-files", "seven-hub", "seven-reader", "foliate", "calibre", "ebook-viewer", "espeak-ng", "festival", "trans"],
    "forge": ["git", "gh", "node", "npm", "pnpm", "python", "pip", "pipx", "rustc", "cargo", "go", "docker", "docker-compose", "podman", "buildah", "skopeo", "caddy", "jq", "rsync", "ssh", "seven-deploy", "helix", "hx", "nvim", "code", "tmux", "make", "cmake", "ninja", "gcc", "clang", "lldb", "sqlite3", "psql", "valkey-server"],
    "shield": ["nmap", "wireshark", "tcpdump", "nc", "john", "hashcat", "hydra", "medusa", "sqlmap", "nikto", "msfconsole", "gobuster", "zaproxy", "masscan", "impacket-secretsdump", "whois", "dig", "traceroute", "openvpn", "wg", "binwalk", "volatility3", "yara", "sleuthkit", "foremost", "testdisk", "exiftool", "gdb", "strace", "ltrace", "radare2", "rizin", "cutter", "ghidra", "jadx", "afl-fuzz", "aircrack-ng", "bettercap", "ettercap", "macchanger", "firejail", "bwrap", "bandit"],
    "studio": ["gimp", "krita", "inkscape", "blender", "kdenlive", "obs", "obs-studio", "audacity", "ardour", "lmms", "darktable", "rawtherapee", "scribus", "magick", "ffmpeg", "handbrake"],
    "atlas": ["evince", "foliate", "calibre", "marble", "tesseract", "ocrmypdf", "kiwix-desktop"],
    "pulse": ["gamemoderun", "game-mode", "gamescope", "mangohud", "vulkaninfo", "lutris"],
}
global_package_commands = ["pacman", "paru", "yay", "makepkg"]

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
for command in global_package_commands:
    if command not in all_commands:
        all_commands.append(command)

if system_selected:
    active_commands = list(all_commands)
inactive_commands = [command for command in all_commands if command not in active_commands]

profile_overlays = {
    key: {
        "upper": str(host_home / ".local/share/sevenos/profile-overlays" / key / "upper"),
        "work": str(host_home / ".local/share/sevenos/profile-overlays" / key / "work"),
        "merged": str(host_home / ".local/share/sevenos/profile-overlays" / key / "merged"),
        "state": "prepared",
        "selected": key in selected,
    }
    for key in profiles
}

profile_containers = {
    key: {
        "config": str(host_home / ".config/sevenos/profiles" / key),
        "home": str(host_home / ".local/share/sevenos/profile-containers" / key / "home"),
        "cache": str(host_home / ".local/share/sevenos/profile-containers" / key / "cache"),
        "data": str(host_home / ".local/share/sevenos/profile-containers" / key / "data"),
        "rootfs": str(host_home / ".local/share/sevenos/profile-rootfs" / key / "rootfs"),
        "state": "prepared",
        "selected": key in selected,
        "launch_mode": "available-via-seven-profile-run-container",
        "exec": f"seven-profile-run --profile {key} --container <command>",
        "engine": "bubblewrap" if shutil.which("bwrap") else "planned",
    }
    for key in profiles
}
if SYSTEM_PROFILE in profile_containers:
    profile_containers[SYSTEM_PROFILE].update({
        "config": str(host_home / ".config"),
        "home": str(host_home),
        "cache": str(host_home / ".cache"),
        "data": str(host_home / ".local/share"),
        "rootfs": "host-system",
        "state": "system",
        "launch_mode": "host-system",
        "exec": "host-direct",
        "engine": "host",
    })

profile_workspace_names = {
    "equinox": "SevenOS",
    "baobab": "Baobab",
    "forge": "Forge",
    "shield": "ShieldLab",
    "studio": "Studio",
    "atlas": "Atlas",
    "pulse": "Pulse",
}

profile_isolation_modes = {
    "equinox": "system",
    "baobab": "balanced",
    "forge": "balanced",
    "shield": "strict",
    "studio": "balanced",
    "atlas": "balanced",
    "pulse": "balanced",
}
profile_balanced_overrides = {
    "baobab": {
        "gpu": "blocked-by-default",
        "dev": "minimal",
        "reason": "culture, reading and narration do not need broad device/GPU access by default",
    },
    "forge": {
        "gpu": "blocked-by-default",
        "dev": "minimal",
        "audio": "blocked-by-default",
        "reason": "development keeps network/runtime access but does not need broad media devices by default",
    },
}

manifest_root = host_home / ".local/share/sevenos/profile-runtime-manifests"
strict_runtime = {}
has_bwrap = shutil.which("bwrap") is not None
has_systemd_run = shutil.which("systemd-run") is not None
for key, item in profile_containers.items():
    if key == SYSTEM_PROFILE:
        strict_runtime[key] = {
            "state": "system",
            "score": 100,
            "engine": "host",
            "app_data": "host-home-cache-data",
            "workspace": "host-home",
            "workspace_mount": "native",
            "ephemeral": "not-used-for-system-profile",
            "ephemeral_command": f"seven-profile-run --profile {key} <command>",
            "profile_workspace": str(host_home / profile_workspace_names.get(key, "SevenOS")),
            "profile_workspace_command": f"seven-profile-run --profile {key} --workspace-profile <command>",
            "manifest": str(manifest_root / f"{key}.json"),
            "manifest_command": f"seven-profile-run --profile {key} --manifest",
            "packages": "global-pacman-store",
            "rootfs": "host-system",
            "rootfs_state": "not-applicable",
            "isolation_mode": "system",
            "isolation_policy": {
                "system": "admin host runtime with real HOME, normal PATH, and global package manager access",
                "balanced": "used by other daily mini OSes",
                "strict": "used by Shield and explicit strict launches",
                "independent": "used by explicit profile rootfs launches",
            },
            "runtime_scope": "host-process",
            "command": "host-direct",
            "selected": item.get("selected", False),
        }
        continue
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
        "profile_workspace": str(host_home / profile_workspace_names.get(key, "SevenOS")),
        "profile_workspace_command": f"seven-profile-run --profile {key} --container --workspace-profile <command>",
        "manifest": str(manifest_root / f"{key}.json"),
        "manifest_command": f"seven-profile-run --profile {key} --manifest",
        "packages": "global-pacman-store",
        "rootfs": item.get("rootfs"),
        "rootfs_state": "ready" if (Path(item.get("rootfs", "")) / "usr/bin").is_dir() else "prepared",
        "isolation_mode": profile_isolation_modes.get(key, "balanced"),
        "isolation_policy": {
            "balanced": "shared runtime, host GPU/dev/network for graphical daily apps",
            "strict": "network namespace, minimal /dev, no runtime dir or DBus by default",
            "independent": "sealed read-only profile rootfs plus profile HOME/cache/data, no VM",
        },
        "balanced_overrides": profile_balanced_overrides.get(key, {}),
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
        "global_package_commands": "raw pacman/AUR helpers are direct in Equinox and guarded by SevenOS profile shims in other mini OS terminals and profiled launchers",
        "system_profile": f"{SYSTEM_PROFILE} is the host admin OS: real HOME, normal PATH, and direct Arch package manager access",
    },
    "shared_foundations": {
        "kernel": "shared host kernel; not a VM boundary",
        "compositor": "shared Hyprland/Wayland session with SevenOS profile routing",
        "gpu": "shared hardware; foreground/profile policy controls access, not hardware partitioning",
        "network": "shared host network by default; strict profiles can use bubblewrap network namespace",
        "package_store": "pacman database remains physically global; profile views and rootfs seals define SevenOS boundaries",
    },
    "paths": {
        "state": str(state_dir / "profile-isolation.json"),
        "env": str(state_dir / "profile-isolation.env"),
        "active_packages": str(state_dir / "active-packages.txt"),
        "inactive_packages": str(state_dir / "inactive-packages.json"),
        "global_package_policy": str(global_package_policy_path),
        "service_policy": str(state_dir / "profile-services.json"),
        "shims": str(host_home / ".local/share/sevenos/profile-shims"),
        "desktop_overrides": str(host_home / ".local/share/applications"),
        "package_views": str(host_home / ".local/share/sevenos/profile-package-views"),
        "rootfs": str(host_home / ".local/share/sevenos/profile-rootfs"),
        "runtime_manifests": str(manifest_root),
    },
    "activation_depth": {
        "current": "Equinox host-system activation plus profile-scoped activation for other mini OSes with global pacman store, per-profile package views, command shims, prepared overlay roots and prepared bubblewrap HOME/cache/data roots",
        "commands": "Equinox can see all host commands; inactive profile commands are hidden from non-system profile package views, routed through seven-profile-run and blocked unless selected",
        "services": "Equinox can administer all profile services; profile-owned services are otherwise allowed only for the selected runtime",
        "containers": "Equinox runs on the host; other mini OS config/HOME/cache/data roots are prepared and run through seven-profile-run --profile <profile> --container with bubblewrap app-data isolation",
        "next": "profile rootfs build for full per-mini-OS package installation",
    },
    "profile_overlays": profile_overlays,
    "profile_containers": profile_containers,
    "strict_runtime": strict_runtime,
    "core_package_files": core_package_files,
    "active_packages": active_packages,
    "active_package_count": len(active_packages),
    "inactive_packages": inactive_packages,
    "inactive_package_count": len(inactive_packages),
    "global_package_policy": global_package_policy,
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
        "sudo_noninteractive": shutil.which("sudo") is not None and subprocess.run(
            ["sudo", "-n", "true"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0,
    },
    "strict_boundaries": {
        "launcher": "seven-profile-launch",
        "desktop_apps": "Equinox launches host apps directly; other mini OS apps use the active profile container by default",
        "shims": "Equinox shims fall through to host commands; other profile shims route through seven-profile-run --container",
        "workspace": "mounted only as /workspace for profile launches",
        "implicit_capability_borrowing": False,
        "rootfs": "prepared per profile; used by seven-profile-run --rootfs when built",
        "isolation_modes": "balanced by default, strict for Shield, explicit --isolation strict|vm available",
        "package_manager_guard": "pacman/paru/yay/makepkg are direct in Equinox and guarded in other mini OS sessions",
    },
}

def write_text(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")

def desktop_quote(value):
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'

def read_desktop_entry(path):
    data = {}
    in_entry = False
    try:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        return data
    for line in lines:
        raw = line.strip()
        if raw == "[Desktop Entry]":
            in_entry = True
            continue
        if in_entry and raw.startswith("[") and raw.endswith("]"):
            break
        if not in_entry or not raw or raw.startswith("#") or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        data[key.strip()] = value.strip()
    return data

def exec_command_name(exec_line):
    if not exec_line:
        return ""
    try:
        parts = shlex.split(exec_line)
    except ValueError:
        parts = exec_line.split()
    if not parts:
        return ""
    first = parts[0]
    if "=" in first and not first.startswith("/"):
        for item in parts:
            if "=" not in item or item.startswith("/"):
                first = item
                break
    return Path(first).name

def generate_desktop_overrides():
    launcher = root / "bin" / "seven-profile-launch"
    if not launcher.is_file():
        return []
    override_root = host_home / ".local/share/applications"
    override_root.mkdir(parents=True, exist_ok=True)
    for stale in override_root.glob("*.desktop"):
        try:
            text = stale.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        if "X-SevenOS-Profiled=true" in text:
            stale.unlink()
    search_roots = [
        Path("/usr/share/applications"),
        Path("/usr/local/share/applications"),
        override_root,
    ]
    generated = []
    protected = {
        "seven-profile-launch", "seven-profile-run", "seven",
        "seven-terminal", "seven-files", "seven-hub", "kitty",
        "python", "python3", "hyprctl", "notify-send", "xdg-open", "gio", "gtk-launch",
    }
    for base in search_roots:
        if not base.is_dir():
            continue
        for desktop in sorted(base.glob("*.desktop")):
            if desktop.name.startswith("sevenos-profiled-"):
                continue
            entry = read_desktop_entry(desktop)
            if entry.get("Type", "Application") != "Application":
                continue
            command = exec_command_name(entry.get("Exec", ""))
            if not command or command in protected or command not in all_commands:
                continue
            target = override_root / desktop.name
            if target.resolve() == desktop.resolve():
                continue
            keep_keys = [
                "Name", "GenericName", "Comment", "Icon", "Terminal", "Type",
                "Categories", "Keywords", "StartupNotify", "StartupWMClass",
                "NoDisplay", "MimeType",
            ]
            lines = [
                "[Desktop Entry]",
                "Type=Application",
                f"Name={entry.get('Name') or desktop.stem}",
                f"Exec={desktop_quote(launcher)} {desktop_quote(desktop.name)} {desktop_quote(desktop)}",
            ]
            for key in keep_keys:
                if key in {"Name", "Type"}:
                    continue
                value = entry.get(key)
                if value is not None:
                    lines.append(f"{key}={value}")
            lines.extend([
                "X-SevenOS-Profiled=true",
                f"X-SevenOS-OriginalDesktop={desktop}",
                "",
            ])
            target.write_text("\n".join(lines), encoding="utf-8")
            generated.append(str(target))
    return generated

def generate_profile_launchers():
    launcher_root = host_home / ".local/share/applications"
    launcher_root.mkdir(parents=True, exist_ok=True)
    runner = root / "bin" / "seven-profile-run"
    generated = []
    launcher_specs = {
        "equinox": ("Equinox Balance", "SevenOS balanced workspace", "sevenos"),
        "baobab": ("Baobab Cultural OS", "African culture, heritage and language workspace", "seven-baobab"),
        "forge": ("Forge DevOps", "Code, containers, services and deployment workspace", "utilities-terminal"),
        "shield": ("Shield Cybersecurity", "Audit, forensics and sandbox workspace", "seven-security"),
        "studio": ("Studio Creator", "Media, design and asset production workspace", "seven-studio"),
        "atlas": ("Atlas Explorer", "Research, maps and document navigation workspace", "applications-science"),
        "pulse": ("Pulse Gaming", "Gaming, performance and controller workspace", "applications-games"),
    }
    for key in profiles:
        title, comment, icon = launcher_specs.get(key, (profiles[key].get("title", key.title()), f"{key} mini OS", "sevenos"))
        center = profiles[key].get("center_command") or f"seven-mini-os-center {key}"
        center_parts = shlex.split(center)
        if key == SYSTEM_PROFILE:
            center_exec = " ".join(desktop_quote(part) for part in center_parts)
            terminal_exec = " ".join(["seven-terminal", desktop_quote(key)])
            launch_mode = "host-system"
            terminal_comment = f"Open the system terminal for {title}"
        else:
            center_exec = " ".join([desktop_quote(str(runner)), "--profile", desktop_quote(key), "--container", "--workspace-profile", *[desktop_quote(part) for part in center_parts]])
            terminal_exec = " ".join([desktop_quote(str(runner)), "--profile", desktop_quote(key), "--container", "--workspace-profile", "seven-terminal", desktop_quote(key)])
            launch_mode = "strict-container"
            terminal_comment = f"Open an isolated terminal for {title}"
        entries = {
            f"sevenos-mini-{key}.desktop": [
                "[Desktop Entry]",
                "Type=Application",
                f"Name={title}",
                f"Comment={comment}",
                f"Exec={center_exec}",
                f"Icon={icon}",
                "Terminal=false",
                "Categories=System;SevenOS;",
                "StartupNotify=true",
                "X-SevenOS-Profiled=true",
                f"X-SevenOS-Profile={key}",
                f"X-SevenOS-LaunchMode={launch_mode}",
                "",
            ],
            f"sevenos-mini-{key}-terminal.desktop": [
                "[Desktop Entry]",
                "Type=Application",
                f"Name={title} Terminal",
                f"Comment={terminal_comment}",
                f"Exec={terminal_exec}",
                "Icon=utilities-terminal",
                "Terminal=false",
                "Categories=System;TerminalEmulator;SevenOS;",
                "StartupNotify=true",
                "X-SevenOS-Profiled=true",
                f"X-SevenOS-Profile={key}",
                f"X-SevenOS-LaunchMode={launch_mode}",
                "",
            ],
        }
        for name, lines in entries.items():
            path = launcher_root / name
            path.write_text("\n".join(lines), encoding="utf-8")
            generated.append(str(path))
    return generated

def archive_legacy_aliases():
    archived = []
    aliases = {"horizon": "forge"}
    container_root = host_home / ".local/share/sevenos/profile-containers"
    archive_root = container_root / "_legacy"
    for alias, target in aliases.items():
        source = container_root / alias
        target_root = container_root / target
        if not source.exists() or not target_root.exists():
            continue
        archive_root.mkdir(parents=True, exist_ok=True)
        stamp = time.strftime("%Y%m%d-%H%M%S")
        destination = archive_root / f"{alias}-to-{target}-{stamp}"
        try:
            source.rename(destination)
            archived.append({"alias": alias, "target": target, "archived_to": str(destination)})
        except OSError as exc:
            archived.append({"alias": alias, "target": target, "error": str(exc)})
    return archived

def generate_package_views():
    view_root = host_home / ".local/share/sevenos/profile-package-views"
    view_root.mkdir(parents=True, exist_ok=True)
    generated = {}
    base_path = os.pathsep.join(
        item for item in os.environ.get("PATH", "").split(os.pathsep)
        if item and "profile-shims" not in item and "profile-package-views" not in item
    )
    core_commands = set(profile_commands.get(SYSTEM_PROFILE, []))
    for key in profiles:
        bin_dir = view_root / key / "bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        for stale in bin_dir.iterdir():
            if stale.is_symlink() or stale.is_file():
                stale.unlink()
        exposed = []
        policy_exposed = []
        command_scope = set(all_commands) if key == SYSTEM_PROFILE else core_commands | set(profile_commands.get(key, []))
        if key != SYSTEM_PROFILE:
            for package, entry in global_package_policy.get("packages", {}).items():
                if entry.get("visibility") != "exposed":
                    continue
                targets = entry.get("profiles", [])
                if "*" not in targets and key not in targets:
                    continue
                for command in entry.get("commands", []):
                    if command:
                        command_scope.add(command)
                        policy_exposed.append({"package": package, "command": command})
        for command in sorted(command_scope):
            resolved = str(root / "bin" / command) if command.startswith("seven") and (root / "bin" / command).is_file() else None
            if not resolved:
                resolved = shutil.which(command, path=base_path)
            if not resolved and (root / "bin" / command).is_file():
                resolved = str(root / "bin" / command)
            if not resolved:
                continue
            target = bin_dir / command
            try:
                target.symlink_to(resolved)
                exposed.append(command)
            except FileExistsError:
                pass
            except OSError:
                continue
        generated[key] = {
            "bin": str(bin_dir),
            "commands": exposed,
            "command_count": len(exposed),
            "global_policy_commands": policy_exposed,
            "policy": "profile-owned command view over the global pacman store",
        }
    return generated

def apply_state():
    shims_dir = host_home / ".local/share/sevenos/profile-shims"
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
        f'SEVENOS_PACKAGE_VIEW="{"" if primary == SYSTEM_PROFILE else host_home / ".local/share/sevenos/profile-package-views" / primary / "bin"}"',
        f'SEVENOS_PROFILE_STRICT_LAUNCH="{"0" if primary == SYSTEM_PROFILE else "1"}"',
        "",
    ]))
    write_text(state_dir / "active-packages.txt", "\n".join(active_packages) + "\n")
    write_text(state_dir / "inactive-packages.json", json.dumps(inactive_packages, indent=2) + "\n")
    write_text(state_dir / "profile-services.json", json.dumps(service_policy, indent=2) + "\n")
    overlay_root = host_home / ".local/share/sevenos/profile-overlays"
    container_root = host_home / ".local/share/sevenos/profile-containers"
    manifest_root.mkdir(parents=True, exist_ok=True)
    for key in profiles:
        roots = profile_containers[key]
        for name in ("upper", "work", "merged"):
            (overlay_root / key / name).mkdir(parents=True, exist_ok=True)
        if key == SYSTEM_PROFILE:
            for path in (host_home / ".config", host_home / ".cache", host_home / ".local/share"):
                path.mkdir(parents=True, exist_ok=True)
        else:
            Path(roots.get("config", state_dir / "profiles" / key)).mkdir(parents=True, exist_ok=True)
            for name in ("home", "cache", "data"):
                (container_root / key / name).mkdir(parents=True, exist_ok=True)
            rootfs_root = Path(roots.get("rootfs") or host_home / ".local/share/sevenos/profile-rootfs" / key / "rootfs")
            for path in (rootfs_root, rootfs_root / "etc", rootfs_root / "profile"):
                path.mkdir(parents=True, exist_ok=True)
            (rootfs_root / "etc/sevenos-profile").write_text(key + "\n", encoding="utf-8")
            marker = container_root / key / "README.txt"
            if not marker.exists():
                marker.write_text(
                    f"SevenOS isolated data root for the {key} mini OS.\n"
                    f"Use `seven-profile-run --profile {key} --container <command>` to launch a command with this HOME/cache/data boundary.\n",
                    encoding="utf-8",
                )
        workspace = host_home / profile_workspace_names.get(key, "SevenOS")
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
                "rootfs": roots.get("rootfs"),
                "isolation_mode": profile_isolation_modes.get(key, "balanced"),
            },
            "workspace": {
                "default": str(workspace),
                "exists": workspace.is_dir(),
                "sandbox_path": "native" if key == SYSTEM_PROFILE else "/workspace",
                "policy": "host-home" if key == SYSTEM_PROFILE else "explicit-bind-only",
            },
            "commands": {
                "inspect": f"seven-profile-run --profile {key} --manifest",
                "strict_shell": f"seven profile exec {key} --container sh",
                "workspace_shell": f"seven profile exec {key} --container --workspace-profile sh",
                "ephemeral_shell": f"seven profile exec {key} --ephemeral sh",
                "run_app": f"seven profile exec {key} --container <command>",
                "independent_shell": f"seven profile exec {key} --independent sh",
                "independent_app": f"seven profile exec {key} --independent <command>",
                "rootfs_shell": f"seven profile exec {key} --rootfs sh",
                "strict_rootfs_shell": f"seven profile exec {key} --rootfs --isolation strict sh",
            },
            "policy": {
                "packages": "global-pacman-store direct access" if key == SYSTEM_PROFILE else "global-pacman-store with profile package view; rootfs available after seven profile-rootfs build",
                "app_data": "host-home-cache-data" if key == SYSTEM_PROFILE else "profile-config-home-cache-data",
                "rootfs": "not-applicable" if key == SYSTEM_PROFILE else "prepared",
                "native_independence": "system admin profile uses the host directly" if key == SYSTEM_PROFILE else "sealed read-only profile rootfs plus profile HOME/cache/data; no VM required",
                "isolation": profile_isolation_modes.get(key, "balanced"),
                "balanced_overrides": profile_balanced_overrides.get(key, {}),
                "workspace": "host-home" if key == SYSTEM_PROFILE else "explicit-bind-only",
                "ephemeral": "not-used-for-system-profile" if key == SYSTEM_PROFILE else "temporary-home-cache-data",
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
        if command in global_package_commands:
            shim.write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                f"real=\"/usr/bin/{command}\"\n"
                "[[ -x \"$real\" ]] || real=\"$(command -v " + command + " || true)\"\n"
                "[[ -n \"$real\" && \"$real\" != \"$0\" ]] || { printf '[SevenOS] backend missing for " + command + "\\n' >&2; exit 127; }\n"
                "if [[ \"${SEVENOS_ALLOW_GLOBAL_PACKAGES:-0}\" == \"1\" ]]; then\n"
                "  exec \"$real\" \"$@\"\n"
                "fi\n"
                "case \" ${*:-} \" in\n"
                "  *' -Q'*|*' --query '*|*' -Si '*|*' -Ss '*|*' --sync --search '*|*' --sync --info '*) exec \"$real\" \"$@\" ;;\n"
                "esac\n"
                f"profile=\"$(sed -n 's/^SEVENOS_ACTIVE_PROFILE=//p' {shlex.quote(str(state_dir / 'profile.env'))} 2>/dev/null | head -1 | tr -d '\"' || true)\"\n"
                "profile=\"${profile:-${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_ISOLATION_PRIMARY:-equinox}}}\"\n"
                "if [[ \"$profile\" == \"equinox\" || \"${SEVENOS_SYSTEM_PROFILE:-0}\" == \"1\" ]]; then\n"
                "  exec \"$real\" \"$@\"\n"
                "fi\n"
                "case \" ${*:-} \" in\n"
                "  *' -S '*|*' --sync '*|*' -U '*|*' --upgrade '*|*' -R '*|*' --remove '*|*' -i '*|*' --install '*)\n"
                "    if [[ -t 0 && -t 1 && \"${SEVENOS_PACKAGE_GUARD:-confirm}\" == \"confirm\" ]]; then\n"
                f"      printf '[SevenOS] {command} will modify the global Arch package store, not only the %s mini OS.\\n' \"$profile\" >&2\n"
                "      printf '[SevenOS] Continue? [y/N] ' >&2\n"
                "      read -r answer\n"
                "      case \"$answer\" in y|Y|yes|YES|oui|OUI) exec \"$real\" \"$@\" ;; esac\n"
                "      printf '[SevenOS] Cancelled. Use SevenStore/sevenpkg or rerun with SEVENOS_ALLOW_GLOBAL_PACKAGES=1.\\n' >&2\n"
                "      exit 126\n"
                "    fi\n"
                "    ;;\n"
                "esac\n"
                f"printf '[SevenOS] {command} is a global package command.\\n' >&2\n"
                "printf '[SevenOS] Use SevenStore/sevenpkg for normal installs, or profile rootfs maintenance for mini OS packages.\\n' >&2\n"
                "printf '[SevenOS] For a deliberate global install: SEVENOS_ALLOW_GLOBAL_PACKAGES=1 " + command + " %s\\n' \"$*\" >&2\n"
                f"printf '[SevenOS] Suggested: seven profile exec %s --rootfs-writable {command} %s\\n' \"$profile\" \"$*\" >&2\n"
                "printf '[SevenOS] Then run: seven profile-rootfs verify all && seven profile-rootfs seal all --apply --yes\\n' >&2\n"
                "exit 126\n",
                encoding="utf-8",
            )
        else:
            shim.write_text(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                f"command_name={shlex.quote(command)}\n"
                f"profile=\"$(sed -n 's/^SEVENOS_ACTIVE_PROFILE=//p' {shlex.quote(str(state_dir / 'profile.env'))} 2>/dev/null | head -1 | tr -d '\"' || true)\"\n"
                "profile=\"${profile:-${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_ISOLATION_PRIMARY:-equinox}}}\"\n"
                "if [[ \"$profile\" == \"equinox\" || \"${SEVENOS_SYSTEM_PROFILE:-0}\" == \"1\" ]]; then\n"
                "  base_path=\"\"\n"
                "  IFS=':' read -ra path_parts <<<\"${PATH:-}\"\n"
                "  for path_part in \"${path_parts[@]}\"; do\n"
                "    [[ -n \"$path_part\" ]] || continue\n"
                "    case \"$path_part\" in *profile-shims*|*profile-package-views*|*/.local/share/sevenos/profile-containers/*) continue ;; esac\n"
                "    base_path=\"${base_path:+$base_path:}$path_part\"\n"
                "  done\n"
                "  real=\"$(PATH=\"$base_path\" command -v \"$command_name\" || true)\"\n"
                "  [[ -n \"$real\" && \"$real\" != \"$0\" ]] || { printf '[SevenOS] backend missing for %s\\n' \"$command_name\" >&2; exit 127; }\n"
                "  exec \"$real\" \"$@\"\n"
                "fi\n"
                f"exec {runner} --container \"$command_name\" \"$@\"\n",
                encoding="utf-8",
            )
        shim.chmod(0o755)

    package_views = generate_package_views()
    for key, view in package_views.items():
        payload["profile_containers"].setdefault(key, {})["package_view"] = view.get("bin")
        payload["strict_runtime"].setdefault(key, {})["package_view"] = view.get("bin")
        payload["strict_runtime"].setdefault(key, {})["package_view_command_count"] = view.get("command_count", 0)
    payload["package_views"] = package_views
    payload["strict_boundaries"]["package_views"] = "per-profile PATH/bin view over global pacman store"

    desktop_overrides = generate_desktop_overrides()
    profile_launchers = generate_profile_launchers()
    legacy_archives = archive_legacy_aliases()
    payload["strict_boundaries"]["desktop_overrides"] = len(desktop_overrides) + len(profile_launchers)
    payload["strict_boundaries"]["profile_launchers"] = "one independent launcher and one independent terminal per mini OS"
    payload["strict_boundaries"]["legacy_aliases"] = "archived, not deleted"
    payload["desktop_overrides"] = desktop_overrides[:200]
    payload["profile_launchers"] = profile_launchers
    payload["legacy_archives"] = legacy_archives
    write_text(state_dir / "profile-isolation.json", json.dumps(payload, indent=2) + "\n")

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
    shims_dir = host_home / ".local/share/sevenos/profile-shims"
    sample_shims = [shims_dir / command for command in ("code", "gimp", "nmap", "gamemoderun") if (shims_dir / command).exists()]
    strict_shims_ok = bool(sample_shims) and all("--container" in path.read_text(encoding="utf-8", errors="ignore") for path in sample_shims)
    package_guard_shims = [shims_dir / command for command in ("pacman", "paru", "yay", "makepkg") if (shims_dir / command).exists()]
    package_guard_ok = bool(package_guard_shims) and all("SEVENOS_ALLOW_GLOBAL_PACKAGES" in path.read_text(encoding="utf-8", errors="ignore") for path in package_guard_shims)
    desktop_override_root = host_home / ".local/share/applications"
    desktop_override_count = 0
    if desktop_override_root.is_dir():
        desktop_override_count = sum(1 for path in desktop_override_root.glob("*.desktop") if "X-SevenOS-Profiled=true" in path.read_text(encoding="utf-8", errors="ignore"))
    package_view_root = host_home / ".local/share/sevenos/profile-package-views"
    package_view_count = 0
    if package_view_root.is_dir():
        package_view_count = sum(1 for path in package_view_root.glob("*/bin") if path.is_dir())
    rootfs_root = host_home / ".local/share/sevenos/profile-rootfs"
    rootfs_count = 0
    rootfs_ready_count = 0
    if rootfs_root.is_dir():
        rootfs_count = sum(1 for path in rootfs_root.glob("*/rootfs") if path.is_dir())
        rootfs_ready_count = sum(1 for path in rootfs_root.glob("*/rootfs/usr/bin") if path.is_dir())
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
        "profile_launcher": "OK" if (root / "bin" / "seven-profile-launch").is_file() else "MISS",
        "strict_shims": "OK" if strict_shims_ok else "MISS",
        "package_manager_guard": "OK" if package_guard_ok else "MISS",
        "desktop_overrides": "OK" if desktop_override_count > 0 else "MISS",
        "desktop_override_count": desktop_override_count,
        "package_views": "OK" if package_view_count >= len(profiles) else "MISS",
        "package_view_count": package_view_count,
        "rootfs": "OK" if rootfs_count >= max(len(profiles) - 1, 0) else "MISS",
        "rootfs_count": rootfs_count,
        "rootfs_ready_count": rootfs_ready_count,
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
