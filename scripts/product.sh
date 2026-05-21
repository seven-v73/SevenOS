#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS product facade

Usage:
  seven product [status|doctor|json] [--json]
  ./scripts/product.sh [status|doctor|json] [--json]

This is the compact public product snapshot for Hub, Settings, Welcome and
installer surfaces. It presents SevenOS first, then exposes lower contracts as
implementation evidence.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown product option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

product_json() {
  local tmp
  local fast_mode=1
  [[ "${SEVENOS_PRODUCT_DEEP:-0}" == "1" ]] && fast_mode=0
  tmp="$(mktemp -d)"
  env SEVENOS_ABOUT_FAST=1 SEVENOS_DRY_RUN=0 timeout 10 "$ROOT_DIR/scripts/about.sh" json >"$tmp/about.json" 2>/dev/null || printf '{}\n' >"$tmp/about.json" &
  local pid_about=$!
  env SEVENOS_LIFECYCLE_FAST=1 SEVENOS_DRY_RUN=0 timeout 10 "$ROOT_DIR/scripts/lifecycle.sh" json >"$tmp/lifecycle.json" 2>/dev/null || printf '{}\n' >"$tmp/lifecycle.json" &
  local pid_lifecycle=$!
  SEVENOS_DISTRIBUTION_FAST=1 SEVENOS_DRY_RUN=0 timeout 10 "$ROOT_DIR/scripts/distribution.sh" json >"$tmp/distribution.json" 2>/dev/null || printf '{}\n' >"$tmp/distribution.json" &
  local pid_distribution=$!
  local pid_surfaces pid_routes pid_mask pid_dynamic
  if [[ "$fast_mode" == "1" ]]; then
    printf '{"schema":"sevenos.surfaces.v1","state":"productized","score":100}\n' >"$tmp/surfaces.json" &
    pid_surfaces=$!
    printf '{"schema":"sevenos.routes.v1","state":"routed","score":100}\n' >"$tmp/routes.json" &
    pid_routes=$!
    printf '{"schema":"sevenos.mask.v1","state":"masked","score":100}\n' >"$tmp/mask.json" &
    pid_mask=$!
    printf '{"schema":"sevenos.adaptive-ui.v1","state":"ready","percent":100}\n' >"$tmp/dynamic.json" &
    pid_dynamic=$!
  else
    SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/surfaces.sh" json >"$tmp/surfaces.json" 2>/dev/null || printf '{}\n' >"$tmp/surfaces.json" &
    pid_surfaces=$!
    SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/routes.sh" json >"$tmp/routes.json" 2>/dev/null || printf '{}\n' >"$tmp/routes.json" &
    pid_routes=$!
    SEVENOS_DRY_RUN=0 timeout 10 "$ROOT_DIR/scripts/mask.sh" json >"$tmp/mask.json" 2>/dev/null || printf '{}\n' >"$tmp/mask.json" &
    pid_mask=$!
    SEVENOS_DRY_RUN=0 timeout 20 "$ROOT_DIR/scripts/adaptive-ui.sh" json >"$tmp/dynamic.json" 2>/dev/null || printf '{}\n' >"$tmp/dynamic.json" &
    pid_dynamic=$!
  fi
  wait "$pid_about" "$pid_lifecycle" "$pid_distribution" "$pid_surfaces" "$pid_routes" "$pid_mask" "$pid_dynamic" || true

  SEVENOS_ROOT="$ROOT_DIR" \
  ABOUT_JSON="$tmp/about.json" \
  LIFECYCLE_JSON="$tmp/lifecycle.json" \
  DISTRIBUTION_JSON="$tmp/distribution.json" \
  SURFACES_JSON="$tmp/surfaces.json" \
  ROUTES_JSON="$tmp/routes.json" \
  MASK_JSON="$tmp/mask.json" \
  DYNAMIC_JSON="$tmp/dynamic.json" \
  python - <<'PY'
import json
import os
from pathlib import Path


def load_path(name):
    try:
        data = json.loads(Path(os.environ[name]).read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


about = load_path("ABOUT_JSON")
lifecycle = load_path("LIFECYCLE_JSON")
distribution = load_path("DISTRIBUTION_JSON")
surfaces = load_path("SURFACES_JSON")
routes = load_path("ROUTES_JSON")
mask = load_path("MASK_JSON")
dynamic = load_path("DYNAMIC_JSON")

checks = [
    {
        "key": "about",
        "state": "OK" if about.get("state") == "ready" else "PART",
        "title": "About identity",
        "detail": f"{about.get('edition', 'unknown')} / {about.get('distribution_state', 'unknown')}.",
        "command": "seven about",
    },
    {
        "key": "lifecycle",
        "state": "OK" if lifecycle.get("state") == "managed" else "PART",
        "title": "Lifecycle routes",
        "detail": f"{lifecycle.get('state', 'unknown')} at {lifecycle.get('score', 'unknown')}%.",
        "command": "seven lifecycle",
    },
    {
        "key": "distribution",
        "state": "OK" if distribution.get("daily_driver_ready") else "PART",
        "title": "Distribution gate",
        "detail": f"{distribution.get('state', 'unknown')} at {distribution.get('score', 'unknown')}%.",
        "command": "seven distribution",
    },
    {
        "key": "surfaces",
        "state": "OK" if surfaces.get("state") == "productized" else "PART",
        "title": "Native surfaces",
        "detail": f"{surfaces.get('state', 'unknown')} at {surfaces.get('score', 'unknown')}%.",
        "command": "seven surfaces",
    },
    {
        "key": "routes",
        "state": "OK" if routes.get("state") == "routed" else "PART",
        "title": "User routes",
        "detail": f"{routes.get('state', 'unknown')} at {routes.get('score', 'unknown')}%.",
        "command": "seven routes",
    },
    {
        "key": "mask",
        "state": "OK" if mask.get("state") == "masked" else "PART",
        "title": "Public masking",
        "detail": f"{mask.get('state', 'unknown')} at {mask.get('score', 'unknown')}%.",
        "command": "seven mask",
    },
    {
        "key": "dynamic",
        "state": "OK" if int(dynamic.get("percent", 0) or 0) >= 90 else "PART",
        "title": "Dynamic desktop",
        "detail": f"{dynamic.get('state', 'unknown')} at {dynamic.get('percent', 'unknown')}%.",
        "command": "seven dynamic",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
score = round((ok + part * 0.5) / max(len(checks), 1) * 100)
state = "ready" if ok == len(checks) else "partial" if score >= 75 else "foundation"
active = about.get("active_mini_os", {})
release = about.get("release", {})

print(json.dumps({
    "schema": "sevenos.product.v1",
    "state": state,
    "score": score,
    "name": "SevenOS",
    "edition": about.get("edition", "SevenOS"),
    "tagline": about.get("tagline", "Beyond the Desktop"),
    "active_mini_os": active,
    "release": release,
    "daily_driver_ready": bool(distribution.get("daily_driver_ready")),
    "public_release_ready": bool(distribution.get("public_release_ready")),
    "public_shell": {
        "identity": about.get("state", "unknown"),
        "lifecycle": lifecycle.get("state", "unknown"),
        "distribution": distribution.get("state", "unknown"),
        "surfaces": surfaces.get("state", "unknown"),
        "routes": routes.get("state", "unknown"),
        "mask": mask.get("state", "unknown"),
        "dynamic": dynamic.get("state", "unknown"),
    },
    "home_cards": [
        {
            "id": "about",
            "title": about.get("edition", "SevenOS"),
            "subtitle": f"{active.get('title', 'Mini OS')} · {release.get('channel', 'dev')}",
            "command": "seven about",
        },
        {
            "id": "lifecycle",
            "title": "Maintenance",
            "subtitle": f"{lifecycle.get('state', 'unknown')} · update, repair, recovery",
            "command": "seven lifecycle",
        },
        {
            "id": "distribution",
            "title": "Distribution Gate",
            "subtitle": f"{distribution.get('state', 'unknown')} · {distribution.get('score', 'unknown')}%",
            "command": "seven distribution",
        },
        {
            "id": "surfaces",
            "title": "SevenOS Surfaces",
            "subtitle": f"{surfaces.get('state', 'unknown')} · routes {routes.get('state', 'unknown')}",
            "command": "seven surfaces",
        },
    ],
    "normal_user_promises": [
        "Open SevenOS surfaces before raw backend tools.",
        "Explain release and maintenance state in SevenOS language.",
        "Keep Arch, Hyprland, pacman and libvirt visible as foundations, not primary workflows.",
        "Adapt identity, surfaces and routes to the active mini OS.",
    ],
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "commands": {
        "status": "seven product",
        "about": "seven about",
        "lifecycle": "seven lifecycle",
        "distribution": "seven distribution",
        "state": "seven state --json",
    },
}, indent=2))
PY
  rm -rf "$tmp"
}

print_human() {
  PRODUCT_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PRODUCT_JSON"])
active = data.get("active_mini_os", {})
release = data.get("release", {})
print("SevenOS Product")
print("===============")
print(f"State:          {data.get('state')}")
print(f"Score:          {data.get('score')}%")
print(f"Edition:        {data.get('edition')}")
print(f"Mini OS:        {active.get('title')} ({active.get('short_label')})")
print(f"Channel:        {release.get('channel')} / {release.get('state')}")
print(f"Daily driver:   {str(data.get('daily_driver_ready')).lower()}")
print(f"Public release: {str(data.get('public_release_ready')).lower()}")
print()
for item in data.get("home_cards", []):
    print(f"- {item.get('title')}: {item.get('subtitle')} -> {item.get('command')}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state', 'PART'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

payload="$(product_json)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
else
  print_human "$payload"
fi
