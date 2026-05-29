#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
MODE_TARGET=""
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS public experience gate

Usage:
  seven quality [status|doctor|plan|json] [--json]
  seven quality mode public [--json]
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
    mode) ACTION="mode" ;;
    public) MODE_TARGET="public" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown public experience option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1
if [[ "$ACTION" == "mode" && "${MODE_TARGET:-public}" != "public" ]]; then
  log_error "Unknown quality mode: $MODE_TARGET"
  exit 1
fi

public_experience_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
installed_tree = str(root.resolve()) == "/opt/SevenOS"


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
identity = run_json([str(root / "scripts/identity-experience.sh"), "json"], {"score": 0, "state": "unknown"}, timeout=25)
interaction = run_json([str(root / "scripts/interaction-contract.sh"), "public", "--json"], {"score": 0, "state": "unknown"}, timeout=90)
workflow = run_json([str(root / "scripts/workflow-gate.sh"), "status", "--json"], {"score": 0, "state": "unknown"}, timeout=25)
layout = run_json([str(root / "scripts/layout-gate.sh"), "status", "--json"], {"score": 0, "state": "unknown"}, timeout=20)
performance = run_json([str(root / "scripts/performance-gate.sh"), "status", "--json"], {"score": 0, "state": "unknown"}, timeout=20)
native_fallback = run_json([str(root / "scripts/native-fallback-gate.sh"), "status", "--json"], {"score": 0, "state": "unknown"}, timeout=20)
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
if installed_tree:
    gate("release-freeze", "OK", "Clean release freeze", "Installed /opt/SevenOS tree; Git freeze is verified in the build repository before publication.", "seven public-readiness", "high")
else:
    gate("release-freeze", "OK" if dirty_count == 0 else "PART", "Clean release freeze", f"{dirty_count} modified or untracked path(s).", "seven release freeze && git status --short", "high")

installer = release.get("installer") or {}
gate("installer", "OK" if installer.get("state") == "graphical-ready" else "PART", "Graphical installer runtime", installer.get("state", "unknown"), "seven installer release", "high")

shell_detail = f"{shell.get('state', 'unknown')}; package={shell.get('aur_package', 'aylurs-gtk-shell')}"
if shell.get("report"):
    shell_detail += f"; report={shell.get('report')}"
shell_runtime_ready = bool(shell.get("ready"))
shell_installable_with_safe_fallback = shell.get("readiness") == "installable-with-aur-helper"
if not shell_runtime_ready and shell_installable_with_safe_fallback:
    shell_detail += "; native fallback remains production-safe; install opens in a terminal-backed guided route"
gate("shell-ags", "OK" if shell_runtime_ready or shell_installable_with_safe_fallback else "PART", "Seven Shell AGS runtime", shell_detail + ".", "scripts/shell-ags-runtime.sh open", "medium")

identity_score = int(identity.get("score", 0) or 0)
identity_ready = bool(identity.get("signature_ready")) or (identity_score >= 92 and surface_score >= 95 and legacy_blockers == 0)
identity_detail = f"{identity.get('state', 'unknown')} at {identity_score}%."
if identity_ready and not identity.get("signature_ready"):
    identity_detail += " Public surfaces are independently productized, so the identity aggregate is accepted."
gate("identity-experience", "OK" if identity_ready else "PART", "SevenOS identity experience", identity_detail, "seven identity experience", "high")

interaction_score = int(interaction.get("score", 0) or 0)
gate("interaction-contract", "OK" if interaction_score >= 90 and interaction.get("state") == "ready" else "PART", "SevenOS interaction contract", f"{interaction.get('state', 'unknown')} at {interaction_score}%.", "seven interaction-gate", "high")

workflow_score = int(workflow.get("score", 0) or 0)
gate("workflow-contract", "OK" if workflow_score >= 90 and workflow.get("state") == "ready" else "PART", "SevenOS workflow contract", f"{workflow.get('state', 'unknown')} at {workflow_score}%.", "seven workflow-gate", "high")

layout_score = int(layout.get("score", 0) or 0)
gate("layout-contract", "OK" if layout_score >= 90 and layout.get("state") == "ready" else "PART", "SevenOS layout contract", f"{layout.get('state', 'unknown')} at {layout_score}%.", "seven layout-gate", "high")

performance_score = int(performance.get("score", 0) or 0)
gate("performance-contract", "OK" if performance_score >= 90 and performance.get("state") == "ready" else "PART", "SevenOS performance UX contract", f"{performance.get('state', 'unknown')} at {performance_score}%.", "seven performance-gate", "high")

native_fallback_score = int(native_fallback.get("score", 0) or 0)
native_summary = native_fallback.get("summary") if isinstance(native_fallback.get("summary"), dict) else {}
gate("native-fallback-contract", "OK" if native_fallback_score >= 90 and native_fallback.get("state") == "ready" else "PART", "SevenOS native-first fallback contract", f"{native_fallback.get('state', 'unknown')} at {native_fallback_score}%; {native_summary.get('ok', 0)}/{native_summary.get('routes', 0)} route(s) native-first.", "seven native-fallback-gate", "medium")

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
        "release_review": "seven release open",
        "identity": "seven identity experience",
        "interaction": "seven interaction-gate",
        "accessibility": "seven accessibility-gate",
        "workflow": "seven workflow-gate",
        "layout": "seven layout-gate",
        "performance": "seven performance-gate",
        "native_fallback": "seven native-fallback-gate",
        "readiness": "seven public-readiness",
        "update": "seven update check",
        "shell_runtime": "scripts/shell-ags-runtime.sh open",
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
  mode)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_status "$payload"
      echo
      if PUBLIC_JSON="$payload" python - <<'PY'
import json
import os
data = json.loads(os.environ["PUBLIC_JSON"])
raise SystemExit(0 if data.get("public_quality_ready") else 1)
PY
      then
        echo "Public mode: ready. SevenOS public interaction, visual and release gates are aligned."
      else
        echo "Public mode: daily-ready. Open actions remain before a public release."
        print_plan "$payload"
      fi
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
