#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS public experience gate

Usage:
  seven quality [status|doctor|plan|json] [--json]
  seven public-experience [status|doctor|plan|json] [--json]

This is the short public-quality gate. It combines the checks that matter most
for a polished user experience: health, visible surfaces, smoke contracts,
update route, release freeze state, mini OS readiness, Shell runtime and
Forge-only Server/Deploy policy.
EOF
}

for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown public experience option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

public_experience_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def run_json(command, fallback=None, timeout=45, env=None):
    fallback = fallback or {}
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
            env={**os.environ, "SEVENOS_ROOT": str(root), **(env or {})},
        )
    except Exception:
        return fallback
    if not result.stdout.strip():
        return fallback
    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback
    return value if isinstance(value, dict) else fallback


def gate(key, state, title, detail, command, severity="medium"):
    item = {
        "key": key,
        "state": state,
        "title": title,
        "detail": detail,
        "command": command,
        "severity": severity,
    }
    gates.append(item)
    if state not in {"OK", "READY", "RUN", "SKIP"}:
        issues.append(item)


health = run_json([str(root / "scripts/health.sh"), "json"], {"score": 0, "state": "unknown"}, env={"SEVENOS_HEALTH_FAST": "1"})
surfaces = run_json([str(root / "scripts/surfaces.sh"), "json"], {"score": 0, "summary": {}}, timeout=20)
smoke = run_json([str(root / "scripts/smoke.sh"), "json"], {"score": 0, "state": "unknown"}, timeout=70)
release = run_json([str(root / "scripts/release.sh"), "status", "--json"], {"state": "unknown", "worktree": {}}, timeout=80)
update = run_json([str(root / "scripts/update.sh"), "json"], {"score": 0, "state": "unknown"}, env={"SEVENOS_UPDATE_FAST": "1"})
shell = run_json([str(root / "scripts/shell-ags-runtime.sh"), "status", "--json"], {"state": "unknown", "ready": False})
mini = run_json([str(root / "bin/seven-mini-doctor"), "all", "doctor", "--json"], {"score": 0, "state": "unknown"}, timeout=45)
rootfs = run_json([str(root / "bin/seven-profile-rootfs"), "audit", "all", "--json"], {"summary": {}}, timeout=60)
server = run_json([str(root / "server/seven-server.sh"), "status", "--json"], {"state": "unknown"}, timeout=20)
deploy = run_json([str(root / "server/seven-deploy.sh"), "panel", "--json"], {"state": "unknown"}, timeout=20)

gates = []
issues = []

health_score = int(health.get("score", 0) or 0)
gate("health", "OK" if health_score >= 95 else "PART", "Daily health", f"{health.get('state', 'unknown')} at {health_score}%.", "seven health doctor", "high")

surface_summary = surfaces.get("summary") or {}
legacy_blockers = int(surface_summary.get("legacy_blockers", 0) or 0)
surface_score = int(surfaces.get("score", 0) or 0)
gate("surfaces", "OK" if surface_score >= 95 and legacy_blockers == 0 else "PART", "Native public surfaces", f"{surface_score}% with {legacy_blockers} legacy blocker(s).", "seven surfaces doctor", "high")

smoke_score = int(smoke.get("score", 0) or 0)
gate("smoke", "OK" if smoke_score >= 90 else "PART", "Fast product smoke", f"{smoke.get('state', 'unknown')} at {smoke_score}%.", "seven smoke doctor", "high")

update_score = int(update.get("score", 0) or 0)
repo = update.get("repository") or {}
public_location = bool(repo.get("public_location"))
opt_route_ready = (Path("/opt/SevenOS/bin/seven").exists() and Path("/opt/SevenOS/install.sh").exists())
update_state = "OK" if update_score >= 75 and (public_location or opt_route_ready) else "PART"
update_detail = f"{update.get('state', 'unknown')} at {update_score}%; root={update.get('root', 'unknown')}; /opt route={'ready' if opt_route_ready else 'missing'}."
gate("update-route", update_state, "Public update route", update_detail, "seven update check", "high")

worktree = release.get("worktree") or {}
dirty_count = int(worktree.get("dirty_count", 0) or 0)
gate("release-freeze", "OK" if dirty_count == 0 else "PART", "Clean release freeze", f"{dirty_count} modified or untracked path(s).", "seven release freeze && git status --short", "high")

installer = release.get("installer") or {}
gate("installer", "OK" if installer.get("state") == "graphical-ready" else "PART", "Graphical installer runtime", installer.get("state", "unknown"), "seven installer release", "high")

gate("shell-ags", "OK" if shell.get("ready") else "PART", "Seven Shell AGS runtime", f"{shell.get('state', 'unknown')}; package={shell.get('aur_package', 'aylurs-gtk-shell')}.", "./install.sh shell-ags-runtime --yes", "medium")

mini_profiles = mini.get("profiles") if isinstance(mini.get("profiles"), dict) else {}
if mini_profiles:
    mini_total = len(mini_profiles)
    mini_ready = sum(1 for item in mini_profiles.values() if isinstance(item, dict) and item.get("ready"))
    mini_missing = sum(int(((item.get("summary") or {}).get("required_missing", 0) or 0)) for item in mini_profiles.values() if isinstance(item, dict))
    mini_score = round(mini_ready / max(mini_total, 1) * 100)
    mini_detail = f"{mini_ready}/{mini_total} mini OS role-complete; {mini_missing} required package(s) missing."
else:
    mini_score = int(mini.get("score", 0) or 0)
    mini_detail = f"{mini.get('state', 'unknown')} at {mini_score}%."
gate("mini-os", "OK" if mini_score >= 90 else "PART", "Mini OS role completeness", mini_detail, "seven mini-doctor all --json", "high")

rootfs_summary = rootfs.get("summary") or {}
rootfs_ok = int(rootfs_summary.get("ok", 0) or rootfs_summary.get("ready", 0) or 0)
rootfs_total = int(rootfs_summary.get("total", 0) or rootfs_summary.get("profiles", 0) or rootfs_ok or 0)
gate("mini-os-rootfs", "OK" if rootfs_total and rootfs_ok >= rootfs_total else "PART", "Mini OS rootfs boundaries", f"{rootfs_ok}/{rootfs_total or '?'} rootfs audit OK.", "seven profile-rootfs audit all --json", "high")

deploy_gate = (
    deploy.get("schema") == "sevenos.profile-gate.v1"
    and deploy.get("required_profile") == "forge"
) or "forge" in json.dumps(deploy).lower()
gate("forge-deploy-gate", "OK" if deploy_gate else "PART", "Forge-only Server/Deploy", "Deploy surfaces must stay scoped to Forge.", "seven deploy panel --json", "medium")

bind = server.get("bind") if isinstance(server.get("bind"), dict) else {}
server_host = str(server.get("host") or bind.get("host") or "127.0.0.1")
gate("server-local-policy", "OK" if server_host in {"", "127.0.0.1", "localhost"} else "PART", "Local-only Seven Server", f"host={server_host}", "seven server doctor", "high")

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
issues.sort(key=lambda item: (rank.get(item["severity"], 9), item["key"]))
ok = sum(1 for item in gates if item["state"] == "OK")
score = round(ok / max(len(gates), 1) * 100)
public_ready = not issues
daily_ready = not any(item["severity"] in {"critical", "high"} and item["key"] not in {"release-freeze", "shell-ags"} for item in issues)

print(json.dumps({
    "schema": "sevenos.public-experience.v1",
    "state": "public-quality-ready" if public_ready else "daily-quality-ready" if daily_ready else "quality-needs-attention",
    "score": score,
    "daily_quality_ready": daily_ready,
    "public_quality_ready": public_ready,
    "summary": {
        "gates": len(gates),
        "ok": ok,
        "issues": len(issues),
        "high_or_critical": sum(1 for item in issues if item["severity"] in {"critical", "high"}),
    },
    "gates": gates,
    "issues": issues,
    "next": issues[:8],
    "commands": {
        "status": "seven quality",
        "doctor": "seven quality doctor",
        "release": "seven release doctor",
        "update": "seven update check",
        "shell_runtime": "./install.sh shell-ags-runtime --yes",
    },
}, indent=2))
PY
}

print_status() {
  PUBLIC_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PUBLIC_JSON"])
print("SevenOS Public Quality")
print("======================")
print(f"State: {data.get('state')}")
print(f"Score: {data.get('score')}%")
print(f"Daily quality:  {data.get('daily_quality_ready')}")
print(f"Public quality: {data.get('public_quality_ready')}")
print()
for item in data.get("gates", []):
    print(f"  {item.get('state', 'PART'):<4} {item.get('title')}")
    print(f"       {item.get('detail')}")
PY
}

print_plan() {
  PUBLIC_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PUBLIC_JSON"])
if not data.get("next"):
    print("SevenOS public quality plan: no open action.")
else:
    print("SevenOS public quality plan")
    print("===========================")
    for item in data.get("next", []):
        print(f"- {item.get('title')}: {item.get('command')}")
        print(f"  {item.get('detail')}")
PY
}

payload="$(public_experience_json)"
case "$ACTION" in
  status|json)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_status "$payload"
    fi
    ;;
  plan)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan "$payload"
    fi
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_status "$payload"
      echo
      print_plan "$payload"
    fi
    PUBLIC_JSON="$payload" python - <<'PY'
import json
import os
import sys
data = json.loads(os.environ["PUBLIC_JSON"])
sys.exit(0 if data.get("daily_quality_ready") else 1)
PY
    ;;
esac
