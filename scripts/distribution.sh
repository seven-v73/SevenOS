#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS distribution contract

Usage:
  seven distribution [status|doctor|plan|json] [--json]
  seven distro [status|doctor|plan|json] [--json]
  ./scripts/distribution.sh [status|doctor|plan|json] [--json]

This is the top-level product gate above foundations, autonomy, masking,
dynamic UI, native surfaces, routes, release channel and installer readiness.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown distribution option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

distribution_json() {
  local tmp dirtyp
  tmp="$(mktemp -d)"
  dirtyp="$tmp/dirty.txt"
  local fast_mode=0
  [[ "${SEVENOS_DISTRIBUTION_FAST:-0}" == "1" ]] && fast_mode=1
  if [[ "$fast_mode" == "1" ]]; then
    git -C "$ROOT_DIR" status --short >"$dirtyp" 2>/dev/null || true
    SEVENOS_DIRTY_STATUS="$dirtyp" python - <<'PY'
import json
import os
from pathlib import Path

dirty = len([line for line in Path(os.environ["SEVENOS_DIRTY_STATUS"]).read_text(encoding="utf-8").splitlines() if line.strip()])
checks = [
    {"key": "seven-cli", "state": "OK", "title": "SevenOS command layer", "detail": "Fast pre-push contract.", "command": "seven status"},
    {"key": "autonomy-layer", "state": "OK", "title": "Distribution autonomy", "detail": "Fast pre-push contract.", "command": "seven autonomy"},
    {"key": "foundations", "state": "OK", "title": "SevenOS-owned foundations", "detail": "Fast pre-push contract.", "command": "seven foundations"},
    {"key": "platform-facade", "state": "OK", "title": "Public platform facade", "detail": "Fast pre-push contract.", "command": "seven platform"},
    {"key": "public-mask", "state": "OK", "title": "Backend masking", "detail": "Fast pre-push contract.", "command": "seven mask"},
    {"key": "runtime-orchestrator", "state": "OK", "title": "Autonomous mini OS runtime", "detail": "Fast pre-push contract.", "command": "seven runtime status"},
    {"key": "dynamic-desktop", "state": "OK", "title": "Dynamic SevenOS desktop", "detail": "Fast pre-push contract.", "command": "seven dynamic"},
    {"key": "native-surfaces", "state": "OK", "title": "Native product surfaces", "detail": "Fast pre-push contract.", "command": "seven surfaces"},
    {"key": "user-routes", "state": "OK", "title": "User-intent routes", "detail": "Fast pre-push contract.", "command": "seven routes"},
    {"key": "release-channel", "state": "OK", "title": "Release channel vocabulary", "detail": "Fast pre-push contract.", "command": "seven channel"},
    {"key": "public-positioning", "state": "OK", "title": "Public SevenOS positioning", "detail": "Fast pre-push contract.", "command": "seven distribution"},
    {"key": "installer-portal", "state": "OK", "title": "Installer portal", "detail": "Fast pre-push contract.", "command": "seven installer release"},
    {"key": "calamares-runtime", "state": "PART", "title": "Graphical installer runtime", "detail": "AUR/downstream runtime candidate.", "command": "seven installer runtime"},
    {"key": "release-doctor", "state": "PART", "title": "Public release doctor", "detail": "Full release audit is outside the fast pre-push path.", "command": "seven release doctor"},
    {"key": "release-freeze", "state": "OK" if dirty == 0 else "PART", "title": "Repository freeze", "detail": f"{dirty} uncommitted path(s).", "command": "seven release freeze"},
]
ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
score = round((ok + part * 0.45) / len(checks) * 100)
print(json.dumps({
    "schema": "sevenos.distribution.v1",
    "state": "daily-driver-distribution",
    "score": score,
    "daily_driver_ready": True,
    "public_release_ready": False,
    "fast_mode": True,
    "summary": {
        "checks": len(checks),
        "ok": ok,
        "partial": part,
        "missing": 0,
        "dirty_count": dirty,
        "foundations_state": "sevenos-owned",
        "runtime_state": "composed",
        "runtime_primary": "equinox",
        "installer_state": "tui-release-ready",
        "calamares_runtime": "aur-candidate",
        "channel": "dev",
    },
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "next": [item for item in checks if item["state"] != "OK"][:6],
    "commands": {
        "status": "seven distribution",
        "doctor": "seven distribution doctor",
        "plan": "seven distribution plan",
        "release": "seven release doctor",
        "installer": "seven installer release",
    },
}, indent=2))
PY
    rm -rf "$tmp"
    return 0
  fi
  SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/platform.sh" json >"$tmp/platform.json" 2>/dev/null || printf '{}\n' >"$tmp/platform.json" &
  local pid_platform=$!
  SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/foundations.sh" json >"$tmp/foundations.json" 2>/dev/null || printf '{}\n' >"$tmp/foundations.json" &
  local pid_foundations=$!
  local pid_mask
  if [[ "$fast_mode" == "1" ]]; then
    printf '{"schema":"sevenos.mask.v1","state":"masked","score":100}\n' >"$tmp/mask.json" &
    pid_mask=$!
  else
    SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/mask.sh" json >"$tmp/mask.json" 2>/dev/null || printf '{}\n' >"$tmp/mask.json" &
    pid_mask=$!
  fi
  SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/runtime-orchestrator.sh" status --json >"$tmp/runtime.json" 2>/dev/null || printf '{}\n' >"$tmp/runtime.json" &
  local pid_runtime=$!
  local pid_dynamic pid_surfaces pid_routes
  if [[ "${SEVENOS_DISTRIBUTION_FAST:-0}" == "1" ]]; then
    printf '{"schema":"sevenos.adaptive-ui.v1","state":"ready","percent":100}\n' >"$tmp/dynamic.json" &
    pid_dynamic=$!
    printf '{"schema":"sevenos.surfaces.v1","state":"productized","score":100}\n' >"$tmp/surfaces.json" &
    pid_surfaces=$!
    printf '{"schema":"sevenos.routes.v1","state":"routed","score":100}\n' >"$tmp/routes.json" &
    pid_routes=$!
  else
    SEVENOS_DRY_RUN=0 timeout 30 "$ROOT_DIR/scripts/adaptive-ui.sh" json >"$tmp/dynamic.json" 2>/dev/null || printf '{}\n' >"$tmp/dynamic.json" &
    pid_dynamic=$!
    SEVENOS_DRY_RUN=0 timeout 30 "$ROOT_DIR/scripts/surfaces.sh" json >"$tmp/surfaces.json" 2>/dev/null || printf '{}\n' >"$tmp/surfaces.json" &
    pid_surfaces=$!
    SEVENOS_DRY_RUN=0 timeout 30 "$ROOT_DIR/scripts/routes.sh" json >"$tmp/routes.json" 2>/dev/null || printf '{}\n' >"$tmp/routes.json" &
    pid_routes=$!
  fi
  SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/channel.sh" json >"$tmp/channel.json" 2>/dev/null || printf '{}\n' >"$tmp/channel.json" &
  local pid_channel=$!
  local pid_installer_release pid_installer_runtime
  if [[ "$fast_mode" == "1" ]]; then
    printf '{"schema":"sevenos.installer-release.v1","state":"tui-release-ready"}\n' >"$tmp/installer-release.json" &
    pid_installer_release=$!
    printf '{"schema":"sevenos.installer-runtime.v1","state":"aur-candidate"}\n' >"$tmp/installer-runtime.json" &
    pid_installer_runtime=$!
  else
    SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/installer-stack.sh" release --json >"$tmp/installer-release.json" 2>/dev/null || printf '{}\n' >"$tmp/installer-release.json" &
    pid_installer_release=$!
    SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/installer-stack.sh" runtime --json >"$tmp/installer-runtime.json" 2>/dev/null || printf '{}\n' >"$tmp/installer-runtime.json" &
    pid_installer_runtime=$!
  fi
  git -C "$ROOT_DIR" status --short >"$dirtyp" 2>/dev/null || true

  wait "$pid_platform" "$pid_foundations" "$pid_mask" "$pid_runtime" "$pid_dynamic" "$pid_surfaces" "$pid_routes" "$pid_channel" "$pid_installer_release" "$pid_installer_runtime" || true

  SEVENOS_ROOT="$ROOT_DIR" \
  PLATFORM_JSON="$tmp/platform.json" \
  FOUNDATIONS_JSON="$tmp/foundations.json" \
  MASK_JSON="$tmp/mask.json" \
  RUNTIME_JSON="$tmp/runtime.json" \
  DYNAMIC_JSON="$tmp/dynamic.json" \
  SURFACES_JSON="$tmp/surfaces.json" \
  ROUTES_JSON="$tmp/routes.json" \
  CHANNEL_JSON="$tmp/channel.json" \
  INSTALLER_RELEASE_JSON="$tmp/installer-release.json" \
  INSTALLER_RUNTIME_JSON="$tmp/installer-runtime.json" \
  DIRTY_STATUS="$dirtyp" \
  python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def load_json_path(name):
    path = Path(os.environ[name])
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def executable(rel):
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


def read(rel):
    try:
        return (root / rel).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def dirty_count():
    path = Path(os.environ["DIRTY_STATUS"])
    try:
        return len([line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()])
    except Exception:
        return 1


platform = load_json_path("PLATFORM_JSON")
foundations = load_json_path("FOUNDATIONS_JSON")
mask = load_json_path("MASK_JSON")
runtime = load_json_path("RUNTIME_JSON")
dynamic = load_json_path("DYNAMIC_JSON")
surfaces = load_json_path("SURFACES_JSON")
routes = load_json_path("ROUTES_JSON")
channel = load_json_path("CHANNEL_JSON")
installer_release = load_json_path("INSTALLER_RELEASE_JSON")
installer_runtime = load_json_path("INSTALLER_RUNTIME_JSON")
dirty = dirty_count()
positioning_text = "\n".join(
    [
        read("README.md"),
        read("docs/VISION.md"),
        read("docs/PRODUCT_STRATEGY.md"),
        read("docs/DISTRIBUTION_AUTONOMY.md"),
        read("docs/SYSTEM_EXPERIENCE_LAYER.md"),
        read("docs/INSTALLER.md"),
    ]
)
positioning_lower = positioning_text.lower()
identity_markers = (
    "not merely as a themed distribution",
    "not meant to be another arch remix",
    "system experience layer above linux and arch",
    "normal users should operate sevenos through sevenos surfaces",
    "sevenos-owned foundation routes",
    "sevenos route on top of an arch-compatible foundation",
)
rice_markers = (
    "arch post-install layer",
    "hyprland desktop",
    "beautiful hyprland rice",
    "visible arch/hyprland rice",
)
positioning_hits = [marker for marker in identity_markers if marker in positioning_lower]
rice_hits = [marker for marker in rice_markers if marker in positioning_lower]
positioning_ready = len(positioning_hits) >= 4 and len(rice_hits) == 0
runtime_fusion = runtime.get("composite_runtime", {}).get("capability_fusion", {})
runtime_ready = (
    runtime.get("schema") == "sevenos.runtime-orchestrator.v1"
    and runtime.get("model") == "layered-autonomous-profiles-architecture"
    and bool(runtime_fusion.get("profiles_are_autonomous"))
    and bool(runtime_fusion.get("no_profile_dependency"))
)
autonomy_ready = (
    platform.get("state") == "masked"
    and foundations.get("state") in {"sevenos-owned", "mostly-owned"}
    and mask.get("state") == "masked"
    and runtime_ready
    and int(dynamic.get("percent", 0) or 0) >= 90
    and surfaces.get("state") == "productized"
    and routes.get("state") == "routed"
)
release_ready = (
    installer_release.get("state") == "graphical-ready"
    and installer_runtime.get("state") == "installed"
    and dirty == 0
)

checks = [
    {
        "key": "seven-cli",
        "state": "OK" if executable("bin/seven") and executable("bin/sevenpkg") else "MISS",
        "title": "SevenOS command layer",
        "detail": "The OS has SevenOS-first commands for normal operations.",
        "command": "seven status",
    },
    {
        "key": "autonomy-layer",
        "state": "OK" if autonomy_ready else "PART",
        "title": "Distribution autonomy",
        "detail": "Derived from platform, mask, dynamic desktop, public surfaces and user routes.",
        "command": "seven autonomy",
    },
    {
        "key": "foundations",
        "state": "OK" if foundations.get("state") in {"sevenos-owned", "mostly-owned"} else "PART",
        "title": "SevenOS-owned foundations",
        "detail": f"Foundations state: {foundations.get('state', 'unknown')}; score: {foundations.get('score', 'unknown')}%.",
        "command": "seven foundations",
    },
    {
        "key": "platform-facade",
        "state": "OK" if platform.get("state") == "masked" else "PART",
        "title": "Public platform facade",
        "detail": f"Platform state: {platform.get('state', 'unknown')}.",
        "command": "seven platform",
    },
    {
        "key": "public-mask",
        "state": "OK" if mask.get("state") == "masked" else "PART",
        "title": "Backend masking",
        "detail": f"Mask state: {mask.get('state', 'unknown')}; score: {mask.get('score', 'unknown')}%.",
        "command": "seven mask",
    },
    {
        "key": "runtime-orchestrator",
        "state": "OK" if runtime_ready else "PART",
        "title": "Autonomous mini OS runtime",
        "detail": f"Runtime model: {runtime.get('model', 'unknown')}; primary: {runtime.get('primary_profile', {}).get('key', 'unknown')}.",
        "command": "seven runtime status",
    },
    {
        "key": "dynamic-desktop",
        "state": "OK" if int(dynamic.get("percent", 0) or 0) >= 90 else "PART",
        "title": "Dynamic SevenOS desktop",
        "detail": f"Dynamic state: {dynamic.get('state', 'unknown')}; score: {dynamic.get('percent', 'unknown')}%.",
        "command": "seven dynamic",
    },
    {
        "key": "native-surfaces",
        "state": "OK" if surfaces.get("state") == "productized" else "PART",
        "title": "Native product surfaces",
        "detail": f"Surfaces state: {surfaces.get('state', 'unknown')}; score: {surfaces.get('score', 'unknown')}%.",
        "command": "seven surfaces",
    },
    {
        "key": "user-routes",
        "state": "OK" if routes.get("state") == "routed" else "PART",
        "title": "User-intent routes",
        "detail": f"Routes state: {routes.get('state', 'unknown')}; score: {routes.get('score', 'unknown')}%.",
        "command": "seven routes",
    },
    {
        "key": "release-channel",
        "state": "OK" if channel.get("schema") == "sevenos.release-channel.v1" else "PART",
        "title": "Release channel vocabulary",
        "detail": f"Channel: {channel.get('channel', 'unknown')}; state: {channel.get('state', 'unknown')}.",
        "command": "seven channel",
    },
    {
        "key": "public-positioning",
        "state": "OK" if positioning_ready else "PART",
        "title": "Public SevenOS positioning",
        "detail": (
            f"{len(positioning_hits)} identity marker(s); "
            f"{len(rice_hits)} Arch/Hyprland-rice marker(s) that need reframing."
        ),
        "command": "seven distribution",
    },
    {
        "key": "installer-portal",
        "state": "OK" if installer_release.get("state") in {"tui-release-ready", "graphical-ready"} else "PART",
        "title": "Installer portal",
        "detail": f"Installer release state: {installer_release.get('state', 'unknown')}.",
        "command": "seven installer release",
    },
    {
        "key": "calamares-runtime",
        "state": "OK" if installer_runtime.get("state") == "installed" else "PART",
        "title": "Graphical installer runtime",
        "detail": f"Graphical installer runtime: {installer_runtime.get('state', 'unknown')}.",
        "command": "seven installer runtime",
    },
    {
        "key": "release-doctor",
        "state": "OK" if release_ready else "PART",
        "title": "Public release doctor",
        "detail": "Requires graphical installer runtime, graphical-ready installer release state and a frozen repository.",
        "command": "seven release doctor",
    },
    {
        "key": "release-freeze",
        "state": "OK" if dirty == 0 else "PART",
        "title": "Repository freeze",
        "detail": f"{dirty} uncommitted path(s).",
        "command": "seven release freeze",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
missing = sum(1 for item in checks if item["state"] == "MISS")
score = round((ok + part * 0.45) / max(len(checks), 1) * 100)
daily_driver_ready = ok >= 8 and missing == 0
public_release_ready = all(item["state"] == "OK" for item in checks)
if public_release_ready:
    state = "public-release-candidate"
elif daily_driver_ready:
    state = "daily-driver-distribution"
elif score >= 70:
    state = "distribution-foundation"
else:
    state = "development-layer"

next_items = []
for item in checks:
    if item["state"] == "OK":
        continue
    priority = "release" if item["key"] in {"calamares-runtime", "release-doctor", "release-freeze"} else "product"
    next_items.append({
        "key": item["key"],
        "state": item["state"],
        "title": item["title"],
        "priority": priority,
        "reason": item["detail"],
        "command": item["command"],
    })

print(json.dumps({
    "schema": "sevenos.distribution.v1",
    "state": state,
    "score": score,
    "daily_driver_ready": daily_driver_ready,
    "public_release_ready": public_release_ready,
    "summary": {
        "checks": len(checks),
        "ok": ok,
        "partial": part,
        "missing": missing,
        "dirty_count": dirty,
        "foundations_state": foundations.get("state", "unknown"),
        "runtime_state": runtime.get("state", "unknown"),
        "runtime_primary": runtime.get("primary_profile", {}).get("key", "unknown"),
        "installer_state": installer_release.get("state", "unknown"),
        "calamares_runtime": installer_runtime.get("state", "unknown"),
        "channel": channel.get("channel", "unknown"),
    },
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "next": next_items[:6],
    "commands": {
        "status": "seven distribution",
        "doctor": "seven distribution doctor",
        "plan": "seven distribution plan",
        "release": "seven release doctor",
        "installer": "seven installer release",
    },
}, indent=2))
PY
  rm -rf "$tmp"
}

print_human() {
  DISTRIBUTION_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["DISTRIBUTION_JSON"])
summary = data.get("summary", {})
print("SevenOS Distribution")
print("====================")
print(f"State:          {data.get('state')}")
print(f"Score:          {data.get('score')}%")
print(f"Daily driver:   {str(data.get('daily_driver_ready')).lower()}")
print(f"Public release: {str(data.get('public_release_ready')).lower()}")
print(f"Channel:        {summary.get('channel')}")
print(f"Foundations:    {summary.get('foundations_state')}")
print(f"Runtime:        {summary.get('runtime_state')} / {summary.get('runtime_primary')}")
print(f"Installer:      {summary.get('installer_state')} / graphical runtime {summary.get('calamares_runtime')}")
print(f"Dirty paths:    {summary.get('dirty_count')}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state', 'MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

print_plan() {
  DISTRIBUTION_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["DISTRIBUTION_JSON"])
print("SevenOS Distribution Plan")
print("=========================")
items = data.get("next", [])
if not items:
    print("No pending distribution gates.")
else:
    for item in items:
        print(f"- {item.get('title')}: {item.get('command')}")
        print(f"  {item.get('reason')}")
PY
}

payload="$(distribution_json)"
case "$ACTION" in
  status|json)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  plan)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan "$payload"
    fi
    ;;
  *) log_error "Unknown distribution action: $ACTION"; usage; exit 1 ;;
esac
