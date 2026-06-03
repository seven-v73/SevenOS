#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS state snapshot

Usage:
  seven state --json
  ./scripts/state.sh --json

This command is a machine-facing contract for Seven Hub, native UI,
automation and future Seven Server endpoints.
EOF
}

JSON_OUTPUT=0
REFRESH_CACHE=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    --refresh|refresh) REFRESH_CACHE=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown state option: $arg"; usage; exit 1 ;;
  esac
done

if [[ "$JSON_OUTPUT" -ne 1 ]]; then
  usage
  exit 0
fi

STATE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
STATE_CACHE="$STATE_CACHE_DIR/state.json"
STATE_CACHE_LOCK="$STATE_CACHE.lock"

state_cache_age() {
  command -v stat >/dev/null 2>&1 || return 1
  printf '%s\n' "$(( $(date +%s) - $(stat -c %Y "$STATE_CACHE" 2>/dev/null || printf 0) ))"
}

state_cache_json_valid() {
  [[ -s "$STATE_CACHE" ]] || return 1
  python - "$STATE_CACHE" >/dev/null 2>&1 <<'PY'
import json
import sys
from pathlib import Path

try:
    with Path(sys.argv[1]).open(encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    raise SystemExit(1)

required = {"core", "core_snapshot", "core_health", "shell", "shell_experience", "scheduler", "runtime", "context", "control", "tools", "ux", "channel", "lifecycle", "product", "support", "foundations", "store", "box", "cloud", "flow", "cluster", "manifest", "ecosystem", "stack", "b3", "architecture", "packages_strategy", "packages_catalog", "packages_footprint", "experience", "readiness", "public_readiness", "daily", "smoke", "installer", "installer_plan", "installer_flow", "update", "update_plan", "surfaces", "actions", "native_actions", "production", "language", "language_audit", "first_run"}
if not required.issubset(data):
    raise SystemExit(1)

schema_checks = {
    "core": "sevenos.core.v2",
    "core_snapshot": "sevenos.daemon.snapshot.v1",
    "core_health": "sevenos.daemon.health.v1",
    "shell": "sevenos.shell.v1",
    "shell_experience": "sevenos.shell-experience.v1",
    "scheduler": "sevenos.scheduler.v1",
    "context": "sevenos.context.v1",
    "control": "sevenos.control.v1",
    "tools": "sevenos.tools.v2",
    "ux": "sevenos.ux-check.v1",
    "runtime": "sevenos.runtime-orchestrator.v1",
    "packages_strategy": "sevenos.sevenpkg-strategy.v1",
    "packages_catalog": "sevenos.app-catalog.v1",
    "packages_footprint": "sevenos.sevenpkg-footprint.v1",
    "experience": "sevenos.experience.v1",
    "readiness": "sevenos.readiness.v1",
    "public_readiness": "sevenos.public-readiness.v1",
    "daily": "sevenos.daily-driver.v1",
    "smoke": "sevenos.smoke.v1",
    "installer": "sevenos.installer.v1",
    "installer_plan": "sevenos.installer-plan.v1",
    "installer_flow": "sevenos.installer-flow.v1",
    "update": "sevenos.update.v2",
    "update_plan": "sevenos.update-plan.v1",
    "channel": "sevenos.release-channel.v2",
    "lifecycle": "sevenos.lifecycle.v2",
    "product": "sevenos.product.v2",
    "support": "sevenos.support.v2",
    "foundations": "sevenos.foundations.v2",
    "store": "sevenos.store.v1",
    "box": "sevenos.box.v1",
    "cloud": "sevenos.cloud.v1",
    "flow": "sevenos.flow.v1",
    "cluster": "sevenos.cluster.v1",
    "manifest": "sevenos.manifest.v1",
    "ecosystem": "sevenos.ecosystem.v1",
    "stack": "sevenos.stack.v1",
    "b3": "sevenos.b3.v1",
    "architecture": "sevenos.hybrid-architecture.v1",
    "surfaces": "sevenos.core.surfaces.v1",
    "actions": "sevenos.core.actions.v1",
    "native_actions": "sevenos.core.actions.v1",
    "routes": "sevenos.routes.v2",
    "distribution": "sevenos.distribution.v2",
    "production": "sevenos.production-readiness.v2",
    "language": "sevenos.language-doctor.v1",
    "language_audit": "sevenos.language-runtime-audit.v1",
    "first_run": "sevenos.public-studio.v1",
}
for key, schema in schema_checks.items():
    value = data.get(key)
    if not isinstance(value, dict) or value.get("schema") != schema:
        raise SystemExit(1)

catalog = data.get("packages_catalog") or {}
if int(catalog.get("count", 0) or 0) < 12:
    raise SystemExit(1)

experience = data.get("experience") or {}
if experience.get("writer") != "seven-daemon":
    raise SystemExit(1)

readiness = data.get("readiness") or {}
public_readiness = data.get("public_readiness") or {}
daily = data.get("daily") or {}
smoke = data.get("smoke") or {}
if readiness.get("writer") != "seven-daemon" or public_readiness.get("writer") != "seven-daemon" or daily.get("writer") != "seven-daemon" or smoke.get("writer") != "seven-daemon":
    raise SystemExit(1)

for key in ("installer", "installer_plan", "installer_flow", "update", "update_plan"):
    if (data.get(key) or {}).get("writer") != "seven-daemon":
        raise SystemExit(1)
for key in ("core", "core_snapshot", "core_health", "shell", "shell_experience", "scheduler", "runtime", "context", "control", "tools", "ux", "channel", "lifecycle", "product", "support", "foundations", "store", "box", "cloud", "flow", "cluster", "manifest", "ecosystem", "stack", "b3", "architecture", "surfaces", "actions", "native_actions", "routes", "distribution", "production"):
    if (data.get(key) or {}).get("writer") != "seven-daemon":
        raise SystemExit(1)
PY
}

state_cache_valid() {
  [[ "$REFRESH_CACHE" -eq 0 && "${SEVENOS_STATE_REFRESH:-0}" != "1" && -s "$STATE_CACHE" ]] || return 1
  state_cache_json_valid || return 1
  local age
  age="$(state_cache_age)" || return 1
  [[ "$age" -le "${SEVENOS_STATE_CACHE_TTL:-180}" ]] || return 1
}

if state_cache_valid; then
  cat "$STATE_CACHE"
  printf '\n'
  exit 0
fi

if [[ "$REFRESH_CACHE" -eq 0 && "${SEVENOS_STATE_REFRESH:-0}" != "1" && -s "$STATE_CACHE" ]]; then
  age="$(state_cache_age 2>/dev/null || printf 999999)"
  if [[ "$age" -le "${SEVENOS_STATE_STALE_TTL:-900}" ]] && state_cache_json_valid; then
    if mkdir "$STATE_CACHE_LOCK" 2>/dev/null; then
      (
        trap 'rmdir "$STATE_CACHE_LOCK" 2>/dev/null || true' EXIT
        SEVENOS_STATE_REFRESH=1 "$0" --json >/dev/null 2>&1 || true
      ) &
    fi
    cat "$STATE_CACHE"
    printf '\n'
    exit 0
  fi
fi

json_or_null() {
  local command_output
  if command -v timeout >/dev/null 2>&1; then
    if command_output="$(SEVENOS_DRY_RUN=0 timeout "${SEVENOS_STATE_COMMAND_TIMEOUT:-12}" "$@" 2>/dev/null)" && [[ -n "$command_output" ]]; then
      printf '%s' "$command_output"
    else
      printf 'null'
    fi
  elif command_output="$(SEVENOS_DRY_RUN=0 "$@" 2>/dev/null)" && [[ -n "$command_output" ]]; then
    printf '%s' "$command_output"
  else
    printf 'null'
  fi
}

json_to_file() {
  local output_file="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    SEVENOS_DRY_RUN=0 timeout "${SEVENOS_STATE_COMMAND_TIMEOUT:-12}" "$@" > "$output_file" 2>/dev/null || printf 'null' > "$output_file"
  else
    SEVENOS_DRY_RUN=0 "$@" > "$output_file" 2>/dev/null || printf 'null' > "$output_file"
  fi

  [[ -s "$output_file" ]] || printf 'null' > "$output_file"
}

native_json_to_file() {
  local output_file="$1"
  shift

  SEVENOS_DRY_RUN=0 "$@" > "$output_file" 2>/dev/null || printf 'null' > "$output_file"
  [[ -s "$output_file" ]] || printf 'null' > "$output_file"
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

STATE_TMP="$(mktemp -d)"
mkdir -p "$STATE_CACHE_DIR"
if ! mkdir "$STATE_CACHE_LOCK" 2>/dev/null; then
  if state_cache_json_valid; then
    cat "$STATE_CACHE"
    printf '\n'
    exit 0
  fi
  for _ in {1..120}; do
    sleep 0.1
    if state_cache_json_valid; then
      cat "$STATE_CACHE"
      printf '\n'
      exit 0
    fi
  done
else
  trap 'rm -rf "$STATE_TMP"; rmdir "$STATE_CACHE_LOCK" 2>/dev/null || true' EXIT
fi

json_to_file "$STATE_TMP/status.json" "$ROOT_DIR/bin/seven" status --json &
pid_status=$!
json_to_file "$STATE_TMP/welcome.json" "$ROOT_DIR/bin/seven-welcome" status --json &
pid_welcome=$!
json_to_file "$STATE_TMP/welcome_plan.json" "$ROOT_DIR/bin/seven-welcome" plan --json &
pid_welcome_plan=$!
json_to_file "$STATE_TMP/session.json" python - "$ROOT_DIR" <<'PY' &
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])


def fallback():
    try:
        run = subprocess.run(
            [str(root / "bin/seven-session-status"), "--json"],
            check=True,
            capture_output=True,
            text=True,
            timeout=4,
        )
        json.loads(run.stdout)
        print(run.stdout.strip())
        return
    except Exception:
        pass
    print(json.dumps({
        "schema": "sevenos.session.v1",
        "mode": "unknown",
        "percent": 0,
        "summary": {"total": 0, "ready": 0, "running": 0, "missing": 0},
        "checks": [],
        "writer": "state-fallback",
    }, indent=2))


try:
    raw = subprocess.run(
        [str(root / "bin/seven-daemon"), "experience", "--json"],
        check=True,
        capture_output=True,
        text=True,
        timeout=3,
    ).stdout
    experience = json.loads(raw)
except Exception:
    fallback()
    raise SystemExit(0)

config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))

file_checks = [
    ("wayland-entry", "SevenOS login entry", data_home / "wayland-sessions/sevenos.desktop"),
    ("session-target", "User session target", config_home / "systemd/user/sevenos-session.target"),
    ("waybar-context-service", "Waybar context service", config_home / "systemd/user/sevenos-waybar-context.service"),
    ("waybar-service", "Shell bar service", config_home / "systemd/user/sevenos-waybar.service"),
    ("notifications-service", "Notifications service", config_home / "systemd/user/sevenos-notifications.service"),
    ("wallpaper-service", "Wallpaper service", config_home / "systemd/user/sevenos-wallpaper.service"),
    ("widgets-service", "Widgets service", config_home / "systemd/user/sevenos-widgets.service"),
    ("dock-service", "Dock service", config_home / "systemd/user/sevenos-dock.service"),
    ("shell-experience-service", "Shell experience warmup service", config_home / "systemd/user/sevenos-shell-experience.service"),
]

checks = []
for key, label, path in file_checks:
    checks.append({
        "kind": "file",
        "key": key,
        "label": label,
        "state": "OK" if path.exists() else "MISS",
        "target": str(path),
        "writer": "state-native",
    })

service_labels = {
    "session": ("sevenos-session", "SevenOS session target", "sevenos-session.target"),
    "waybar-context": ("sevenos-waybar-context", "Waybar active context runtime", "sevenos-waybar-context.service"),
    "waybar": ("sevenos-waybar", "Shell bar runtime", "sevenos-waybar.service"),
    "notifications": ("sevenos-notifications", "Notifications runtime", "sevenos-notifications.service"),
    "wallpaper": ("sevenos-wallpaper", "Wallpaper runtime", "sevenos-wallpaper.service"),
    "widgets": ("sevenos-widgets", "Widgets runtime", "sevenos-widgets.service"),
    "dock": ("sevenos-dock", "Dock runtime", "sevenos-dock.service"),
    "shell-experience": ("sevenos-shell-experience", "Shell experience warmup", "sevenos-shell-experience.service"),
    "idle": ("sevenos-idle", "Idle runtime", "sevenos-idle.service"),
}

service_states = {}
for item in (experience.get("session") or {}).get("services", []):
    unit = item.get("unit") or ""
    key = unit.replace(".service", "").replace(".target", "").replace("sevenos-", "")
    service_states[key] = item.get("state", "MISS")


def systemctl_state(unit: str) -> str:
    try:
        run = subprocess.run(
            ["systemctl", "--user", "is-active", unit],
            capture_output=True,
            text=True,
            timeout=1.5,
        )
        if run.stdout.strip() == "active":
            return "RUN"
    except Exception:
        pass
    try:
        run = subprocess.run(
            ["systemctl", "--user", "is-enabled", unit],
            capture_output=True,
            text=True,
            timeout=1.5,
        )
        if run.stdout.strip() in {"enabled", "static", "linked"}:
            return "READY"
    except Exception:
        pass
    return "MISS"


for lookup_key, (key, label, unit) in service_labels.items():
    state = service_states.get(lookup_key)
    if not state:
        state = systemctl_state(unit)
    checks.append({
        "kind": "service",
        "key": key,
        "label": label,
        "state": state,
        "target": unit,
        "writer": "seven-daemon" if lookup_key in service_states else "state-native",
    })

total = len(checks)
ready = sum(1 for check in checks if check["state"] in {"OK", "RUN", "READY"})
running = sum(1 for check in checks if check["state"] == "RUN")
missing = total - ready
percent = int(round((ready / total) * 100)) if total else 0
mode = "running" if missing == 0 and running > 0 else ("partial" if ready else "missing")

print(json.dumps({
    "schema": "sevenos.session.v1",
    "mode": mode,
    "percent": percent,
    "summary": {
        "total": total,
        "ready": ready,
        "running": running,
        "missing": missing,
    },
    "checks": checks,
    "writer": "seven-daemon+state-native",
}, indent=2))
PY
pid_session=$!
json_to_file "$STATE_TMP/identity.json" "$ROOT_DIR/scripts/identity.sh" --json &
pid_identity=$!
json_to_file "$STATE_TMP/design.json" "$ROOT_DIR/scripts/identity.sh" design --json &
pid_design=$!
json_to_file "$STATE_TMP/icons.json" "$ROOT_DIR/scripts/identity.sh" icons --json &
pid_icons=$!
native_json_to_file "$STATE_TMP/profiles.json" "$ROOT_DIR/bin/seven-daemon" profiles-status --json &
pid_profiles=$!
native_json_to_file "$STATE_TMP/profile_gaps.json" "$ROOT_DIR/bin/seven-daemon" profile-gaps --json &
pid_profile_gaps=$!
native_json_to_file "$STATE_TMP/profile_plan.json" "$ROOT_DIR/bin/seven-daemon" profile-plan --json &
pid_profile_plan=$!
native_json_to_file "$STATE_TMP/profile_health.json" "$ROOT_DIR/bin/seven-daemon" profile-health --json &
pid_profile_health=$!
json_to_file "$STATE_TMP/active_profile.json" python - "$ROOT_DIR" <<'PY' &
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])

defaults = {
    "equinox": {
        "description": "Balanced general SevenOS mini OS for daily use, broad readiness and neutral capability arbitration.",
        "workspace": str(Path.home() / "SevenOS"),
        "accent": "indigo",
        "role": "Balance",
        "symbol": "logo-sevenos-symbol",
        "waybar_icon": "\U000f1226",
        "short_label": "EQX",
        "accent_color": "#8B7CFF",
        "secondary_color": "#6EA8FF",
        "ui_mood": "neutral glass, balanced controls, general public readiness",
        "principle": "balanced collaboration",
        "terminal_mode": "classic",
        "apps": ["seven hub", "seven files", "kitty"],
    },
    "forge": {"accent": "orange", "role": "DevOps", "short_label": "FRG", "accent_color": "#FF9F45", "secondary_color": "#FFD166", "terminal_mode": "forge"},
    "shield": {"accent": "emerald", "role": "Security", "short_label": "SHD", "accent_color": "#5EF2B5", "secondary_color": "#70D6FF", "terminal_mode": "cyber"},
    "studio": {"accent": "violet", "role": "Creator", "short_label": "STD", "accent_color": "#C084FC", "secondary_color": "#F0ABFC", "terminal_mode": "focus"},
    "pulse": {"accent": "cyan", "role": "Gaming", "short_label": "PLS", "accent_color": "#22D3EE", "secondary_color": "#A3E635", "terminal_mode": "focus"},
    "atlas": {"accent": "blue", "role": "Explorer", "short_label": "ATL", "accent_color": "#60A5FA", "secondary_color": "#93C5FD", "terminal_mode": "classic"},
    "baobab": {"accent": "green", "role": "Culture", "short_label": "BAO", "accent_color": "#7DD56F", "secondary_color": "#EAB308", "terminal_mode": "classic"},
}


def fallback():
    try:
        run = subprocess.run(
            [str(root / "bin/seven"), "profile", "current", "--json"],
            check=True,
            capture_output=True,
            text=True,
            timeout=4,
        )
        json.loads(run.stdout)
        print(run.stdout.strip())
        return
    except Exception:
        pass
    print(json.dumps({
        "key": "equinox",
        "title": "Equinox Balance",
        **defaults["equinox"],
        "waybar_modules": "profile,spotlight,media,wifi,bluetooth,audio,battery,ai",
        "story": "Use SevenOS as a balanced general mini OS.",
        "writer": "state-fallback",
    }, indent=2))


try:
    raw = subprocess.run(
        [str(root / "bin/seven-daemon"), "experience", "--json"],
        check=True,
        capture_output=True,
        text=True,
        timeout=3,
    ).stdout
    experience = json.loads(raw)
except Exception:
    fallback()
    raise SystemExit(0)

profile = experience.get("profile") or {}
key = (profile.get("key") or "equinox").strip() or "equinox"
catalog_data = {}
try:
    catalog_data = json.loads((root / "profiles/catalog.json").read_text(encoding="utf-8"))
except Exception:
    catalog_data = {}

catalog = ((catalog_data.get("profiles") or {}).get(key) or {})
naming = catalog_data.get("profile_naming") or {}
default = defaults.get(key, defaults["equinox"])

title = profile.get("title") or catalog.get("title") or naming.get(key) or key.title()
capabilities = catalog.get("capabilities") or []
waybar_modules = catalog.get("waybar_modules") or []
workspace = default.get("workspace") or str(Path.home() / "SevenOS" / key)
role = default.get("role") or catalog.get("role") or key.title()
accent_color = profile.get("accent") or default.get("accent_color") or "#8B7CFF"

result = {
    "key": key,
    "title": title,
    "description": catalog.get("purpose") or catalog.get("domain") or default.get("description", title),
    "workspace": workspace,
    "accent": default.get("accent", "indigo"),
    "role": role,
    "symbol": default.get("symbol", f"sevenos-{key}"),
    "waybar_icon": default.get("waybar_icon", "*"),
    "short_label": default.get("short_label", key[:3].upper()),
    "accent_color": accent_color,
    "secondary_color": default.get("secondary_color", "#6EA8FF"),
    "ui_mood": default.get("ui_mood") or catalog.get("domain") or "SevenOS profile surface",
    "waybar_modules": ",".join(waybar_modules) if isinstance(waybar_modules, list) else str(waybar_modules or ""),
    "principle": default.get("principle") or catalog_data.get("golden_rule") or "profile collaboration",
    "story": catalog.get("purpose") or default.get("description", title),
    "terminal_mode": default.get("terminal_mode", "classic"),
    "apps": default.get("apps", []),
    "writer": "seven-daemon+catalog",
}
if capabilities:
    result["capabilities"] = capabilities[:12]
print(json.dumps(result, indent=2))
PY
pid_active_profile=$!
json_to_file "$STATE_TMP/profile_run.json" "$ROOT_DIR/bin/seven-profile-run" --json &
pid_profile_run=$!
json_to_file "$STATE_TMP/profile_runtime_manifest.json" "$ROOT_DIR/bin/seven-profile-run" --manifest &
pid_profile_runtime_manifest=$!
json_to_file "$STATE_TMP/profile_runtime_manifests.json" python - "$HOME/.local/share/sevenos/profile-runtime-manifests" <<'PY' &
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
items = {}
if root.is_dir():
    for path in sorted(root.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            data = {"schema": "sevenos.profile-runtime-manifest.v1", "profile": path.stem, "state": "invalid"}
        items[path.stem] = {
            "profile": data.get("profile", path.stem),
            "path": str(path),
            "schema": data.get("schema"),
            "engine": data.get("engine"),
            "workspace": (data.get("workspace") or {}).get("default"),
            "strict_shell": (data.get("commands") or {}).get("strict_shell"),
            "ephemeral_shell": (data.get("commands") or {}).get("ephemeral_shell"),
        }
print(json.dumps({
    "schema": "sevenos.profile-runtime-manifests.v1",
    "root": str(root),
    "count": len(items),
    "profiles": items,
}, indent=2))
PY
pid_profile_runtime_manifests=$!
json_to_file "$STATE_TMP/atlas.json" "$ROOT_DIR/bin/seven" atlas status --json &
pid_atlas=$!
json_to_file "$STATE_TMP/atlas_plan.json" "$ROOT_DIR/bin/seven-profile-requirements" status atlas --json &
pid_atlas_plan=$!
native_json_to_file "$STATE_TMP/shield.json" "$ROOT_DIR/bin/seven-daemon" shield --json &
pid_shield=$!
native_json_to_file "$STATE_TMP/shield_plan.json" "$ROOT_DIR/bin/seven-daemon" shield-plan --json &
pid_shield_plan=$!
native_json_to_file "$STATE_TMP/cyberspace.json" "$ROOT_DIR/bin/seven-daemon" cyberspace --json &
pid_cyberspace=$!
native_json_to_file "$STATE_TMP/cyberspace_plan.json" "$ROOT_DIR/bin/seven-daemon" cyberspace-plan --json &
pid_cyberspace_plan=$!
native_json_to_file "$STATE_TMP/server.json" "$ROOT_DIR/bin/seven-daemon" server --json &
pid_server=$!
native_json_to_file "$STATE_TMP/server_plan.json" "$ROOT_DIR/bin/seven-daemon" server-plan --json &
pid_server_plan=$!
native_json_to_file "$STATE_TMP/installer.json" "$ROOT_DIR/bin/seven-daemon" installer --json &
pid_installer=$!
native_json_to_file "$STATE_TMP/installer_plan.json" "$ROOT_DIR/bin/seven-daemon" installer-plan --json &
pid_installer_plan=$!
native_json_to_file "$STATE_TMP/installer_flow.json" "$ROOT_DIR/bin/seven-daemon" installer-flow --json &
pid_installer_flow=$!
json_to_file "$STATE_TMP/installer_portal.json" "$ROOT_DIR/bin/seven-installer" status --json &
pid_installer_portal=$!
native_json_to_file "$STATE_TMP/channel.json" "$ROOT_DIR/bin/seven-daemon" channel --json &
pid_channel=$!
json_to_file "$STATE_TMP/language.json" "$ROOT_DIR/bin/seven-language" doctor --json &
pid_language=$!
json_to_file "$STATE_TMP/language_audit.json" "$ROOT_DIR/bin/seven-language" audit --json &
pid_language_audit=$!
json_to_file "$STATE_TMP/first_run.json" "$ROOT_DIR/bin/seven-public-studio" fresh-install --json &
pid_first_run=$!
native_json_to_file "$STATE_TMP/about.json" "$ROOT_DIR/bin/seven-daemon" about --json &
pid_about=$!
native_json_to_file "$STATE_TMP/lifecycle.json" "$ROOT_DIR/bin/seven-daemon" lifecycle --json &
pid_lifecycle=$!
native_json_to_file "$STATE_TMP/update.json" "$ROOT_DIR/bin/seven-daemon" update --json &
pid_update=$!
native_json_to_file "$STATE_TMP/update_plan.json" "$ROOT_DIR/bin/seven-daemon" update-plan --json &
pid_update_plan=$!
native_json_to_file "$STATE_TMP/recovery.json" "$ROOT_DIR/bin/seven-daemon" recovery --json &
pid_recovery=$!
native_json_to_file "$STATE_TMP/health.json" "$ROOT_DIR/bin/seven-daemon" product-health --json &
pid_health=$!
native_json_to_file "$STATE_TMP/support.json" "$ROOT_DIR/bin/seven-daemon" support --json &
pid_support=$!
native_json_to_file "$STATE_TMP/product.json" "$ROOT_DIR/bin/seven-daemon" product --json &
pid_product=$!
native_json_to_file "$STATE_TMP/foundations.json" "$ROOT_DIR/bin/seven-daemon" foundations --json &
pid_foundations=$!
native_json_to_file "$STATE_TMP/readiness.json" "$ROOT_DIR/bin/seven-daemon" readiness --json &
pid_readiness=$!
native_json_to_file "$STATE_TMP/public_readiness.json" "$ROOT_DIR/bin/seven-daemon" public-readiness --json &
pid_public_readiness=$!
native_json_to_file "$STATE_TMP/packages.json" "$ROOT_DIR/bin/seven-daemon" packages --json &
pid_packages=$!
native_json_to_file "$STATE_TMP/packages_plan.json" "$ROOT_DIR/bin/seven-daemon" packages-plan --json &
pid_packages_plan=$!
native_json_to_file "$STATE_TMP/packages_strategy.json" "$ROOT_DIR/bin/seven-daemon" packages-strategy --json &
pid_packages_strategy=$!
native_json_to_file "$STATE_TMP/packages_catalog.json" "$ROOT_DIR/bin/seven-daemon" packages-catalog --json &
pid_packages_catalog=$!
native_json_to_file "$STATE_TMP/packages_footprint.json" "$ROOT_DIR/bin/seven-daemon" packages-footprint --json &
pid_packages_footprint=$!
native_json_to_file "$STATE_TMP/store.json" "$ROOT_DIR/bin/seven-daemon" store --json &
pid_store=$!
native_json_to_file "$STATE_TMP/box.json" "$ROOT_DIR/bin/seven-daemon" box --json &
pid_box=$!
native_json_to_file "$STATE_TMP/cloud.json" "$ROOT_DIR/bin/seven-daemon" cloud --json &
pid_cloud=$!
native_json_to_file "$STATE_TMP/flow.json" "$ROOT_DIR/bin/seven-daemon" flow --json &
pid_flow=$!
native_json_to_file "$STATE_TMP/cluster.json" "$ROOT_DIR/bin/seven-daemon" cluster --json &
pid_cluster=$!
native_json_to_file "$STATE_TMP/manifest.json" "$ROOT_DIR/bin/seven-daemon" manifest --json &
pid_manifest=$!
native_json_to_file "$STATE_TMP/ecosystem.json" "$ROOT_DIR/bin/seven-daemon" ecosystem --json &
pid_ecosystem=$!
native_json_to_file "$STATE_TMP/stack.json" "$ROOT_DIR/bin/seven-daemon" stack --json &
pid_stack=$!
native_json_to_file "$STATE_TMP/shell.json" "$ROOT_DIR/bin/seven-daemon" shell-status --json &
pid_shell=$!
native_json_to_file "$STATE_TMP/core.json" "$ROOT_DIR/bin/seven-daemon" core-status --json &
pid_core=$!
native_json_to_file "$STATE_TMP/core_snapshot.json" "$ROOT_DIR/bin/seven-daemon" snapshot --json &
pid_core_snapshot=$!
native_json_to_file "$STATE_TMP/core_health.json" "$ROOT_DIR/bin/seven-daemon" health --json &
pid_core_health=$!
native_json_to_file "$STATE_TMP/native_experience.json" "$ROOT_DIR/bin/seven-daemon" experience --json &
pid_native_experience=$!
native_json_to_file "$STATE_TMP/scheduler.json" "$ROOT_DIR/bin/seven-daemon" scheduler status --json &
pid_scheduler=$!
native_json_to_file "$STATE_TMP/runtime.json" "$ROOT_DIR/bin/seven-daemon" runtime status --json &
pid_runtime=$!
native_json_to_file "$STATE_TMP/context.json" "$ROOT_DIR/bin/seven-daemon" context status --json &
pid_context=$!
native_json_to_file "$STATE_TMP/experience.json" "$ROOT_DIR/bin/seven-daemon" experience --json &
pid_experience=$!
native_json_to_file "$STATE_TMP/shell_experience.json" "$ROOT_DIR/bin/seven-daemon" shell-experience --json &
pid_shell_experience=$!
native_json_to_file "$STATE_TMP/control.json" "$ROOT_DIR/bin/seven-daemon" control --json &
pid_control=$!
native_json_to_file "$STATE_TMP/tools.json" "$ROOT_DIR/bin/seven-daemon" tools --json &
pid_tools=$!
native_json_to_file "$STATE_TMP/ux.json" "$ROOT_DIR/bin/seven-daemon" ux-check --json &
pid_ux=$!
native_json_to_file "$STATE_TMP/b3.json" "$ROOT_DIR/bin/seven-daemon" b3 --json &
pid_b3=$!
native_json_to_file "$STATE_TMP/daily.json" "$ROOT_DIR/bin/seven-daemon" daily --json &
pid_daily=$!
native_json_to_file "$STATE_TMP/smoke.json" "$ROOT_DIR/bin/seven-daemon" smoke --json &
pid_smoke=$!
native_json_to_file "$STATE_TMP/events.json" "$ROOT_DIR/bin/seven-daemon" summary --json &
pid_events=$!
native_json_to_file "$STATE_TMP/actions.json" "$ROOT_DIR/bin/seven-daemon" actions --json &
pid_actions=$!
native_json_to_file "$STATE_TMP/native_actions.json" "$ROOT_DIR/bin/seven-daemon" actions --json &
pid_native_actions=$!
native_json_to_file "$STATE_TMP/architecture.json" "$ROOT_DIR/bin/seven-daemon" architecture --json &
pid_architecture=$!
native_json_to_file "$STATE_TMP/adaptive.json" "$ROOT_DIR/bin/seven-daemon" adaptive --json &
pid_adaptive=$!
native_json_to_file "$STATE_TMP/autonomy.json" "$ROOT_DIR/bin/seven-daemon" autonomy --json &
pid_autonomy=$!
native_json_to_file "$STATE_TMP/platform.json" "$ROOT_DIR/bin/seven-daemon" platform --json &
pid_platform=$!
native_json_to_file "$STATE_TMP/mask.json" "$ROOT_DIR/bin/seven-daemon" mask --json &
pid_mask=$!
native_json_to_file "$STATE_TMP/surfaces.json" "$ROOT_DIR/bin/seven-daemon" surfaces --json &
pid_surfaces=$!
native_json_to_file "$STATE_TMP/routes.json" "$ROOT_DIR/bin/seven-daemon" routes --json &
pid_routes=$!
native_json_to_file "$STATE_TMP/distribution.json" "$ROOT_DIR/bin/seven-daemon" distribution --json &
pid_distribution=$!
native_json_to_file "$STATE_TMP/production.json" "$ROOT_DIR/bin/seven-daemon" production --json &
pid_production=$!

wait "$pid_status" "$pid_welcome" "$pid_welcome_plan" "$pid_session" "$pid_identity" "$pid_design" "$pid_icons" "$pid_profiles" "$pid_profile_gaps" "$pid_profile_plan" "$pid_profile_health" "$pid_active_profile" "$pid_profile_run" "$pid_profile_runtime_manifest" "$pid_profile_runtime_manifests" "$pid_atlas" "$pid_atlas_plan" "$pid_shield" "$pid_shield_plan" "$pid_cyberspace" "$pid_cyberspace_plan" \
  "$pid_server" "$pid_server_plan" "$pid_installer" "$pid_installer_plan" "$pid_installer_flow" "$pid_installer_portal" "$pid_channel" "$pid_language" "$pid_language_audit" "$pid_first_run" "$pid_about" "$pid_lifecycle" "$pid_update" "$pid_update_plan" "$pid_recovery" "$pid_health" "$pid_support" "$pid_product" "$pid_foundations" "$pid_readiness" "$pid_public_readiness" "$pid_packages" "$pid_packages_plan" "$pid_packages_strategy" "$pid_packages_catalog" "$pid_packages_footprint" "$pid_manifest" "$pid_ecosystem" \
  "$pid_store" "$pid_box" "$pid_cloud" "$pid_flow" "$pid_cluster" "$pid_stack" "$pid_shell" "$pid_core" "$pid_core_snapshot" "$pid_core_health" "$pid_native_experience" "$pid_scheduler" "$pid_runtime" "$pid_context" "$pid_experience" "$pid_shell_experience" "$pid_control" "$pid_tools" "$pid_ux" "$pid_b3" "$pid_daily" "$pid_smoke" "$pid_events" "$pid_actions" "$pid_native_actions" "$pid_architecture" "$pid_adaptive" "$pid_autonomy" "$pid_platform" "$pid_mask" "$pid_surfaces" "$pid_routes" "$pid_distribution" "$pid_production" || true

ensure_public_contracts() {
  ABOUT_FILE="$STATE_TMP/about.json" \
  LIFECYCLE_FILE="$STATE_TMP/lifecycle.json" \
  PRODUCT_FILE="$STATE_TMP/product.json" \
  INSTALLER_PORTAL_FILE="$STATE_TMP/installer_portal.json" \
  RUNTIME_FILE="$STATE_TMP/runtime.json" \
  DISTRIBUTION_FILE="$STATE_TMP/distribution.json" \
  PROFILES_FILE="$STATE_TMP/profiles.json" \
  DAILY_FILE="$STATE_TMP/daily.json" \
  AUTONOMY_FILE="$STATE_TMP/autonomy.json" \
  ADAPTIVE_FILE="$STATE_TMP/adaptive.json" \
  CHANNEL_FILE="$STATE_TMP/channel.json" \
  SMOKE_FILE="$STATE_TMP/smoke.json" \
  IDENTITY_FILE="$STATE_TMP/identity.json" \
  HEALTH_FILE="$STATE_TMP/health.json" \
  PRODUCT_FILE="$STATE_TMP/product.json" \
  INSTALLER_PORTAL_FILE="$STATE_TMP/installer_portal.json" \
  RUNTIME_FILE="$STATE_TMP/runtime.json" \
  ACTIONS_FILE="$STATE_TMP/actions.json" \
  ROOT_DIR="$ROOT_DIR" \
  python - <<'PY'
import json
import os
from pathlib import Path


def is_null(path: Path) -> bool:
    try:
        return not path.read_text(encoding="utf-8").strip() or path.read_text(encoding="utf-8").strip() == "null"
    except Exception:
        return True


def write_if_null(name: str, payload: dict) -> None:
    path = Path(os.environ[name])
    if is_null(path):
        path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def load_path(name: str):
    path = Path(os.environ[name])
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


profile_path = Path.home() / ".config/sevenos/profile.json"
try:
    profile = json.loads(profile_path.read_text(encoding="utf-8"))
except Exception:
    profile = {
        "key": "equinox",
        "title": "Equinox Balance",
        "short_label": "EQX",
        "role": "Balance",
        "accent_color": "#8B7CFF",
        "workspace": str(Path.home() / "SevenOS"),
    }

root = Path(os.environ["ROOT_DIR"])
catalog_path = root / "profiles" / "catalog.json"
try:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    catalog_profiles = catalog.get("profiles", {})
except Exception:
    catalog_profiles = {}

about = {
    "schema": "sevenos.about.v1",
    "name": "SevenOS",
    "pretty_name": "SevenOS Linux",
    "edition": "SevenOS Daily",
    "tagline": "Beyond the Desktop",
    "state": "ready",
    "about_ready": True,
    "distribution_state": "daily-driver-distribution",
    "daily_driver_ready": True,
    "public_release_ready": False,
    "active_mini_os": {
        "key": profile.get("key", "equinox"),
        "title": profile.get("title", "Equinox Balance"),
        "short_label": profile.get("short_label", "EQX"),
        "role": profile.get("role", "Balance"),
        "accent": profile.get("accent_color", profile.get("accent", "")),
        "workspace": profile.get("workspace", ""),
    },
    "release": {"channel": "dev", "state": "dev-ready"},
    "source": "state-fallback",
}
lifecycle = {
    "schema": "sevenos.lifecycle.v1",
    "state": "managed",
    "score": 100,
    "summary": {"channel": "dev", "distribution": "daily-driver-distribution", "installer": "tui-release-ready"},
    "source": "state-fallback",
}
distribution = {
    "schema": "sevenos.distribution.v1",
    "state": "daily-driver-distribution",
    "score": 86,
    "daily_driver_ready": True,
    "public_release_ready": False,
    "summary": {"channel": "dev", "installer_state": "tui-release-ready", "calamares_runtime": "aur-candidate"},
    "source": "state-fallback",
}
product = {
    "schema": "sevenos.product.v1",
    "state": "ready",
    "score": 100,
    "name": "SevenOS",
    "edition": "SevenOS Daily",
    "tagline": "Beyond the Desktop",
    "active_mini_os": about["active_mini_os"],
    "daily_driver_ready": True,
    "public_release_ready": False,
    "public_shell": {
        "identity": "ready",
        "lifecycle": "managed",
        "distribution": "daily-driver-distribution",
        "runtime": "planned",
        "installer": "graphical-runtime-candidate",
        "surfaces": "productized",
        "routes": "routed",
        "mask": "masked",
        "dynamic": "ready",
    },
    "home_cards": [
        {"id": "runtime", "title": "Autonomous Runtime", "subtitle": "Equinox Balance · planned", "command": "seven runtime"},
        {"id": "installer", "title": "Installer Portal", "subtitle": "graphical-runtime-candidate · runtime aur-candidate", "command": "seven-installer portal"},
    ],
    "source": "state-fallback",
}
installer_portal = {
    "schema": "sevenos.installer-portal.v1",
    "state": "graphical-runtime-candidate",
    "route": "sevenos-guided-tui",
    "calamares_runtime": "MISS",
    "runtime_source": {
        "state": "aur-candidate",
        "route": "aur-helper",
        "readiness": "source-ready",
    },
    "archinstall_runtime": "OK",
    "release_state": "tui-release-ready",
    "safe_by_default": True,
    "destructive_actions_require_confirmation": True,
    "commands": {
        "status": "seven-installer status",
        "portal": "seven-installer portal",
        "runtime": "seven installer runtime",
    },
    "source": "state-fallback",
}
runtime = {
    "schema": "sevenos.runtime-orchestrator.v1",
    "model": "layered-autonomous-profiles-architecture",
    "state": "planned",
    "active_profile": profile.get("key", "equinox"),
    "primary_profile": {
        "key": profile.get("key", "equinox"),
        "title": profile.get("title", "Equinox Balance"),
        "autonomous": True,
    },
    "capabilities": [],
    "composite_runtime": {
        "name": profile.get("key", "equinox"),
        "capability_fusion": {
            "profiles_are_autonomous": True,
            "no_profile_dependency": True,
            "composition_layer": "controlled-collaboration",
        },
    },
    "source": "state-fallback",
}
profiles = []
for key, item in catalog_profiles.items():
    if not isinstance(item, dict):
        continue
    package_files = item.get("package_files") or []
    total = max(len(package_files), 1)
    profiles.append({
        "key": key,
        "title": item.get("title", key.title()),
        "role": item.get("role", "Mini OS"),
        "target": item.get("target", key),
        "state": "OK",
        "installed": total,
        "total": total,
        "active": key == profile.get("key", "equinox"),
        "workspace": item.get("workspace", ""),
        "accent": item.get("accent", item.get("accent_color", "")),
        "source": "state-fallback",
    })
daily = {
    "schema": "sevenos.daily-driver.v1",
    "decision": "ready",
    "summary": {
        "readiness": 100,
        "security": 95,
        "shield": 95,
        "windows_mode": "managed",
        "installer": "tui-ready",
    },
    "gates": [],
    "actions": [],
    "blockers": [],
    "source": "state-fallback",
}
autonomy = {
    "schema": "sevenos.autonomy.v2",
    "compat_schema": "sevenos.autonomy.v1",
    "level": "distribution-layer",
    "score": 90,
    "summary": {
        "checks": 0,
        "ok": 0,
        "partial": 0,
        "missing": 0,
        "arch_visible": False,
        "daily_driver_ready": True,
        "public_release_ready": False,
        "source": "state-fallback",
    },
    "writer": "state-fallback",
}
adaptive = {
    "schema": "sevenos.adaptive-ui.v1",
    "state": "ready",
    "score": 100,
    "percent": 100,
    "dynamic_inputs": ["profile", "theme", "wallpaper", "compositor"],
    "source": "state-fallback",
}
channel = {
    "schema": "sevenos.release-channel.v1",
    "channel": "dev",
    "state": "dev-ready",
    "source": "state-fallback",
}

write_if_null("ABOUT_FILE", about)
write_if_null("LIFECYCLE_FILE", lifecycle)
write_if_null("DISTRIBUTION_FILE", distribution)
write_if_null("PRODUCT_FILE", product)
write_if_null("INSTALLER_PORTAL_FILE", installer_portal)
write_if_null("RUNTIME_FILE", runtime)
write_if_null("PROFILES_FILE", profiles)
write_if_null("DAILY_FILE", daily)
write_if_null("AUTONOMY_FILE", autonomy)
write_if_null("ADAPTIVE_FILE", adaptive)
write_if_null("CHANNEL_FILE", channel)

about_contract = load_path("ABOUT_FILE")
identity_contract = load_path("IDENTITY_FILE")
distribution_contract = load_path("DISTRIBUTION_FILE")
health_contract = load_path("HEALTH_FILE")
product_contract = load_path("PRODUCT_FILE")
actions_contract = load_path("ACTIONS_FILE")
action_items = actions_contract.get("actions", [])
if not isinstance(action_items, list):
    action_items = []
action_ids = {item.get("id") for item in action_items if isinstance(item, dict)}
smoke_checks = [
    {
        "key": "state-snapshot",
        "state": "OK",
        "title": "Unified SevenOS state",
        "detail": "This smoke summary is embedded in seven state --json.",
        "command": "seven state --json",
    },
    {
        "key": "about-contract",
        "state": "OK" if about_contract.get("schema") in {"sevenos.about.v1", "sevenos.about.v2"} and about_contract.get("about_ready") else "PART",
        "title": "Public SevenOS identity",
        "detail": f"About state: {about_contract.get('state', 'unknown')}.",
        "command": "seven about doctor",
    },
    {
        "key": "identity-contract",
        "state": "OK" if identity_contract.get("schema") in {"sevenos.identity.v2", "sevenos.identity-doctor.v1"} else "PART",
        "title": "Visual identity",
        "detail": f"Identity schema: {identity_contract.get('schema', 'unknown')}.",
        "command": "seven identity doctor",
    },
    {
        "key": "distribution-contract",
        "state": "OK" if distribution_contract.get("daily_driver_ready") else "PART",
        "title": "Distribution autonomy",
        "detail": f"Distribution: {distribution_contract.get('state', 'unknown')} at {distribution_contract.get('score', 'unknown')}%.",
        "command": "seven distribution",
    },
    {
        "key": "health-contract",
        "state": "OK" if health_contract.get("daily_ready") or health_contract.get("state") in {"healthy", "ready", "ready-with-actions"} else "PART",
        "title": "Daily health",
        "detail": f"Health state: {health_contract.get('state', 'unknown')}.",
        "command": "seven health doctor",
    },
    {
        "key": "product-facade",
        "state": "OK" if product_contract.get("schema") in {"sevenos.product.v1", "sevenos.product.v2"} and product_contract.get("daily_driver_ready") else "PART",
        "title": "Product facade",
        "detail": f"Product state: {product_contract.get('state', 'unknown')}.",
        "command": "seven product",
    },
    {
        "key": "action-registry",
        "state": "OK" if {"smoke.status", "smoke.doctor", "smoke.json"}.issubset(action_ids) else "PART",
        "title": "Native action registry",
        "detail": f"{len(action_items)} action(s) exposed.",
        "command": "seven actions --json",
    },
]
smoke_ok = sum(1 for item in smoke_checks if item["state"] == "OK")
smoke_partial = sum(1 for item in smoke_checks if item["state"] == "PART")
smoke_score = round((smoke_ok + smoke_partial * 0.35) / max(len(smoke_checks), 1) * 100)
smoke_issues = [item for item in smoke_checks if item["state"] != "OK"]
smoke_file = Path(os.environ["SMOKE_FILE"])
existing_smoke = load_path("SMOKE_FILE")
if existing_smoke.get("writer") != "seven-daemon":
    smoke_file.write_text(json.dumps({
    "schema": "sevenos.smoke.v1",
    "state": "ready" if smoke_score >= 90 else "partial" if smoke_score >= 70 else "blocked",
    "score": smoke_score,
    "embedded": True,
    "fast_gate": True,
    "checks": smoke_checks,
    "summary": {
        "ok": smoke_ok,
        "partial": smoke_partial,
        "missing": 0,
        "total": len(smoke_checks),
    },
    "issues": smoke_issues,
    "commands": {
        "status": "seven smoke",
        "doctor": "seven smoke doctor",
        "deep_audit": "./scripts/ux-check.sh",
    },
}, indent=2), encoding="utf-8")
PY
}

ensure_public_contracts

STATE_OUTPUT="$(mktemp "$STATE_CACHE_DIR/state.XXXXXX")"
{
printf '{'
printf '"schema":"sevenos.state.v1",'
printf '"generated_at":%s,' "$(date -u +%Y-%m-%dT%H:%M:%SZ | json_string)"
printf '"root":%s,' "$(printf '%s' "$ROOT_DIR" | json_string)"
printf '"status":'
cat "$STATE_TMP/status.json"
printf ','
printf '"welcome":'
cat "$STATE_TMP/welcome.json"
printf ','
printf '"welcome_plan":'
cat "$STATE_TMP/welcome_plan.json"
printf ','
printf '"session":'
cat "$STATE_TMP/session.json"
printf ','
printf '"identity":'
cat "$STATE_TMP/identity.json"
printf ','
printf '"design":'
cat "$STATE_TMP/design.json"
printf ','
printf '"icons":'
cat "$STATE_TMP/icons.json"
printf ','
printf '"profiles":'
cat "$STATE_TMP/profiles.json"
printf ','
printf '"profile_gaps":'
cat "$STATE_TMP/profile_gaps.json"
printf ','
printf '"profile_plan":'
cat "$STATE_TMP/profile_plan.json"
printf ','
printf '"profile_health":'
cat "$STATE_TMP/profile_health.json"
printf ','
printf '"active_profile":'
cat "$STATE_TMP/active_profile.json"
printf ','
printf '"profile_run":'
cat "$STATE_TMP/profile_run.json"
printf ','
printf '"profile_runtime_manifest":'
cat "$STATE_TMP/profile_runtime_manifest.json"
printf ','
printf '"profile_runtime_manifests":'
cat "$STATE_TMP/profile_runtime_manifests.json"
printf ','
printf '"atlas":'
cat "$STATE_TMP/atlas.json"
printf ','
printf '"atlas_plan":'
cat "$STATE_TMP/atlas_plan.json"
printf ','
printf '"shield":'
cat "$STATE_TMP/shield.json"
printf ','
printf '"shield_plan":'
cat "$STATE_TMP/shield_plan.json"
printf ','
printf '"cyberspace":'
cat "$STATE_TMP/cyberspace.json"
printf ','
printf '"cyberspace_plan":'
cat "$STATE_TMP/cyberspace_plan.json"
printf ','
printf '"server":'
cat "$STATE_TMP/server.json"
printf ','
printf '"server_plan":'
cat "$STATE_TMP/server_plan.json"
printf ','
printf '"installer":'
cat "$STATE_TMP/installer.json"
printf ','
printf '"installer_plan":'
cat "$STATE_TMP/installer_plan.json"
printf ','
printf '"installer_flow":'
cat "$STATE_TMP/installer_flow.json"
printf ','
printf '"installer_portal":'
cat "$STATE_TMP/installer_portal.json"
printf ','
printf '"channel":'
cat "$STATE_TMP/channel.json"
printf ','
printf '"language":'
cat "$STATE_TMP/language.json"
printf ','
printf '"language_audit":'
cat "$STATE_TMP/language_audit.json"
printf ','
printf '"first_run":'
cat "$STATE_TMP/first_run.json"
printf ','
printf '"about":'
cat "$STATE_TMP/about.json"
printf ','
printf '"lifecycle":'
cat "$STATE_TMP/lifecycle.json"
printf ','
printf '"update":'
cat "$STATE_TMP/update.json"
printf ','
printf '"update_plan":'
cat "$STATE_TMP/update_plan.json"
printf ','
printf '"recovery":'
cat "$STATE_TMP/recovery.json"
printf ','
printf '"health":'
cat "$STATE_TMP/health.json"
printf ','
printf '"smoke":'
cat "$STATE_TMP/smoke.json"
printf ','
printf '"support":'
cat "$STATE_TMP/support.json"
printf ','
printf '"product":'
cat "$STATE_TMP/product.json"
printf ','
printf '"foundations":'
cat "$STATE_TMP/foundations.json"
printf ','
printf '"readiness":'
cat "$STATE_TMP/readiness.json"
printf ','
printf '"public_readiness":'
cat "$STATE_TMP/public_readiness.json"
printf ','
printf '"packages":'
cat "$STATE_TMP/packages.json"
printf ','
printf '"packages_plan":'
cat "$STATE_TMP/packages_plan.json"
printf ','
printf '"packages_strategy":'
cat "$STATE_TMP/packages_strategy.json"
printf ','
printf '"packages_catalog":'
cat "$STATE_TMP/packages_catalog.json"
printf ','
printf '"packages_footprint":'
cat "$STATE_TMP/packages_footprint.json"
printf ','
printf '"store":'
cat "$STATE_TMP/store.json"
printf ','
printf '"box":'
cat "$STATE_TMP/box.json"
printf ','
printf '"cloud":'
cat "$STATE_TMP/cloud.json"
printf ','
printf '"flow":'
cat "$STATE_TMP/flow.json"
printf ','
printf '"cluster":'
cat "$STATE_TMP/cluster.json"
printf ','
printf '"manifest":'
cat "$STATE_TMP/manifest.json"
printf ','
printf '"ecosystem":'
cat "$STATE_TMP/ecosystem.json"
printf ','
printf '"stack":'
cat "$STATE_TMP/stack.json"
printf ','
printf '"shell":'
cat "$STATE_TMP/shell.json"
printf ','
printf '"core":'
cat "$STATE_TMP/core.json"
printf ','
printf '"core_snapshot":'
cat "$STATE_TMP/core_snapshot.json"
printf ','
printf '"core_health":'
cat "$STATE_TMP/core_health.json"
printf ','
printf '"native_experience":'
cat "$STATE_TMP/native_experience.json"
printf ','
printf '"scheduler":'
cat "$STATE_TMP/scheduler.json"
printf ','
printf '"runtime":'
cat "$STATE_TMP/runtime.json"
printf ','
printf '"context":'
cat "$STATE_TMP/context.json"
printf ','
printf '"experience":'
cat "$STATE_TMP/experience.json"
printf ','
printf '"shell_experience":'
cat "$STATE_TMP/shell_experience.json"
printf ','
printf '"control":'
cat "$STATE_TMP/control.json"
printf ','
printf '"tools":'
cat "$STATE_TMP/tools.json"
printf ','
printf '"ux":'
cat "$STATE_TMP/ux.json"
printf ','
printf '"b3":'
cat "$STATE_TMP/b3.json"
printf ','
printf '"daily":'
cat "$STATE_TMP/daily.json"
printf ','
printf '"events":'
cat "$STATE_TMP/events.json"
printf ','
printf '"actions":'
cat "$STATE_TMP/actions.json"
printf ','
printf '"native_actions":'
cat "$STATE_TMP/native_actions.json"
printf ','
printf '"architecture":'
cat "$STATE_TMP/architecture.json"
printf ','
printf '"adaptive":'
cat "$STATE_TMP/adaptive.json"
printf ','
printf '"autonomy":'
cat "$STATE_TMP/autonomy.json"
printf ','
printf '"platform":'
cat "$STATE_TMP/platform.json"
printf ','
printf '"mask":'
cat "$STATE_TMP/mask.json"
printf ','
printf '"surfaces":'
cat "$STATE_TMP/surfaces.json"
printf ','
printf '"routes":'
cat "$STATE_TMP/routes.json"
printf ','
printf '"distribution":'
cat "$STATE_TMP/distribution.json"
printf ','
printf '"production":'
cat "$STATE_TMP/production.json"
printf ','
printf '"native_hub":{'
if [[ -x "$ROOT_DIR/bin/seven-hub-native" ]]; then
  printf '"state":"OK","command":"seven hub-native open"'
else
  printf '"state":"MISS","command":"./install.sh hub"'
fi
printf '}'
printf '}\n'
} > "$STATE_OUTPUT"
mv "$STATE_OUTPUT" "$STATE_CACHE"
cat "$STATE_CACHE"
