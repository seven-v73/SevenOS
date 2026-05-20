#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
APPLY=0
YES=0

usage() {
  cat <<'EOF'
SevenOS Scheduler

Usage:
  seven scheduler status [--json]
  seven scheduler plan [--json]
  seven scheduler apply [--apply] [--yes]

Seven Scheduler is a user-space orchestration layer above the Linux CFS
scheduler. It does not replace the kernel. It groups workloads by SevenOS
profile context and prepares safe priority, affinity and power policy hints.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|plan|apply) ACTION="$1" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown scheduler option: $1"; usage; exit 1 ;;
  esac
  shift
done

active_profile() {
  local state_file="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env"
  if [[ -f "$state_file" ]]; then
    # shellcheck disable=SC1090
    source "$state_file"
    printf '%s' "${SEVENOS_ACTIVE_PROFILE:-equinox}"
  else
    printf 'equinox'
  fi
}

context_payload() {
  if [[ -x "$ROOT_DIR/scripts/context.sh" ]]; then
    "$ROOT_DIR/scripts/context.sh" status --json 2>/dev/null || printf 'null'
  else
    printf 'null'
  fi
}

json_payload() {
  SEVENOS_ROOT="$ROOT_DIR" ACTIVE_PROFILE="$(active_profile)" CONTEXT_PAYLOAD="$(context_payload)" python - <<'PY'
import json
import os
import shutil
import subprocess

active = os.environ.get("ACTIVE_PROFILE", "equinox")
try:
    context_payload = json.loads(os.environ.get("CONTEXT_PAYLOAD", "null") or "null")
except json.JSONDecodeError:
    context_payload = None

GROUPS = {
    "equinox": {
        "title": "Equinox",
        "role": "Balanced global",
        "policy": "balanced-adaptive",
        "nice": 0,
        "io": "best-effort",
        "power": "balanced",
        "slice": "seven-equinox.slice",
        "cpu_weight": 150,
        "io_weight": 140,
        "uclamp_min": "0",
        "uclamp_max": "max",
        "processes": ["seven", "seven-daemon", "seven-server", "waybar", "hyprpaper", "swaync", "kitty", "nautilus"],
        "reason": "Keep the neutral system profile responsive while avoiding profile dominance.",
    },
    "baobab": {
        "title": "Baobab",
        "role": "Culture",
        "policy": "quiet-cultural",
        "nice": 0,
        "io": "best-effort",
        "power": "balanced",
        "slice": "seven-baobab.slice",
        "cpu_weight": 90,
        "io_weight": 90,
        "uclamp_min": "0",
        "uclamp_max": "80%",
        "processes": ["seven-files", "seven-hub-native", "seven-settings-native", "waybar", "hyprpaper"],
        "reason": "Keep cultural/community surfaces calm and lightweight without dev/security noise.",
    },
    "forge": {
        "title": "Forge",
        "role": "Development",
        "policy": "interactive-build",
        "nice": -2,
        "io": "best-effort-high",
        "power": "performance-on-ac",
        "slice": "seven-forge.slice",
        "cpu_weight": 180,
        "io_weight": 160,
        "uclamp_min": "20%",
        "uclamp_max": "max",
        "processes": ["code", "codium", "helix", "hx", "nvim", "node", "npm", "cargo", "rustc", "docker", "podman"],
        "reason": "Boost editors, compilers and containers while keeping desktop latency stable.",
    },
    "shield": {
        "title": "Shield",
        "role": "Security",
        "policy": "isolated-analysis",
        "nice": 0,
        "io": "best-effort",
        "power": "balanced",
        "slice": "seven-shield.slice",
        "cpu_weight": 120,
        "io_weight": 100,
        "uclamp_min": "0",
        "uclamp_max": "80%",
        "processes": ["wireshark", "nmap", "burpsuite", "zaproxy", "john", "hashcat", "aircrack-ng", "firejail"],
        "reason": "Keep security tools visible and auditable; avoid silently boosting risky scans.",
    },
    "studio": {
        "title": "Studio",
        "role": "Creation",
        "policy": "media-low-latency",
        "nice": -4,
        "io": "best-effort-high",
        "power": "performance",
        "slice": "seven-studio.slice",
        "cpu_weight": 220,
        "io_weight": 180,
        "uclamp_min": "30%",
        "uclamp_max": "max",
        "processes": ["blender", "krita", "gimp", "inkscape", "kdenlive", "ardour", "pipewire", "wireplumber"],
        "reason": "Prioritize creative apps, media pipelines and audio responsiveness.",
    },
    "windows": {
        "title": "Windows",
        "role": "Compatibility",
        "policy": "vm-foreground",
        "nice": -3,
        "io": "best-effort-high",
        "power": "performance-on-ac",
        "slice": "seven-windows.slice",
        "cpu_weight": 200,
        "io_weight": 170,
        "uclamp_min": "25%",
        "uclamp_max": "max",
        "processes": ["qemu-system-x86_64", "virt-manager", "libvirtd", "wineserver", "wine", "bottles", "lutris"],
        "reason": "Give VM/Wine workloads enough foreground priority without replacing CFS.",
    },
    "horizon": {
        "title": "Horizon",
        "role": "Server and deploy",
        "policy": "service-stability",
        "nice": 2,
        "io": "best-effort",
        "power": "balanced",
        "slice": "seven-horizon.slice",
        "cpu_weight": 140,
        "io_weight": 130,
        "uclamp_min": "0",
        "uclamp_max": "90%",
        "processes": ["podman", "conmon", "caddy", "go", "seven-server", "seven-deploy"],
        "reason": "Prefer stable service throughput over aggressive desktop boosts.",
    },
    "pulse": {
        "title": "Pulse",
        "role": "Performance",
        "policy": "low-latency-foreground",
        "nice": -3,
        "io": "best-effort-high",
        "power": "performance-on-demand",
        "slice": "seven-pulse.slice",
        "cpu_weight": 210,
        "io_weight": 170,
        "uclamp_min": "25%",
        "uclamp_max": "max",
        "processes": ["gamemoderun", "gamescope", "mangohud", "steam", "lutris", "heroic", "obs", "wf-recorder"],
        "reason": "Prioritize focused interactive workloads and capture hooks while suppressing background noise.",
    },
}


def run(command):
    return subprocess.run(command, text=True, capture_output=True, check=False)


def process_rows():
    result = run(["ps", "-eo", "pid=,ni=,psr=,pcpu=,pmem=,comm="])
    rows = []
    if result.returncode != 0:
        return rows
    for raw in result.stdout.splitlines():
        parts = raw.split(None, 5)
        if len(parts) < 6:
            continue
        pid, nice, cpu, pcpu, pmem, comm = parts
        try:
            nice_value = int(nice)
        except ValueError:
            nice_value = 0
        rows.append({
            "pid": int(pid),
            "nice": nice_value,
            "cpu": cpu,
            "pcpu": float(pcpu),
            "pmem": float(pmem),
            "command": comm,
        })
    return rows


def match_group(process, group):
    command = process.get("command", "").lower()
    for name in group.get("processes", []):
        name = name.lower()
        if command == name or command.startswith(name):
            return True
    return False


rows = process_rows()
primary_context = (context_payload or {}).get("primary_context", {}) if isinstance(context_payload, dict) else {}
context_group = primary_context.get("scheduler_group") or active
if context_group not in GROUPS:
    context_group = active if active in GROUPS else "equinox"
groups = []
for key, group in GROUPS.items():
    matches = [item for item in rows if match_group(item, group)]
    groups.append({
        "key": key,
        **group,
        "active": key == context_group,
        "profile_active": key == active,
        "context_active": key == context_group,
        "matches": len(matches),
        "sample": matches[:8],
    })

active_group = GROUPS.get(context_group, GROUPS["equinox"])
governor_path = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
try:
    with open(governor_path, "r", encoding="utf-8") as handle:
        governor = handle.read().strip()
except OSError:
    governor = "unknown"

cgroup_controllers_path = "/sys/fs/cgroup/cgroup.controllers"
try:
    with open(cgroup_controllers_path, "r", encoding="utf-8") as handle:
        cgroup_controllers = handle.read().strip().split()
except OSError:
    cgroup_controllers = []

has_systemd_run = shutil.which("systemd-run") is not None

actions = []
for group in groups:
    if not group["active"]:
        continue
    if group["matches"] == 0:
        actions.append({
            "key": f"{group['key']}.no-workload",
            "severity": "low",
            "impact": "safe",
            "title": f"No active {group['title']} workload detected",
            "command": f"seven profile open {group['key']}",
            "reason": "Open the workspace before applying context scheduling.",
        })
        continue
    mismatched = [item for item in group.get("sample", []) if item.get("nice") != group["nice"]]
    if mismatched:
        actions.append({
            "key": f"{group['key']}.nice",
            "severity": "medium",
            "impact": "changes",
            "title": f"Apply {group['title']} nice policy",
            "command": "seven scheduler apply --apply",
            "reason": f"{len(mismatched)} sampled process(es) differ from target nice {group['nice']}.",
        })
    actions.append({
        "key": f"{group['key']}.power",
        "severity": "medium",
        "impact": "manual",
        "title": f"Review {group['title']} power policy",
        "command": "seven scheduler plan",
        "reason": f"Requested power policy: {group['power']}. Kernel/governor changes stay explicit.",
    })
    actions.append({
        "key": f"{group['key']}.slice",
        "severity": "low",
        "impact": "future",
        "title": f"Prepare {group['title']} context group",
        "command": f"systemd-run --user --scope --slice={group['slice']} <command>",
        "reason": "Future SevenDaemon will move launched profile apps into semantic cgroups instead of tracking raw PIDs only.",
    })

print(json.dumps({
    "schema": "sevenos.scheduler.v1",
    "layer": "user-space scheduler orchestration",
    "kernel_scheduler": "Linux CFS",
    "state": "foundation",
    "active_profile": active,
    "active_context": primary_context or {
        "key": active,
        "title": GROUPS.get(active, GROUPS["equinox"])["title"],
        "confidence": 0,
        "scheduler_group": context_group,
    },
    "policy_source": "context" if primary_context else "profile",
    "active_policy": {
        "profile": active,
        "scheduler_group": context_group,
        "policy": active_group["policy"],
        "nice": active_group["nice"],
        "io": active_group["io"],
        "power": active_group["power"],
        "slice": active_group["slice"],
        "cpu_weight": active_group["cpu_weight"],
        "io_weight": active_group["io_weight"],
        "uclamp_min": active_group["uclamp_min"],
        "uclamp_max": active_group["uclamp_max"],
        "reason": active_group["reason"],
    },
    "host": {
        "nproc": os.cpu_count() or 1,
        "governor": governor,
        "cgroups_v2": bool(cgroup_controllers),
        "cgroup_controllers": cgroup_controllers,
        "has_systemd_run": has_systemd_run,
        "has_taskset": shutil.which("taskset") is not None,
        "has_renice": shutil.which("renice") is not None,
        "has_ionice": shutil.which("ionice") is not None,
    },
    "semantic_controls": {
        "implemented": ["context classification", "process matching", "safe nice preview", "JSON policy contract"],
        "planned": ["systemd user scopes", "cgroups v2 CPUWeight/IOWeight", "uclamp hints", "SevenDaemon policy executor", "SevenBus foreground events"],
        "guardrails": ["no kernel scheduler replacement", "no silent affinity changes", "no opaque AI-driven resource changes"],
    },
    "groups": groups,
    "actions": actions,
}, indent=2))
PY
}

status() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    json_payload
    return 0
  fi

  SCHEDULER_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SCHEDULER_PAYLOAD"])
policy = data.get("active_policy", {})
host = data.get("host", {})

print("SevenOS Scheduler")
print("=================")
print(f"layer:     {data.get('layer')}")
print(f"kernel:    {data.get('kernel_scheduler')}")
print(f"profile:   {data.get('active_profile')}")
print(f"context:   {data.get('active_context', {}).get('title', 'unknown')} ({data.get('active_context', {}).get('confidence', 0)}%)")
print(f"policy:    {policy.get('policy')} / nice {policy.get('nice')} / power {policy.get('power')}")
print(f"group:     {policy.get('scheduler_group')} / {policy.get('slice')}")
print(f"weights:   CPU {policy.get('cpu_weight')} / IO {policy.get('io_weight')} / uclamp {policy.get('uclamp_min')}..{policy.get('uclamp_max')}")
print(f"host:      {host.get('nproc')} CPU threads / governor {host.get('governor')} / cgroups v2 {host.get('cgroups_v2')}")
print()
print("Groups:")
for group in data.get("groups", []):
    marker = "*" if group.get("active") else " "
    print(f" {marker} {group.get('title'):<8} {group.get('policy'):<20} matches={group.get('matches')}")
PY
}

plan() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    json_payload
    return 0
  fi

  SCHEDULER_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SCHEDULER_PAYLOAD"])
print("SevenOS Scheduler Plan")
print("======================")
print(f"Active profile: {data.get('active_profile')}")
print(f"Kernel scheduler: {data.get('kernel_scheduler')}")
print()
for item in data.get("actions", []):
    print(f"{item.get('severity', 'medium'):<8} {item.get('impact', 'safe'):<8} {item.get('command')}")
    print(f"         {item.get('reason')}")
if not data.get("actions"):
    print("No scheduler actions are currently needed.")
PY
}

apply_plan() {
  local payload dry_run=0
  payload="$(json_payload)"
  is_dry_run && dry_run=1

  printf 'SevenOS Scheduler Apply\n'
  printf '=======================\n'
  if [[ "$APPLY" -ne 1 ]]; then
    printf 'Preview only. Add --apply to change nice values for owned processes.\n\n'
  fi

  SCHEDULER_PAYLOAD="$payload" APPLY="$APPLY" DRY_RUN="$dry_run" python - <<'PY'
import json
import os
import subprocess

data = json.loads(os.environ["SCHEDULER_PAYLOAD"])
apply = os.environ.get("APPLY") == "1"
dry_run = os.environ.get("DRY_RUN") == "1"
active = data.get("active_policy", {}).get("scheduler_group") or data.get("active_profile")
target = data.get("active_policy", {}).get("nice", 0)

active_group = next((item for item in data.get("groups", []) if item.get("key") == active), {})
sample = active_group.get("sample", [])
if not sample:
    print(f"DRY-RUN > Scheduler > {active} > no matching owned workload")
    raise SystemExit(0)

for process in sample:
    command = ["renice", "-n", str(target), "-p", str(process["pid"])]
    if not apply or dry_run:
        print(f"DRY-RUN > Scheduler > {active} > {' '.join(command)}")
        continue
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    state = "OK" if result.returncode == 0 else "MISS"
    detail = (result.stdout or result.stderr).strip()
    print(f"{state} > Scheduler > {active} > pid {process['pid']} > {detail}")
PY
}

case "$ACTION" in
  status) status ;;
  plan) plan ;;
  apply) apply_plan ;;
  *) log_error "Unknown scheduler action: $ACTION"; usage; exit 1 ;;
esac
