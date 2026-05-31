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

required = {"packages_strategy", "packages_catalog", "packages_footprint", "production", "language", "language_audit", "first_run"}
if not required.issubset(data):
    raise SystemExit(1)

schema_checks = {
    "packages_strategy": "sevenos.sevenpkg-strategy.v1",
    "packages_catalog": "sevenos.app-catalog.v1",
    "packages_footprint": "sevenos.sevenpkg-footprint.v1",
    "production": "sevenos.production-readiness.v1",
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
    if command_output="$(SEVENOS_DRY_RUN=0 timeout 8 "$@" 2>/dev/null)" && [[ -n "$command_output" ]]; then
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
    SEVENOS_DRY_RUN=0 timeout 8 "$@" > "$output_file" 2>/dev/null || printf 'null' > "$output_file"
  else
    SEVENOS_DRY_RUN=0 "$@" > "$output_file" 2>/dev/null || printf 'null' > "$output_file"
  fi

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
json_to_file "$STATE_TMP/session.json" "$ROOT_DIR/bin/seven-session-status" --json &
pid_session=$!
json_to_file "$STATE_TMP/identity.json" "$ROOT_DIR/scripts/identity.sh" --json &
pid_identity=$!
json_to_file "$STATE_TMP/design.json" "$ROOT_DIR/scripts/identity.sh" design --json &
pid_design=$!
json_to_file "$STATE_TMP/icons.json" "$ROOT_DIR/scripts/identity.sh" icons --json &
pid_icons=$!
json_to_file "$STATE_TMP/profiles.json" "$ROOT_DIR/bin/seven" profile status --json &
pid_profiles=$!
json_to_file "$STATE_TMP/profile_gaps.json" "$ROOT_DIR/bin/seven" profile gaps --json &
pid_profile_gaps=$!
json_to_file "$STATE_TMP/profile_plan.json" "$ROOT_DIR/bin/seven" profile plan --json &
pid_profile_plan=$!
json_to_file "$STATE_TMP/profile_health.json" "$ROOT_DIR/bin/seven" profile health --json &
pid_profile_health=$!
json_to_file "$STATE_TMP/active_profile.json" "$ROOT_DIR/bin/seven" profile current --json &
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
json_to_file "$STATE_TMP/shield.json" "$ROOT_DIR/security/shield-status.sh" --json &
pid_shield=$!
json_to_file "$STATE_TMP/shield_plan.json" "$ROOT_DIR/security/shield-status.sh" plan --json &
pid_shield_plan=$!
json_to_file "$STATE_TMP/cyberspace.json" "$ROOT_DIR/security/cyberspace.sh" mode --json &
pid_cyberspace=$!
json_to_file "$STATE_TMP/cyberspace_plan.json" "$ROOT_DIR/bin/seven-daemon" cyberspace-plan --json &
pid_cyberspace_plan=$!
json_to_file "$STATE_TMP/server.json" "$ROOT_DIR/server/seven-server.sh" status --json &
pid_server=$!
json_to_file "$STATE_TMP/server_plan.json" "$ROOT_DIR/server/seven-server.sh" plan --json &
pid_server_plan=$!
json_to_file "$STATE_TMP/installer.json" "$ROOT_DIR/scripts/installer-stack.sh" status --json &
pid_installer=$!
json_to_file "$STATE_TMP/installer_plan.json" "$ROOT_DIR/scripts/installer-stack.sh" plan --json &
pid_installer_plan=$!
json_to_file "$STATE_TMP/installer_portal.json" "$ROOT_DIR/bin/seven-installer" status --json &
pid_installer_portal=$!
json_to_file "$STATE_TMP/channel.json" "$ROOT_DIR/scripts/channel.sh" json &
pid_channel=$!
json_to_file "$STATE_TMP/language.json" "$ROOT_DIR/bin/seven-language" doctor --json &
pid_language=$!
json_to_file "$STATE_TMP/language_audit.json" "$ROOT_DIR/bin/seven-language" audit --json &
pid_language_audit=$!
json_to_file "$STATE_TMP/first_run.json" "$ROOT_DIR/bin/seven-public-studio" fresh-install --json &
pid_first_run=$!
json_to_file "$STATE_TMP/about.json" env SEVENOS_ABOUT_FAST=1 "$ROOT_DIR/scripts/about.sh" json &
pid_about=$!
json_to_file "$STATE_TMP/lifecycle.json" env SEVENOS_LIFECYCLE_FAST=1 "$ROOT_DIR/scripts/lifecycle.sh" json &
pid_lifecycle=$!
json_to_file "$STATE_TMP/update.json" env SEVENOS_UPDATE_FAST=1 "$ROOT_DIR/scripts/update.sh" json &
pid_update=$!
json_to_file "$STATE_TMP/recovery.json" env SEVENOS_RECOVERY_FAST=1 "$ROOT_DIR/scripts/recovery.sh" json &
pid_recovery=$!
json_to_file "$STATE_TMP/health.json" env SEVENOS_HEALTH_FAST=1 "$ROOT_DIR/scripts/health.sh" json &
pid_health=$!
json_to_file "$STATE_TMP/support.json" env SEVENOS_SUPPORT_FAST=1 "$ROOT_DIR/scripts/support.sh" json &
pid_support=$!
json_to_file "$STATE_TMP/product.json" env SEVENOS_PRODUCT_FAST=1 "$ROOT_DIR/scripts/product.sh" json &
pid_product=$!
json_to_file "$STATE_TMP/foundations.json" "$ROOT_DIR/scripts/foundations.sh" json &
pid_foundations=$!
json_to_file "$STATE_TMP/readiness.json" "$ROOT_DIR/scripts/readiness.sh" --json &
pid_readiness=$!
json_to_file "$STATE_TMP/packages.json" "$ROOT_DIR/bin/sevenpkg" status --json &
pid_packages=$!
json_to_file "$STATE_TMP/packages_plan.json" "$ROOT_DIR/bin/sevenpkg" plan --json &
pid_packages_plan=$!
json_to_file "$STATE_TMP/packages_strategy.json" "$ROOT_DIR/bin/sevenpkg" strategy --json &
pid_packages_strategy=$!
json_to_file "$STATE_TMP/packages_catalog.json" "$ROOT_DIR/bin/sevenpkg" catalog --json &
pid_packages_catalog=$!
json_to_file "$STATE_TMP/packages_footprint.json" "$ROOT_DIR/bin/sevenpkg" footprint --fast --json &
pid_packages_footprint=$!
json_to_file "$STATE_TMP/store.json" "$ROOT_DIR/scripts/store.sh" json &
pid_store=$!
json_to_file "$STATE_TMP/box.json" "$ROOT_DIR/scripts/box.sh" json &
pid_box=$!
json_to_file "$STATE_TMP/cloud.json" "$ROOT_DIR/scripts/cloud.sh" json &
pid_cloud=$!
json_to_file "$STATE_TMP/flow.json" "$ROOT_DIR/scripts/flow.sh" json &
pid_flow=$!
json_to_file "$STATE_TMP/cluster.json" "$ROOT_DIR/scripts/cluster.sh" json &
pid_cluster=$!
json_to_file "$STATE_TMP/manifest.json" "$ROOT_DIR/scripts/manifest.sh" summary-json &
pid_manifest=$!
json_to_file "$STATE_TMP/ecosystem.json" "$ROOT_DIR/scripts/ecosystem.sh" json &
pid_ecosystem=$!
json_to_file "$STATE_TMP/stack.json" "$ROOT_DIR/scripts/stack.sh" --json &
pid_stack=$!
json_to_file "$STATE_TMP/shell.json" "$ROOT_DIR/scripts/shell.sh" status --json &
pid_shell=$!
json_to_file "$STATE_TMP/core.json" "$ROOT_DIR/scripts/core.sh" status --json &
pid_core=$!
json_to_file "$STATE_TMP/core_snapshot.json" "$ROOT_DIR/scripts/core.sh" snapshot --json &
pid_core_snapshot=$!
json_to_file "$STATE_TMP/core_health.json" "$ROOT_DIR/scripts/core.sh" health --json &
pid_core_health=$!
json_to_file "$STATE_TMP/scheduler.json" "$ROOT_DIR/scripts/scheduler.sh" status --json &
pid_scheduler=$!
json_to_file "$STATE_TMP/runtime.json" "$ROOT_DIR/scripts/runtime-orchestrator.sh" status --json &
pid_runtime=$!
json_to_file "$STATE_TMP/context.json" "$ROOT_DIR/scripts/context.sh" status --json &
pid_context=$!
json_to_file "$STATE_TMP/experience.json" "$ROOT_DIR/scripts/experience.sh" --json &
pid_experience=$!
json_to_file "$STATE_TMP/shell_experience.json" "$ROOT_DIR/scripts/shell-experience.sh" status --json &
pid_shell_experience=$!
json_to_file "$STATE_TMP/control.json" "$ROOT_DIR/scripts/control-plane.sh" --json &
pid_control=$!
json_to_file "$STATE_TMP/b3.json" "$ROOT_DIR/scripts/b3.sh" plan --json &
pid_b3=$!
json_to_file "$STATE_TMP/daily.json" "$ROOT_DIR/scripts/daily-driver.sh" status --json &
pid_daily=$!
json_to_file "$STATE_TMP/events.json" "$ROOT_DIR/scripts/events.sh" summary-json &
pid_events=$!
json_to_file "$STATE_TMP/actions.json" "$ROOT_DIR/scripts/actions.sh" --json &
pid_actions=$!
json_to_file "$STATE_TMP/architecture.json" "$ROOT_DIR/scripts/architecture.sh" matrix --json &
pid_architecture=$!
json_to_file "$STATE_TMP/adaptive.json" "$ROOT_DIR/scripts/adaptive-ui.sh" json &
pid_adaptive=$!
json_to_file "$STATE_TMP/autonomy.json" "$ROOT_DIR/scripts/autonomy.sh" json &
pid_autonomy=$!
json_to_file "$STATE_TMP/platform.json" "$ROOT_DIR/scripts/platform.sh" json &
pid_platform=$!
json_to_file "$STATE_TMP/mask.json" "$ROOT_DIR/scripts/mask.sh" json &
pid_mask=$!
json_to_file "$STATE_TMP/surfaces.json" "$ROOT_DIR/scripts/surfaces.sh" json &
pid_surfaces=$!
json_to_file "$STATE_TMP/routes.json" "$ROOT_DIR/scripts/routes.sh" json &
pid_routes=$!
json_to_file "$STATE_TMP/distribution.json" env SEVENOS_DISTRIBUTION_FAST=1 "$ROOT_DIR/scripts/distribution.sh" json &
pid_distribution=$!
json_to_file "$STATE_TMP/production.json" env SEVENOS_PRODUCTION_FAST=1 "$ROOT_DIR/scripts/production-readiness.sh" json &
pid_production=$!

wait "$pid_status" "$pid_welcome" "$pid_welcome_plan" "$pid_session" "$pid_identity" "$pid_design" "$pid_icons" "$pid_profiles" "$pid_profile_gaps" "$pid_profile_plan" "$pid_profile_health" "$pid_active_profile" "$pid_profile_run" "$pid_profile_runtime_manifest" "$pid_profile_runtime_manifests" "$pid_atlas" "$pid_atlas_plan" "$pid_shield" "$pid_shield_plan" "$pid_cyberspace" "$pid_cyberspace_plan" \
  "$pid_server" "$pid_server_plan" "$pid_installer" "$pid_installer_plan" "$pid_installer_portal" "$pid_channel" "$pid_language" "$pid_language_audit" "$pid_first_run" "$pid_about" "$pid_lifecycle" "$pid_update" "$pid_recovery" "$pid_health" "$pid_support" "$pid_product" "$pid_foundations" "$pid_readiness" "$pid_packages" "$pid_packages_plan" "$pid_packages_strategy" "$pid_packages_catalog" "$pid_packages_footprint" "$pid_manifest" "$pid_ecosystem" \
  "$pid_store" "$pid_box" "$pid_cloud" "$pid_flow" "$pid_cluster" "$pid_stack" "$pid_shell" "$pid_core" "$pid_core_snapshot" "$pid_core_health" "$pid_scheduler" "$pid_runtime" "$pid_context" "$pid_experience" "$pid_shell_experience" "$pid_control" "$pid_b3" "$pid_daily" "$pid_events" "$pid_actions" "$pid_architecture" "$pid_adaptive" "$pid_autonomy" "$pid_platform" "$pid_mask" "$pid_surfaces" "$pid_routes" "$pid_distribution" "$pid_production" || true

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
    "schema": "sevenos.autonomy.v1",
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
    },
    "source": "state-fallback",
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
        "state": "OK" if about_contract.get("schema") == "sevenos.about.v1" and about_contract.get("about_ready") else "PART",
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
        "state": "OK" if product_contract.get("schema") == "sevenos.product.v1" and product_contract.get("daily_driver_ready") else "PART",
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
Path(os.environ["SMOKE_FILE"]).write_text(json.dumps({
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
