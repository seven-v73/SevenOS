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
for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown state option: $arg"; usage; exit 1 ;;
  esac
done

if [[ "$JSON_OUTPUT" -ne 1 ]]; then
  usage
  exit 0
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
trap 'rm -rf "$STATE_TMP"' EXIT

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
json_to_file "$STATE_TMP/windows.json" "$ROOT_DIR/bin/seven-windows-assistant" status --json &
pid_windows=$!
json_to_file "$STATE_TMP/windows_plan.json" "$ROOT_DIR/bin/seven-windows-assistant" plan --json &
pid_windows_plan=$!
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
json_to_file "$STATE_TMP/channel.json" "$ROOT_DIR/scripts/channel.sh" json &
pid_channel=$!
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

wait "$pid_status" "$pid_welcome" "$pid_welcome_plan" "$pid_session" "$pid_identity" "$pid_design" "$pid_icons" "$pid_profiles" "$pid_profile_gaps" "$pid_profile_plan" "$pid_profile_health" "$pid_active_profile" "$pid_profile_run" "$pid_profile_runtime_manifest" "$pid_profile_runtime_manifests" "$pid_windows" "$pid_windows_plan" "$pid_shield" "$pid_shield_plan" "$pid_cyberspace" "$pid_cyberspace_plan" \
  "$pid_server" "$pid_server_plan" "$pid_installer" "$pid_installer_plan" "$pid_channel" "$pid_about" "$pid_lifecycle" "$pid_update" "$pid_recovery" "$pid_health" "$pid_product" "$pid_foundations" "$pid_readiness" "$pid_packages" "$pid_packages_plan" "$pid_manifest" "$pid_ecosystem" \
  "$pid_store" "$pid_box" "$pid_cloud" "$pid_flow" "$pid_cluster" "$pid_stack" "$pid_shell" "$pid_core" "$pid_core_snapshot" "$pid_core_health" "$pid_scheduler" "$pid_runtime" "$pid_context" "$pid_experience" "$pid_control" "$pid_b3" "$pid_daily" "$pid_events" "$pid_actions" "$pid_architecture" "$pid_adaptive" "$pid_autonomy" "$pid_platform" "$pid_mask" "$pid_surfaces" "$pid_routes" "$pid_distribution" || true

ensure_public_contracts() {
  ABOUT_FILE="$STATE_TMP/about.json" \
  LIFECYCLE_FILE="$STATE_TMP/lifecycle.json" \
  PRODUCT_FILE="$STATE_TMP/product.json" \
  DISTRIBUTION_FILE="$STATE_TMP/distribution.json" \
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
        "surfaces": "productized",
        "routes": "routed",
        "mask": "masked",
        "dynamic": "ready",
    },
    "source": "state-fallback",
}

write_if_null("ABOUT_FILE", about)
write_if_null("LIFECYCLE_FILE", lifecycle)
write_if_null("DISTRIBUTION_FILE", distribution)
write_if_null("PRODUCT_FILE", product)
PY
}

ensure_public_contracts

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
printf '"windows":'
cat "$STATE_TMP/windows.json"
printf ','
printf '"windows_plan":'
cat "$STATE_TMP/windows_plan.json"
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
printf '"channel":'
cat "$STATE_TMP/channel.json"
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
printf '"native_hub":{'
if [[ -x "$ROOT_DIR/bin/seven-hub-native" ]]; then
  printf '"state":"OK","command":"seven hub-native open"'
else
  printf '"state":"MISS","command":"./install.sh hub"'
fi
printf '}'
printf '}\n'
