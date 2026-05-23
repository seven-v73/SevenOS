#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS autonomy contract

Usage:
  seven autonomy [status|doctor|plan|json] [--json]
  ./scripts/autonomy.sh [status|doctor|plan|json] [--json]

This checks whether SevenOS is presented as an autonomous distribution layer
rather than a visible Arch/Hyprland rice.
EOF
}

ACTION="status"
JSON_OUTPUT=0
for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown autonomy option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

autonomy_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def exists(rel):
    return (root / rel).exists()


def executable(rel):
    path = root / rel
    return path.is_file() and os.access(path, os.X_OK)


def text_contains(rel, needle):
    path = root / rel
    try:
        return needle in path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return False


def run_json(parts, timeout=10):
    try:
        result = subprocess.run(
            [str(root / parts[0]), *parts[1:]],
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
            env={**os.environ, "SEVENOS_ROOT": str(root), "SEVENOS_DRY_RUN": "0"},
        )
    except Exception:
        return None
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except Exception:
        return None


installer = run_json(["scripts/installer-stack.sh", "release", "--json"], timeout=10) or {}
platform = run_json(["scripts/platform.sh", "json"], timeout=8) or {}
channel = run_json(["scripts/channel.sh", "json"], timeout=8) or {}
mask = run_json(["scripts/mask.sh", "json"], timeout=8) or {}
adaptive = run_json(["scripts/adaptive-ui.sh", "json"], timeout=8) or {}
surfaces = run_json(["scripts/surfaces.sh", "json"], timeout=8) or {}
routes = run_json(["scripts/routes.sh", "json"], timeout=8) or {}
runtime = run_json(["scripts/runtime-orchestrator.sh", "status", "--json"], timeout=8) or {}
dirty_count = 0
try:
    dirty = subprocess.run(["git", "status", "--short"], cwd=root, text=True, capture_output=True, check=False, timeout=5)
    dirty_count = len([line for line in dirty.stdout.splitlines() if line.strip()]) if dirty.returncode == 0 else 1
except Exception:
    dirty_count = 1
daily_driver_ready = True
public_release_ready = installer.get("state") == "graphical-ready" and dirty_count == 0
manifest_root = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "sevenos/profile-runtime-manifests"
manifest_count = len(list(manifest_root.glob("*.json"))) if manifest_root.is_dir() else 0
active_manifest = run_json(["bin/seven-profile-run", "--manifest"], timeout=8) or {}
runtime_fusion = runtime.get("composite_runtime", {}).get("capability_fusion", {})
runtime_ready = (
    runtime.get("schema") == "sevenos.runtime-orchestrator.v1"
    and runtime.get("model") == "layered-autonomous-profiles-architecture"
    and bool(runtime_fusion.get("profiles_are_autonomous"))
    and bool(runtime_fusion.get("no_profile_dependency"))
    and runtime.get("resource_plan", {}).get("allocator") == "Seven Resource Allocator"
)

checks = [
    {
        "key": "seven-first-cli",
        "state": "OK" if executable("bin/seven") and executable("bin/sevenpkg") else "MISS",
        "title": "SevenOS commands are first-class",
        "detail": "Users can operate the OS through seven/sevenpkg instead of raw pacman or Hyprland commands.",
        "command": "seven status",
    },
    {
        "key": "action-runner",
        "state": "OK" if executable("bin/seven-action-runner") else "MISS",
        "title": "Native action runner",
        "detail": "Hub and surfaces can run actions with logs/notifications instead of exposing terminals by default.",
        "command": "seven-action-runner --dry-run -- seven status",
    },
    {
        "key": "platform-facade",
        "state": "OK" if platform.get("state") == "masked" else "PART",
        "title": "SevenOS platform vocabulary",
        "detail": "User surfaces expose SevenOS layers first and keep Arch/Hyprland/pacman/systemd as backend details.",
        "command": "seven platform",
    },
    {
        "key": "public-mask",
        "state": "OK" if mask.get("state") == "masked" else "PART",
        "title": "SevenOS public masking",
        "detail": f"Mask state: {mask.get('state', 'unknown')}; score: {mask.get('score', 'unknown')}.",
        "command": "seven mask",
    },
    {
        "key": "dynamic-adaptation",
        "state": "OK" if int(adaptive.get("percent", 0) or 0) >= 90 else "PART",
        "title": "SevenOS dynamic adaptation",
        "detail": f"Adaptive state: {adaptive.get('state', 'unknown')}; score: {adaptive.get('percent', 'unknown')}%.",
        "command": "seven dynamic",
    },
    {
        "key": "public-surfaces",
        "state": "OK" if surfaces.get("state") == "productized" else "PART",
        "title": "SevenOS public surfaces",
        "detail": f"Surfaces state: {surfaces.get('state', 'unknown')}; score: {surfaces.get('score', 'unknown')}%.",
        "command": "seven surfaces",
    },
    {
        "key": "user-routes",
        "state": "OK" if routes.get("state") == "routed" else "PART",
        "title": "SevenOS user routes",
        "detail": f"Routes state: {routes.get('state', 'unknown')}; score: {routes.get('score', 'unknown')}%.",
        "command": "seven routes",
    },
    {
        "key": "release-channel",
        "state": "OK" if channel.get("schema") == "sevenos.release-channel.v1" else "PART",
        "title": "SevenOS release channel",
        "detail": f"Current channel: {channel.get('channel', 'unknown')}; state: {channel.get('state', 'unknown')}.",
        "command": "seven channel",
    },
    {
        "key": "identity-mask",
        "state": "OK" if all([
            exists("branding/sevenos-release"),
            text_contains("archiso/profile/airootfs/etc/os-release", "SevenOS"),
            text_contains("branding/motd", "SevenOS"),
        ]) else "PART",
        "title": "Boot and shell identity",
        "detail": "Release, MOTD and live ISO identity present SevenOS before the underlying platform.",
        "command": "cat /etc/os-release",
    },
    {
        "key": "hub-settings-surfaces",
        "state": "OK" if executable("bin/seven-hub-native") and executable("bin/seven-settings-native") else "MISS",
        "title": "Native control surfaces",
        "detail": "Normal users have Seven Hub and Settings as primary OS surfaces.",
        "command": "seven hub",
    },
    {
        "key": "software-facade",
        "state": "OK" if executable("bin/seven-store-native") and executable("bin/sevenpkg") else "MISS",
        "title": "SevenOS software facade",
        "detail": "Applications are discovered and managed through SevenStore/sevenpkg, with pacman/AUR treated as backends.",
        "command": "seven store",
    },
    {
        "key": "mini-os-runtime",
        "state": "OK" if isinstance(active_manifest, dict) and active_manifest.get("schema") and manifest_count >= 7 else "PART",
        "title": "Mini OS runtime manifests",
        "detail": "Profiles expose strict HOME/cache/data/workspace contracts instead of only theme labels.",
        "command": "seven-profile-run --manifest",
    },
    {
        "key": "runtime-orchestrator",
        "state": "OK" if runtime_ready else "PART",
        "title": "Layered autonomous runtime",
        "detail": f"Runtime model: {runtime.get('model', 'unknown')}; primary profile: {runtime.get('primary_profile', {}).get('key', 'unknown')}.",
        "command": "seven runtime status",
    },
    {
        "key": "daemon-foundation",
        "state": "OK" if executable("bin/seven-daemon") and exists("systemd/user/seven-daemon.service") else "PART",
        "title": "SevenDaemon foundation",
        "detail": "A daemon/service path exists for moving runtime policy out of shell scripts.",
        "command": "seven core health --json",
    },
    {
        "key": "installer-gate",
        "state": "OK" if installer.get("state") == "graphical-ready" else "PART",
        "title": "Distribution installer gate",
        "detail": f"Installer state: {installer.get('state', 'unknown')}. Public release still needs the graphical ISO path locked.",
        "command": "seven installer release",
    },
    {
        "key": "release-freeze",
        "state": "OK" if dirty_count == 0 else "PART",
        "title": "Release discipline",
        "detail": f"{dirty_count} uncommitted path(s). Public release ready: {str(public_release_ready).lower()}.",
        "command": "seven release freeze",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
score = round((ok + part * 0.5) / max(len(checks), 1) * 100)
if score >= 90:
    level = "distribution-layer"
elif score >= 75:
    level = "autonomous-daily-driver"
elif score >= 60:
    level = "masked-arch-layer"
else:
    level = "rice-risk"

print(json.dumps({
    "schema": "sevenos.autonomy.v1",
    "level": level,
    "score": score,
    "summary": {
        "checks": len(checks),
        "ok": ok,
        "partial": part,
        "missing": sum(1 for item in checks if item["state"] == "MISS"),
        "arch_visible": score < 90,
        "daily_driver_ready": daily_driver_ready,
        "public_release_ready": public_release_ready,
    },
    "checks": checks,
    "issues": [item for item in checks if item["state"] != "OK"],
    "next": [item for item in checks if item["state"] != "OK"][:5],
}, indent=2))
PY
}

print_human() {
  local payload="$1"
  AUTONOMY_JSON="$payload" python - <<'PY'
import json, os
data=json.loads(os.environ["AUTONOMY_JSON"])
summary=data.get("summary", {})
print("SevenOS Autonomy")
print("================")
print(f"Level: {data.get('level')}")
print(f"Score: {data.get('score')}%")
print(f"Checks: {summary.get('ok')}/{summary.get('checks')} OK, {summary.get('partial')} partial")
print(f"Arch visible: {str(summary.get('arch_visible')).lower()}")
print(f"Public release: {str(summary.get('public_release_ready')).lower()}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state','MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
}

print_plan() {
  local payload="$1"
  AUTONOMY_JSON="$payload" python - <<'PY'
import json, os
data=json.loads(os.environ["AUTONOMY_JSON"])
print("SevenOS Autonomy Plan")
print("=====================")
for item in data.get("next", []):
    print(f"- {item.get('title')}")
    print(f"  {item.get('detail')}")
    print(f"  command: {item.get('command')}")
if not data.get("next"):
    print("No autonomy blockers.")
PY
}

payload="$(autonomy_json)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$payload"
  exit 0
fi

case "$ACTION" in
  status) print_human "$payload" ;;
  plan) print_plan "$payload" ;;
  doctor)
    print_human "$payload"
    score="$(AUTONOMY_JSON="$payload" python - <<'PY'
import json, os
print(json.loads(os.environ["AUTONOMY_JSON"]).get("score", 0))
PY
)"
    if [[ "$score" -ge 75 ]]; then
      log_success "SevenOS autonomy contract is coherent."
    else
      log_warn "SevenOS still looks too much like an exposed Arch/Hyprland layer."
      exit 1
    fi
    ;;
esac
