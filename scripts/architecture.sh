#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Architecture

Usage:
  seven architecture [map|layers|hybrid|matrix|doctor] [--json]
  ./scripts/architecture.sh [map|layers|hybrid|matrix|doctor] [--json]

Actions:
  map     Show control plane and product architecture
  layers  Show system layers and modules
  hybrid  Show the user-space hybrid OS architecture
  matrix  Show layer readiness, ownership, contracts and next actions
  doctor  Validate architecture foundation files and entrypoints
EOF
}

json_requested() {
  local item
  for item in "$@"; do
    [[ "$item" == "--json" ]] && return 0
  done
  return 1
}

layers() {
  printf 'SevenOS System Layers\n'
  printf '=====================\n'
  printf '  %-22s %s\n' "Layer" "Modules"
  printf '  %-22s %s\n' "-----" "-------"
  printf '  %-22s %s\n' "System Core" "install.sh, bootstrap.sh, seven, repair, readiness, phase-gate"
  printf '  %-22s %s\n' "Package Layer" "sevenpkg, package manifests, meta-packages"
  printf '  %-22s %s\n' "Service Layer" "seven-session, seven-server, seven-deploy, systemd"
  printf '  %-22s %s\n' "UI Layer" "Hyprland, Waybar, Rofi, Kitty, SwayNC, Hyprlock, Wlogout, Seven Hub, Seven Files, Tauri GUI"
  printf '  %-22s %s\n' "Security Layer" "hardening, cyber audit, cyber lab, sandboxing"
  printf '  %-22s %s\n' "Compatibility Layer" "Wine, Bottles, Lutris, KVM, Windows Mode"
  printf '  %-22s %s\n' "Deployment Layer" "Horizon, local API, deploy planner"
  printf '  %-22s %s\n' "Identity Layer" "branding, palette, vocabulary, wallpaper, icons"
  printf '  %-22s %s\n' "Installer Layer" "archiso, install planner, generated script"
}

map() {
  printf 'SevenOS Architecture Map\n'
  printf '========================\n\n'
  printf 'Product problem:\n'
  printf '  Linux is powerful but fragmented. SevenOS unifies daily desktop, dev,\n'
  printf '  cyber, creation, Windows compatibility and deployment into one system.\n\n'
  printf 'Control plane:\n'
  printf '  User -> Seven Hub / CLI -> seven -> profiles/scripts/services -> system\n\n'
  printf 'Core entrypoints:\n'
  printf '  seven              system controller\n'
  printf '  sevenpkg           package and meta-package manager\n'
  printf '  seven hub          visual control center\n'
  printf '  seven files        file experience\n'
  printf '  seven-server       local API foundation\n'
  printf '  seven-deploy       deployment planner\n\n'
  layers
}

hybrid() {
  printf 'SevenOS Hybrid OS Architecture\n'
  printf '==============================\n\n'
  printf 'Definition:\n'
  printf '  SevenOS keeps the Linux kernel stable and builds a local user-space\n'
  printf '  hybrid operating architecture above it.\n\n'
  printf 'Stack:\n'
  printf '  SevenAI Layer                  natural language, local diagnostics, playbooks\n'
  printf '  Seven System Orchestration     control plane, profiles, scheduler, repair\n'
  printf '  User-Space Services            SevenDaemon, SevenBus, context, Server\n'
  printf '  Desktop / UI Layer             Hyprland, Waybar, Hub, Spotlight, Files\n'
  printf '  Arch / Linux Platform          pacman, systemd, PipeWire, portals, libvirt\n'
  printf '  Linux Kernel                   processes, memory, drivers, network, devices\n\n'
  printf 'Runtime flow:\n'
  printf '  User intent -> Hub/Spotlight/Waybar/CLI -> action registry -> SevenAI or\n'
  printf '  Control Plane -> SevenBus event -> SevenDaemon/service -> Linux.\n\n'
  printf 'Reference:\n'
  printf '  docs/HYBRID_OS_ARCHITECTURE.md\n'
}

hybrid_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import shutil
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
event_file = state_home / "sevenos/events.jsonl"


def exists(path):
    return (root / path).exists()


def executable(path):
    return os.access(root / path, os.X_OK)


def file_contains(path, text):
    try:
        return text in (root / path).read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False


def command_state(command):
    return "OK" if shutil.which(command) else "MISS"


def package_state(package):
    if not shutil.which("pacman"):
        return "MISS"
    result = subprocess.run(["pacman", "-Q", package], text=True, capture_output=True, check=False)
    return "OK" if result.returncode == 0 else "MISS"


def user_unit_state(unit):
    if not shutil.which("systemctl"):
        return "MISS"
    result = subprocess.run(["systemctl", "--user", "list-unit-files", unit, "--no-legend"], text=True, capture_output=True, check=False)
    return "OK" if result.returncode == 0 and result.stdout.strip() else "MISS"


def run_json(command, timeout=25):
    try:
        result = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=timeout, check=False)
    except Exception as exc:
        return None, f"{type(exc).__name__}: {exc}"
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        return None, detail[-1] if detail else f"exit {result.returncode}"
    try:
        return json.loads(result.stdout), None
    except json.JSONDecodeError as exc:
        return None, f"json: {exc}"


def service_state(unit):
    if not shutil.which("systemctl"):
        return "MISS"
    result = subprocess.run(["systemctl", "--user", "is-active", unit], text=True, capture_output=True, check=False)
    return "RUN" if result.returncode == 0 else "STOP"


def layer_status(checks):
    ok = sum(1 for item in checks if item.get("state") in {"OK", "RUN", "READY"})
    total = len(checks)
    if ok == total:
        return "ready"
    if ok:
        return "partial"
    return "missing"


layer_contracts = {
    "seven_ai": ["seven ai", "seven ai --json", "seven ai diagnose system --json", "seven ai playbook <id> --json"],
    "orchestration": ["seven control --json", "seven actions --json", "seven scheduler status --json", "seven repair"],
    "services": ["seven core health --json", "seven context status --json", "seven events --json", "seven server status --json"],
    "desktop_ui": ["seven hub", "seven-spotlight", "seven-quick-settings", "seven-files", "hyprctl"],
    "linux_platform": ["systemctl", "pacman", "nmcli", "pipewire", "xdg-desktop-portal-hyprland.service", "virsh"],
    "kernel": ["/proc", "/dev", "/proc/meminfo", "/proc/cpuinfo"],
}

layer_capabilities = {
    "seven_ai": ["natural language intents", "human explanations", "local diagnostics", "safe playbook selection"],
    "orchestration": ["prioritized plans", "profile decisions", "repair routing", "confirmation levels"],
    "services": ["event trail", "runtime health", "context observation", "local API foundation"],
    "desktop_ui": ["visible control surfaces", "quick actions", "workspace interaction", "normal-user workflows"],
    "linux_platform": ["packages", "services", "audio portals", "network", "virtualization"],
    "kernel": ["processes", "memory", "devices", "network stack", "filesystems"],
}

layer_owners = {
    "seven_ai": "SevenAI agent and provider",
    "orchestration": "seven control, actions, scheduler and repair",
    "services": "SevenDaemon, SevenBus and systemd user services",
    "desktop_ui": "Hyprland, Waybar, Hub, Spotlight and native SevenOS apps",
    "linux_platform": "Arch/Linux user-space services",
    "kernel": "upstream Linux kernel",
}

layer_safety = {
    "seven_ai": "safe-by-default; escalates through confirmation gates",
    "orchestration": "preview first; apply requires explicit intent",
    "services": "local-only audit trail and daemon contracts",
    "desktop_ui": "normal-user actions first; system actions routed to control plane",
    "linux_platform": "package/service changes require confirmation or admin rights",
    "kernel": "read-only observation from SevenOS; no kernel fork",
}

layer_actions = {
    "seven_ai": ["seven ai focus", "seven ai diagnose system --json", "seven ai shortcuts"],
    "orchestration": ["seven control", "seven actions --json", "seven scheduler plan"],
    "services": ["seven core health --json", "seven context emit", "seven events --json"],
    "desktop_ui": ["seven hub", "seven-spotlight", "seven-quick-settings"],
    "linux_platform": ["seven post-install", "seven repair", "seven daily"],
    "kernel": ["seven core health --json", "seven ai diagnose system --json"],
}


core_health, core_health_error = run_json([str(root / "bin/seven"), "core", "health", "--json"])
actions, actions_error = run_json([str(root / "scripts/actions.sh"), "--json"])
context, context_error = run_json([str(root / "bin/seven"), "context", "--json"])

event_count = 0
if event_file.exists():
    try:
        event_count = sum(1 for line in event_file.read_text(encoding="utf-8", errors="ignore").splitlines() if line.strip())
    except OSError:
        event_count = 0

layers = [
    {
        "id": "seven_ai",
        "title": "SevenAI Layer",
        "role": "natural-language OS agent, diagnostics, playbooks, local guidance",
        "checks": [
            {"name": "ai_command", "state": "OK" if executable("scripts/ai.sh") else "MISS"},
            {"name": "agent_engine", "state": "OK" if exists("scripts/seven_ai_agent.py") else "MISS"},
            {"name": "provider", "state": "OK" if exists("scripts/seven_ai_provider.py") else "MISS"},
            {"name": "ai_json_contract", "state": "OK" if file_contains("scripts/ai.sh", "sevenos.ai-local.v1") else "MISS", "detail": "sevenos.ai-local.v1"},
        ],
    },
    {
        "id": "orchestration",
        "title": "Seven System Orchestration Layer",
        "role": "control plane, scheduler, action registry, repair decisions",
        "checks": [
            {"name": "control_plane", "state": "OK" if executable("scripts/control-plane.sh") else "MISS"},
            {"name": "scheduler", "state": "OK" if executable("scripts/scheduler.sh") else "MISS"},
            {"name": "actions_json", "state": "OK" if actions and actions.get("schema") else "MISS", "detail": actions_error or actions.get("schema") if actions else actions_error},
            {"name": "control_json_contract", "state": "OK" if file_contains("scripts/control-plane.sh", "sevenos.control.v1") else "MISS", "detail": "sevenos.control.v1"},
        ],
    },
    {
        "id": "services",
        "title": "User-Space Services Layer",
        "role": "SevenDaemon, SevenBus, context observer, local APIs and runtime health",
        "checks": [
            {"name": "seven_daemon", "state": "OK" if executable("bin/seven-daemon") else "MISS"},
            {"name": "daemon_service", "state": service_state("seven-daemon.service")},
            {"name": "context_observer", "state": service_state("seven-context-observer.service")},
            {"name": "event_bus", "state": "OK" if event_file.exists() or core_health else "MISS", "detail": str(event_file)},
            {"name": "core_health", "state": "OK" if core_health and core_health.get("schema") else "MISS", "detail": core_health_error or core_health.get("schema") if core_health else core_health_error},
            {"name": "context_json", "state": "OK" if context and context.get("schema") else "MISS", "detail": context_error or context.get("schema") if context else context_error},
        ],
    },
    {
        "id": "desktop_ui",
        "title": "Desktop / UI Layer",
        "role": "Hyprland, Waybar, Seven Hub, Spotlight, Files and shell controls",
        "checks": [
            {"name": "hyprland_config", "state": "OK" if exists("hyprland/hyprland.conf") else "MISS"},
            {"name": "hyprctl", "state": command_state("hyprctl")},
            {"name": "waybar_config", "state": "OK" if exists("hyprland/waybar/config.jsonc") else "MISS"},
            {"name": "seven_hub_native", "state": "OK" if executable("bin/seven-hub-native") else "MISS"},
            {"name": "spotlight", "state": "OK" if executable("bin/seven-spotlight") else "MISS"},
            {"name": "files", "state": "OK" if executable("bin/seven-files") else "MISS"},
        ],
    },
    {
        "id": "linux_platform",
        "title": "Arch / Linux Platform",
        "role": "systemd, pacman, PipeWire, NetworkManager, portals and libvirt",
        "checks": [
            {"name": "systemctl", "state": command_state("systemctl")},
            {"name": "pacman", "state": command_state("pacman")},
            {"name": "pipewire", "state": command_state("pipewire")},
            {"name": "networkmanager", "state": command_state("nmcli")},
            {"name": "portal_hyprland", "state": "OK" if package_state("xdg-desktop-portal-hyprland") == "OK" or user_unit_state("xdg-desktop-portal-hyprland.service") == "OK" else "MISS", "detail": "package-or-user-service"},
            {"name": "libvirt", "state": command_state("virsh")},
        ],
    },
    {
        "id": "kernel",
        "title": "Linux Kernel",
        "role": "processes, memory, drivers, networking, filesystems and devices",
        "checks": [
            {"name": "proc", "state": "OK" if Path("/proc").exists() else "MISS"},
            {"name": "kernel_version", "state": "OK" if Path("/proc/version").exists() else "MISS"},
            {"name": "devices", "state": "OK" if Path("/dev").exists() else "MISS"},
            {"name": "memory", "state": "OK" if Path("/proc/meminfo").exists() else "MISS"},
            {"name": "cpu", "state": "OK" if Path("/proc/cpuinfo").exists() else "MISS"},
        ],
    },
]

for layer in layers:
    layer["state"] = layer_status(layer["checks"])
    layer["score"] = sum(1 for item in layer["checks"] if item.get("state") in {"OK", "RUN", "READY"})
    layer["max"] = len(layer["checks"])
    layer_id = layer["id"]
    layer["maturity"] = round((layer["score"] / layer["max"]) * 100) if layer["max"] else 0
    layer["owner"] = layer_owners.get(layer_id, "SevenOS")
    layer["contracts"] = layer_contracts.get(layer_id, [])
    layer["capabilities"] = layer_capabilities.get(layer_id, [])
    layer["safety"] = layer_safety.get(layer_id, "local-first SevenOS contract")
    layer["next_actions"] = layer_actions.get(layer_id, [])
    layer["gaps"] = [item["name"] for item in layer["checks"] if item.get("state") not in {"OK", "RUN", "READY"}]
    layer["risk"] = "low" if layer["state"] == "ready" else "medium" if layer["score"] else "high"

score = sum(layer["score"] for layer in layers)
maximum = sum(layer["max"] for layer in layers)
ready_layers = sum(1 for layer in layers if layer["state"] == "ready")

payload = {
    "schema": "sevenos.hybrid-architecture.v1",
    "name": "SevenOS user-space hybrid operating architecture",
    "kernel_policy": "do-not-fork-linux",
    "local_first": True,
    "state": "ready" if ready_layers == len(layers) else "partial" if score else "missing",
    "score": score,
    "max": maximum,
    "percent": round((score / maximum) * 100) if maximum else 0,
    "event_count": event_count,
    "layers": layers,
    "runtime_flow": [
        "user_intent",
        "hub_spotlight_waybar_cli",
        "action_registry",
        "sevenai_or_control_plane",
        "sevenbus_event",
        "sevendaemon_or_service",
        "linux_kernel",
    ],
    "next": [
        {"command": "seven core health --json", "reason": "read daemon-owned runtime state"},
        {"command": "seven actions --json", "reason": "route UI and AI through stable action IDs"},
        {"command": "seven ai diagnose system --json", "reason": "inspect local context before repair"},
        {"command": "seven events --json", "reason": "audit previews and executed actions"},
        {"command": "seven architecture matrix", "reason": "show layer ownership, contracts, gaps and next actions"},
    ],
}
print(json.dumps(payload, indent=2))
PY
}

matrix() {
  local payload
  payload="$(hybrid_json)"

  if json_requested "$@"; then
    printf '%s\n' "$payload"
    return 0
  fi

  HYBRID_JSON="$payload" python - <<'PY'
import json
import os

payload = json.loads(os.environ["HYBRID_JSON"])

print("SevenOS Hybrid Architecture Matrix")
print("==================================")
print(f"State: {payload['state']} · Score: {payload['score']}/{payload['max']} · Maturity: {payload['percent']}%")
print()
print(f"{'Layer':<22} {'State':<8} {'Score':<7} {'Risk':<6} Owner")
print(f"{'-' * 22} {'-' * 8} {'-' * 7} {'-' * 6} {'-' * 30}")
for layer in payload["layers"]:
    print(f"{layer['title'][:22]:<22} {layer['state']:<8} {layer['score']}/{layer['max']:<5} {layer['risk']:<6} {layer['owner']}")

print()
print("Contracts and Next Actions")
print("--------------------------")
for layer in payload["layers"]:
    print(f"{layer['title']}")
    print(f"  capabilities: {', '.join(layer['capabilities'])}")
    print(f"  contracts:    {', '.join(layer['contracts'])}")
    if layer["gaps"]:
        print(f"  gaps:         {', '.join(layer['gaps'])}")
    else:
        print("  gaps:         none")
    print(f"  next:         {', '.join(layer['next_actions'])}")
    print(f"  safety:       {layer['safety']}")
    print()

print("Runtime Flow")
print("------------")
print(" -> ".join(payload["runtime_flow"]))
PY
}

doctor() {
  local failures=0
  local path

  printf 'SevenOS Architecture Doctor\n'
  printf '===========================\n'

  for path in \
    "docs/ARCHITECTURE.md" \
    "docs/HYBRID_OS_ARCHITECTURE.md" \
    "docs/VISION.md" \
    "docs/PRODUCT_STRATEGY.md" \
    "docs/UX_PRINCIPLES.md" \
    "docs/VOCABULARY.md" \
    "docs/OS_CRITERIA.md" \
    "docs/DEPLOYMENT.md" \
    "docs/ECOSYSTEM.md" \
    "install.sh" \
    "bootstrap.sh" \
    "bin/seven" \
    "bin/sevenpkg" \
    "bin/seven-session" \
    "bin/seven-files" \
    "seven-hub/bin/seven-hub" \
    "seven-hub/bin/seven-control-center" \
    "seven-hub/gui-stack.sh" \
    "seven-hub/gui/package.json" \
    "server/seven-server.sh" \
    "server/seven-deploy.sh" \
    "scripts/installer-stack.sh" \
    "scripts/flatpak.sh" \
    "scripts/readiness.sh" \
    "scripts/phase-gate.sh" \
    "scripts/ux-check.sh" \
    "scripts/check.sh" \
    "scripts/packages-base.txt" \
    "sevenpkg/metapackages.json" \
    "security/hardening.sh" \
    "vm/windows-mode.sh" \
    "installer/plan.sh" \
    "archiso/README.md"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  if ! grep -q 'System Core' "$ROOT_DIR/docs/ARCHITECTURE.md" ||
     ! grep -q 'Package Layer' "$ROOT_DIR/docs/ARCHITECTURE.md" ||
     ! grep -q 'Security Layer' "$ROOT_DIR/docs/ARCHITECTURE.md" ||
     ! grep -q 'Deployment Layer' "$ROOT_DIR/docs/ARCHITECTURE.md"; then
    printf '[MISS] docs/ARCHITECTURE.md missing required layer language\n'
    failures=$((failures + 1))
  else
    printf '[OK] architecture layers documented\n'
  fi

  if ! grep -q 'user-space hybrid operating architecture' "$ROOT_DIR/docs/HYBRID_OS_ARCHITECTURE.md" ||
     ! grep -q 'SevenAI Layer' "$ROOT_DIR/docs/HYBRID_OS_ARCHITECTURE.md" ||
     ! grep -q 'SevenBus' "$ROOT_DIR/docs/HYBRID_OS_ARCHITECTURE.md"; then
    printf '[MISS] docs/HYBRID_OS_ARCHITECTURE.md missing hybrid OS contract language\n'
    failures=$((failures + 1))
  else
    printf '[OK] hybrid user-space OS architecture documented\n'
  fi

  if ! grep -q 'architecture_parser' "$ROOT_DIR/bin/seven"; then
    printf '[MISS] seven architecture entrypoint missing\n'
    failures=$((failures + 1))
  else
    printf '[OK] seven architecture entrypoint\n'
  fi

  if [[ "$failures" -gt 0 ]]; then
    log_error "Architecture foundation has $failures issue(s)."
    return 1
  fi

  log_success "Architecture foundation is coherent."
}

action="${1:-map}"
shift || true
case "$action" in
  map|status) map ;;
  layers) layers ;;
  hybrid)
    if json_requested "$@"; then
      hybrid_json
    else
      hybrid
    fi
    ;;
  matrix)
    matrix "$@"
    ;;
  doctor) doctor ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown architecture action: $action"; usage; exit 1 ;;
esac
