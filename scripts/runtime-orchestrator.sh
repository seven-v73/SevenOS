#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
shift || true

JSON_OUTPUT=0
APPLY=0
YES=0
ITEMS=()

usage() {
  cat <<'EOF'
Seven Runtime Orchestrator
==========================

Usage:
  seven runtime status [--json]
  seven runtime capabilities [--json]
  seven runtime plan [primary] [capability ...] [--json]
  seven runtime activate <primary> [capability ...] [--apply] [--yes] [--json]
  seven runtime doctor [--json]

Examples:
  seven runtime plan equinox forge shield studio pulse
  seven runtime activate baobab + shield + forge --apply --yes

Seven Runtime Orchestrator uses the Layered Autonomous Profiles Architecture:
each profile is complete by itself, while Equinox can mix controlled
capabilities without letting profiles pollute each other.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|plan|activate|capabilities|doctor) ACTION="$1" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) ITEMS+=("$1") ;;
  esac
  shift
done

runtime_state_dir() {
  printf '%s/sevenos\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

runtime_state_file() {
  printf '%s/runtime.json\n' "$(runtime_state_dir)"
}

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

items_json() {
  ITEMS_PAYLOAD="$(printf '%s\n' "${ITEMS[@]}")" python - <<'PY'
import json
import os

items = []
for raw in os.environ.get("ITEMS_PAYLOAD", "").splitlines():
    for token in raw.replace("+", " + ").split():
        token = token.strip()
        if token and token != "+":
            items.append(token)
print(json.dumps(items))
PY
}

context_payload() {
  if [[ -x "$ROOT_DIR/scripts/context.sh" ]]; then
    "$ROOT_DIR/scripts/context.sh" status --json 2>/dev/null || printf 'null'
  else
    printf 'null'
  fi
}

scheduler_payload() {
  if [[ -x "$ROOT_DIR/scripts/scheduler.sh" ]]; then
    "$ROOT_DIR/scripts/scheduler.sh" status --json 2>/dev/null || printf 'null'
  else
    printf 'null'
  fi
}

json_payload() {
  SEVENOS_ROOT="$ROOT_DIR" \
  ACTION="$ACTION" \
  ACTIVE_PROFILE="$(active_profile)" \
  ITEMS_JSON="$(items_json)" \
  APPLY="$APPLY" \
  YES="$YES" \
  DRY_RUN="${SEVENOS_DRY_RUN:-0}" \
  STATE_FILE="$(runtime_state_file)" \
  CONTEXT_PAYLOAD="$(context_payload)" \
  SCHEDULER_PAYLOAD="$(scheduler_payload)" \
  python - <<'PY'
import json
import os
import platform
import shutil
import subprocess
import time
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
action = os.environ.get("ACTION", "status")
active_profile = os.environ.get("ACTIVE_PROFILE", "equinox")
state_file = Path(os.environ["STATE_FILE"])
apply_requested = os.environ.get("APPLY") == "1"
yes = os.environ.get("YES") == "1"
dry_run = os.environ.get("DRY_RUN") == "1"

try:
    items = json.loads(os.environ.get("ITEMS_JSON", "[]"))
except json.JSONDecodeError:
    items = []

try:
    context = json.loads(os.environ.get("CONTEXT_PAYLOAD", "null") or "null")
except json.JSONDecodeError:
    context = None

try:
    scheduler = json.loads(os.environ.get("SCHEDULER_PAYLOAD", "null") or "null")
except json.JSONDecodeError:
    scheduler = None

def load_profiles():
    catalog_path = root / "profiles" / "catalog.json"
    with catalog_path.open(encoding="utf-8") as handle:
        catalog = json.load(handle)

    profiles = {}
    for key, item in (catalog.get("profiles") or {}).items():
        resource_intent = item.get("resource_intent") or {
            "cpu": "balanced",
            "ram": "shared",
            "gpu": "foreground",
            "io": "responsive",
            "network": "normal",
        }
        profiles[key] = {
            "title": item.get("title", key.title()),
            "domain": item.get("domain", item.get("target", key)),
            "role": item.get("role", "mini OS"),
            "autonomous": bool(item.get("mini_os", True)),
            "layers": item.get("layers", {}),
            "capabilities": item.get("capabilities", []),
            "resource_intent": resource_intent,
            "slice": item.get("runtime_slice", f"seven-{key}.slice"),
            "priority": int(item.get("priority", 100)),
            "anti_nuisance": item.get("anti_nuisance", []),
            "center_command": item.get("center_command", f"seven-mini-os-center {key}"),
            "package_files": item.get("package_files", []),
            "optional_package_files": item.get("optional_package_files", []),
        }
    return profiles, catalog


PROFILES, CATALOG = load_profiles()

CONFLICT_RULES = {
    frozenset(("forge", "shield")): {
        "conflict": "interactive builds and continuous audit can compete for CPU and IO",
        "resolution": "keep Forge as primary; run Shield audit event-driven with reduced background pressure",
    },
    frozenset(("studio", "shield")): {
        "conflict": "GPU/media rendering and heavy security scans can create latency spikes",
        "resolution": "prioritize Studio media path; Shield stays audit-only unless user confirms deep scans",
    },
    frozenset(("windows", "shield")): {
        "conflict": "Windows compatibility needs permissive app bridges while Shield prefers isolation",
        "resolution": "keep Windows prefix/VM usability; enable guarded network and explicit sandbox prompts",
    },
    frozenset(("studio", "windows")): {
        "conflict": "creative GPU workloads and Windows VM/Wine foreground workloads can both request high priority",
        "resolution": "primary runtime owns GPU priority; secondary compatibility runs foreground-only when focused",
    },
    frozenset(("pulse", "shield")): {
        "conflict": "low-latency gaming and active scans can create frame-time spikes",
        "resolution": "Pulse owns foreground latency; Shield only keeps passive rules unless explicitly confirmed",
    },
    frozenset(("pulse", "forge")): {
        "conflict": "latency-sensitive workloads and server daemons compete for network/IO smoothness",
        "resolution": "Pulse foreground traffic wins; Forge DevOps services stay background-limited",
    },
    frozenset(("baobab", "forge")): {
        "conflict": "Baobab is cultural-only while Forge can inject dev noise",
        "resolution": "keep Baobab cultural UI clean; Forge capabilities remain explicit and hidden unless requested",
    },
}


def command_state(command):
    return "OK" if shutil.which(command) else "MISS"


def run(command):
    return subprocess.run(command, text=True, capture_output=True, check=False)


def read_state():
    try:
        return json.loads(state_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


ALIASES = {"horizon": "forge"}

def normalize_key(item):
    return ALIASES.get(item, item)

def normalize_profiles(raw_items):
    normalized_items = [normalize_key(item) for item in raw_items]
    valid = [item for item in normalized_items if item in PROFILES]
    invalid = [
        raw for raw, normalized in zip(raw_items, normalized_items)
        if raw and normalized not in PROFILES
    ]
    if valid:
        primary = valid[0]
        capabilities = []
        for item in valid[1:]:
            if item != primary and item not in capabilities:
                capabilities.append(item)
        return primary, capabilities, invalid

    state = read_state()
    if state and state.get("primary_profile", {}).get("key") in PROFILES:
        primary = state["primary_profile"]["key"]
        capabilities = [
            item.get("key") for item in state.get("capabilities", [])
            if isinstance(item, dict) and item.get("key") in PROFILES and item.get("key") != primary
        ]
        return primary, capabilities, invalid

    primary = active_profile if active_profile in PROFILES else "equinox"
    return primary, [], invalid


def lifecycle_for(primary, capabilities):
    rows = []
    for key in PROFILES:
        if key == primary:
            state = "ACTIVE"
            reason = "main runtime profile"
        elif key in capabilities:
            state = "DEGRADED"
            reason = "injected as a capability module"
        else:
            state = "SUSPENDED"
            reason = "not loaded in the current composite runtime"
        rows.append({
            "profile": key,
            "title": PROFILES[key]["title"],
            "state": state,
            "reason": reason,
        })
    return rows


def resolve_conflicts(primary, capabilities):
    selected = [primary, *capabilities]
    conflicts = []
    resolutions = []
    for index, left in enumerate(selected):
        for right in selected[index + 1:]:
            rule = CONFLICT_RULES.get(frozenset((left, right)))
            if not rule:
                continue
            conflicts.append({"profiles": [left, right], "detail": rule["conflict"]})
            resolutions.append({"profiles": [left, right], "strategy": rule["resolution"]})
    if not conflicts:
        resolutions.append({
            "profiles": selected,
            "strategy": "no high-risk conflict detected; keep primary runtime isolated" if not capabilities else "no high-risk conflict detected; keep primary runtime and inject explicit capabilities with shared services",
        })
    return conflicts, resolutions


def capability_rows(primary, capabilities):
    rows = []
    for key in capabilities:
        profile = PROFILES[key]
        rows.append({
            "key": key,
            "title": profile["title"],
            "domain": profile["domain"],
            "role": profile["role"],
            "autonomous": profile["autonomous"],
            "layers": profile["layers"],
            "lifecycle": "DEGRADED",
            "capabilities": profile["capabilities"],
            "resource_intent": profile["resource_intent"],
            "anti_nuisance": profile.get("anti_nuisance", []),
            "injection_mode": "rules-and-services",
        })
    return rows


def composite_runtime(primary, capabilities):
    selected = [primary, *capabilities]
    merged = []
    for key in selected:
        for capability in PROFILES[key]["capabilities"]:
            if capability not in merged:
                merged.append(capability)
    return {
        "name": "+".join(selected),
        "primary": primary,
        "injected_profiles": capabilities,
        "capability_fusion": {
            "mode": "layered-autonomous-profiles",
            "deduplicate_services": True,
            "merged_capabilities": merged,
            "profiles_are_autonomous": True,
            "no_profile_dependency": True,
            "composition_layer": "controlled-collaboration",
            "inactive_profiles_are_not_auto_loaded": True,
        },
        "conflict_resolver": {
            "policy": "no-profile-pollution; equinox-arbitrates-when-primary",
            "confirmation_required_for": ["root changes", "service restarts", "network rewrites", "destructive cleanup"],
        },
    }


def resource_plan(primary, capabilities):
    primary_profile = PROFILES[primary]
    selected = [primary, *capabilities]
    max_priority = max(PROFILES[key]["priority"] for key in selected)
    cgroups_ready = Path("/sys/fs/cgroup/cgroup.controllers").exists()
    tc_ready = command_state("tc") == "OK"
    return {
        "status": "applicable" if cgroups_ready else "planned",
        "allocator": "Seven Resource Allocator",
        "cpu": {
            "strategy": primary_profile["resource_intent"]["cpu"],
            "cgroups_v2": "available" if cgroups_ready else "planned",
            "primary_slice": primary_profile["slice"],
            "weight": max_priority,
            "secondary_policy": "degraded/background unless foregrounded",
        },
        "ram": {
            "strategy": primary_profile["resource_intent"]["ram"],
            "zram": "use-if-available",
            "secondary_policy": "profile-owned commands are launched in selected slices; inactive package capabilities stay quiet",
            "future": "CRIU snapshots for FROZEN/OFFLOADED profile state",
        },
        "gpu": {
            "strategy": primary_profile["resource_intent"]["gpu"],
            "foreground_owner": primary,
            "secondary_policy": "only foreground app receives elevated GPU priority",
        },
        "io": {
            "strategy": primary_profile["resource_intent"]["io"],
            "scheduler_hint": "ionice/cgroup IO weight available" if cgroups_ready else "ionice/cgroup IO weight planned",
            "secondary_policy": "throttle heavy background IO",
        },
        "network": {
            "strategy": primary_profile["resource_intent"]["network"],
            "qos": "available" if tc_ready else "planned",
            "security_overlay": "enabled" if "shield" in selected else "available",
        },
        "isolation": {
            "ram_pool": "partially-isolated",
            "cpu_quota": "dynamic",
            "gpu_context": "foreground-profile-owned",
            "filesystem": "profile-workspace-state",
            "services": "systemd-user-slices",
            "packages": "global install store with profile-scoped activation allowlist",
            "commands": "seven-profile-run shims enforce active profile capabilities",
        },
    }


def write_runtime_activation(payload, primary, capabilities):
    state_file.parent.mkdir(parents=True, exist_ok=True)
    user_systemd = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "systemd/user"
    user_systemd.mkdir(parents=True, exist_ok=True)

    selected = [primary, *capabilities]
    written_units = []
    selected_slices = {PROFILES[key]["slice"] for key in selected}
    for profile in PROFILES.values():
        stale_unit = user_systemd / profile["slice"]
        if profile["slice"] not in selected_slices and stale_unit.exists():
            stale_unit.unlink()

    for key in selected:
        profile = PROFILES[key]
        unit_path = user_systemd / profile["slice"]
        unit_path.write_text(
            "\n".join([
                "[Unit]",
                f"Description=SevenOS {profile['title']} runtime slice",
                "Documentation=https://sevenos.local/runtime",
                "",
                "[Slice]",
                f"CPUWeight={profile['priority']}",
                f"IOWeight={max(10, min(1000, profile['priority']))}",
                "ManagedOOMSwap=auto",
                "",
            ]),
            encoding="utf-8",
        )
        written_units.append(str(unit_path))

    runtime_env = state_file.parent / "runtime.env"
    runtime_env.write_text(
        "\n".join([
            f'SEVENOS_RUNTIME_PRIMARY="{primary}"',
            f'SEVENOS_RUNTIME_CAPABILITIES="{",".join(capabilities)}"',
            f'SEVENOS_RUNTIME_NAME="{payload["composite_runtime"]["name"]}"',
            f'SEVENOS_RUNTIME_SLICE="{PROFILES[primary]["slice"]}"',
            "",
        ]),
        encoding="utf-8",
    )

    payload["state"] = "active"
    payload["resource_plan"]["status"] = "applied"
    payload["resource_plan"]["applied_hooks"] = {
        "runtime_state": str(state_file),
        "runtime_env": str(runtime_env),
        "profile_isolation": str(state_file.parent / "profile-isolation.json"),
        "systemd_user_units": written_units,
        "reload_command": "systemctl --user daemon-reload",
        "launch_pattern": "systemd-run --user --scope --slice=<profile-slice> <command>",
    }
    payload["safe_execution"]["applied"] = True
    payload["safe_execution"]["requires_confirmation"] = False
    state_file.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    if shutil.which("systemctl"):
        subprocess.run(["systemctl", "--user", "daemon-reload"], text=True, capture_output=True, check=False)

    isolation_script = root / "scripts/profile-isolation.sh"
    if isolation_script.exists():
        subprocess.run(
            [str(isolation_script), "apply", primary, *capabilities, "--yes", "--json"],
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


def doctor_checks():
    checks = [
        {"name": "systemd", "state": command_state("systemctl"), "role": "service and slice control"},
        {"name": "cgroups_v2", "state": "OK" if Path("/sys/fs/cgroup/cgroup.controllers").exists() else "MISS", "role": "CPU/RAM/IO resource control"},
        {"name": "seven_scheduler", "state": "OK" if (root / "scripts/scheduler.sh").exists() else "MISS", "role": "profile-aware process policy"},
        {"name": "seven_context", "state": "OK" if (root / "scripts/context.sh").exists() else "MISS", "role": "semantic observation"},
        {"name": "zram", "state": "OK" if Path("/sys/block/zram0").exists() or command_state("zramctl") == "OK" else "MISS", "role": "compressed memory support"},
        {"name": "tc", "state": command_state("tc"), "role": "future network QoS"},
        {"name": "criu", "state": command_state("criu"), "role": "future profile checkpoint/restore", "install": "./install.sh runtime-tools --yes"},
        {"name": "hyprctl", "state": command_state("hyprctl"), "role": "desktop context and workspace control"},
    ]
    ready = sum(1 for item in checks if item["state"] == "OK")
    return {"checks": checks, "ready": ready, "total": len(checks), "percent": round((ready / len(checks)) * 100)}


primary, capabilities, invalid = normalize_profiles(items)
profile = PROFILES[primary]
conflicts, resolutions = resolve_conflicts(primary, capabilities)
doctor = doctor_checks()

payload = {
    "schema": "sevenos.runtime-orchestrator.v1",
    "model": "layered-autonomous-profiles-architecture",
    "golden_rule": "no profile dependency, only profile collaboration",
    "action": action,
    "state": "active" if action == "status" and read_state() else "planned",
    "generated_at": int(time.time()),
    "host": platform.node(),
    "active_profile": active_profile,
    "primary_profile": {
        "key": primary,
        "title": profile["title"],
        "domain": profile["domain"],
        "role": profile["role"],
        "autonomous": profile["autonomous"],
        "layers": profile["layers"],
        "lifecycle": "ACTIVE",
        "capabilities": profile["capabilities"],
        "resource_intent": profile["resource_intent"],
        "anti_nuisance": profile.get("anti_nuisance", []),
    },
    "capabilities": capability_rows(primary, capabilities),
    "composite_runtime": composite_runtime(primary, capabilities),
    "resource_plan": resource_plan(primary, capabilities),
    "conflicts": conflicts,
    "resolutions": resolutions,
    "lifecycle": lifecycle_for(primary, capabilities),
    "doctor": doctor,
    "context": {
        "schema": context.get("schema") if isinstance(context, dict) else None,
        "primary_context": context.get("primary_context", {}) if isinstance(context, dict) else {},
    },
    "scheduler": {
        "schema": scheduler.get("schema") if isinstance(scheduler, dict) else None,
        "active_policy": scheduler.get("active_policy", {}) if isinstance(scheduler, dict) else {},
    },
    "invalid_profiles": invalid,
    "safe_execution": {
        "apply_requested": apply_requested,
        "yes": yes,
        "applied": False,
        "requires_confirmation": action == "activate" and not (apply_requested and yes),
    },
    "next_actions": [
        {"command": "seven runtime plan equinox forge shield studio pulse", "reason": "preview the neutral global profile with controlled capability fragments"},
        {"command": "seven runtime plan baobab shield forge", "reason": "verify Baobab stays culturally clean while collaborating with other profiles"},
        {"command": "seven scheduler plan", "reason": "inspect CPU/IO/user-space scheduler hints"},
        {"command": "seven context status --json", "reason": "see what SevenOS currently detects from apps and windows"},
        {"command": "seven ai diagnose system --json", "reason": "let SevenAI explain local bottlenecks before repair"},
    ],
}

if action == "capabilities":
    payload["available_profiles"] = [
        {
            "key": key,
            "title": value["title"],
            "role": value["role"],
            "domain": value["domain"],
            "autonomous": value["autonomous"],
            "layers": value["layers"],
            "capabilities": value["capabilities"],
            "resource_intent": value["resource_intent"],
        }
        for key, value in PROFILES.items()
    ]

if action == "doctor":
    payload["state"] = "ready" if doctor["ready"] >= 5 else "partial"

if action == "activate" and apply_requested and yes and not dry_run:
    write_runtime_activation(payload, primary, capabilities)
elif action == "activate" and apply_requested and yes and dry_run:
    payload["state"] = "preview"
    payload["resource_plan"]["status"] = "would-apply"
    payload["resource_plan"]["applied_hooks"] = {
        "runtime_state": str(state_file),
        "runtime_env": str(state_file.parent / "runtime.env"),
        "profile_isolation": str(state_file.parent / "profile-isolation.json"),
        "systemd_user_units": [str(Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "systemd/user" / PROFILES[key]["slice"]) for key in [primary, *capabilities]],
        "reload_command": "systemctl --user daemon-reload",
        "launch_pattern": "systemd-run --user --scope --slice=<profile-slice> <command>",
    }

print(json.dumps(payload, indent=2))
PY
}

print_human() {
  RUNTIME_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["RUNTIME_JSON"])
primary = data["primary_profile"]
caps = data.get("capabilities", [])

print("Seven Runtime Orchestrator")
print("==========================")
print(f"Model: {data.get('model')}")
print(f"Active profile: {data.get('active_profile')}")
print(f"Runtime primary: {primary['title']} ({primary['key']})")
if caps:
    print("Injected capabilities: " + ", ".join(f"{item['title']} ({item['key']})" for item in caps))
else:
    print("Injected capabilities: none")
print()

print("Composite runtime:")
fusion = data["composite_runtime"]["capability_fusion"]
print(f"- mode: {fusion['mode']}")
print(f"- services duplicated: {'no' if fusion['deduplicate_services'] else 'yes'}")
print(f"- merged capabilities: {', '.join(fusion['merged_capabilities'])}")
print()

print("Resource plan:")
plan = data["resource_plan"]
for key in ("cpu", "ram", "gpu", "io", "network"):
    section = plan[key]
    print(f"- {key.upper()}: {section.get('strategy')} ({section.get('secondary_policy', section.get('qos', 'planned'))})")
print()

if data.get("conflicts"):
    print("Conflicts:")
    for item in data["conflicts"]:
        print(f"- {' + '.join(item['profiles'])}: {item['detail']}")
    print()

print("Resolutions:")
for item in data.get("resolutions", []):
    profiles = item.get("profiles", [])
    if isinstance(profiles, list):
        profiles = " + ".join(profiles)
    print(f"- {profiles}: {item.get('strategy')}")
print()

print("Lifecycle:")
for item in data.get("lifecycle", []):
    print(f"- {item['title']}: {item['state']} · {item['reason']}")
print()

doctor = data.get("doctor", {})
if doctor:
    print(f"Runtime doctor: {doctor.get('ready', 0)}/{doctor.get('total', 0)} ({doctor.get('percent', 0)}%)")
    missing = [item for item in doctor.get("checks", []) if item.get("state") != "OK"]
    if missing:
        print("Missing or future hooks: " + ", ".join(item["name"] for item in missing))
print()

safe = data.get("safe_execution", {})
if data.get("action") == "activate":
    if safe.get("applied"):
        print("Activation: saved as current composite runtime.")
    else:
        print("Activation: preview only. Add --apply --yes to save this composite runtime.")
elif data.get("action") == "capabilities":
    print("Available profiles:")
    for item in data.get("available_profiles", []):
        print(f"- {item['title']}: {', '.join(item['capabilities'])}")
PY
}

payload="$(json_payload)"

if [[ "$ACTION" == "activate" && "$APPLY" == "1" && "$YES" == "1" && "${SEVENOS_DRY_RUN:-0}" != "1" && -x "$ROOT_DIR/scripts/mini-os-bridge.sh" ]]; then
  "$ROOT_DIR/scripts/mini-os-bridge.sh" status --json >/dev/null 2>&1 || true
fi

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
else
  print_human "$payload"
fi
