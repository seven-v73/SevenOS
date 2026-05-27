#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0
shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help)
      cat <<'EOF'
SevenOS Release

Usage:
  seven release status [--json]
  seven release plan [--json]
  seven release review [--json]
  seven release freeze [--json]
  seven release doctor [--json]

This command separates the stable daily-driver state from the public release
gates: clean git freeze, graphical installer availability, and complete native
mini OS identity requirements.
EOF
      exit 0
      ;;
    *) log_error "Unknown release option: $arg"; exit 1 ;;
  esac
done

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/release"
FREEZE_JSON="$STATE_DIR/release-freeze.json"
GIT_STATUS_TXT="$STATE_DIR/git-status.txt"
DIFF_STAT_TXT="$STATE_DIR/diff-stat.txt"

json_escape() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

git_value() {
  local fallback="$1"
  shift
  git -C "$ROOT_DIR" "$@" 2>/dev/null || printf '%s\n' "$fallback"
}

git_dirty_count() {
  git -C "$ROOT_DIR" status --short 2>/dev/null | wc -l | tr -d ' '
}

git_dirty_summary_json() {
  GIT_STATUS_RAW="$(git -C "$ROOT_DIR" status --short 2>/dev/null || true)" python - <<'PY'
import json
import os
import sys

counts = {"modified": 0, "added": 0, "deleted": 0, "renamed": 0, "untracked": 0, "other": 0}
samples = []
paths = []
for raw in os.environ.get("GIT_STATUS_RAW", "").splitlines():
    if not raw.strip():
        continue
    code = raw[:2]
    path = raw[3:] if len(raw) > 3 else raw.strip()
    if code == "??":
        bucket = "untracked"
    elif "R" in code:
        bucket = "renamed"
    elif "D" in code:
        bucket = "deleted"
    elif "A" in code:
        bucket = "added"
    elif "M" in code:
        bucket = "modified"
    else:
        bucket = "other"
    counts[bucket] += 1
    paths.append(path)
    if len(samples) < 24:
        samples.append({"status": code.strip() or "?", "path": path})
print(json.dumps({"counts": counts, "samples": samples, "paths": paths}, ensure_ascii=False))
PY
}

doctor_release_json() {
  "$ROOT_DIR/scripts/doctor.sh" release --json 2>/dev/null || printf '{}'
}

doctor_check_json() {
  "$ROOT_DIR/scripts/doctor.sh" all --json 2>/dev/null || printf '{}'
}

installer_release_json() {
  "$ROOT_DIR/scripts/installer-stack.sh" release --json 2>/dev/null || printf '{}'
}

atlas_status_json() {
  "$ROOT_DIR/bin/seven" atlas status --json 2>/dev/null || printf '{}'
}

channel_status_json() {
  "$ROOT_DIR/scripts/channel.sh" json 2>/dev/null || printf '{}'
}

release_status_json() {
  local doctor installer atlas channel dirty_count dirty_summary branch commit freeze_state freeze_path
  doctor="$(doctor_check_json)"
  installer="$(installer_release_json)"
  atlas="$(atlas_status_json)"
  channel="$(channel_status_json)"
  dirty_count="$(git_dirty_count)"
  dirty_summary="$(git_dirty_summary_json)"
  branch="$(git_value unknown rev-parse --abbrev-ref HEAD)"
  commit="$(git_value unknown rev-parse --short HEAD)"
  freeze_state="MISS"
  freeze_path=""
  if [[ -s "$FREEZE_JSON" ]]; then
    freeze_state="OK"
    freeze_path="$FREEZE_JSON"
  fi
  DOCTOR_JSON="$doctor" INSTALLER_JSON="$installer" ATLAS_JSON="$atlas" CHANNEL_JSON="$channel" \
  DIRTY_COUNT="$dirty_count" DIRTY_SUMMARY="$dirty_summary" BRANCH="$branch" COMMIT="$commit" \
  FREEZE_STATE="$freeze_state" FREEZE_PATH="$freeze_path" ROOT_DIR="$ROOT_DIR" \
  python - <<'PY'
import json
import os

def load(name):
    try:
        return json.loads(os.environ.get(name, "{}"))
    except json.JSONDecodeError:
        return {}

doctor = load("DOCTOR_JSON")
installer = load("INSTALLER_JSON")
atlas = load("ATLAS_JSON")
channel = load("CHANNEL_JSON")
dirty_summary = load("DIRTY_SUMMARY")
dirty_count = int(os.environ.get("DIRTY_COUNT", "0") or 0)
summary = doctor.get("summary", {})
doctor_blocked = summary.get("critical", 1) > 0 or summary.get("high", 1) > 0
daily_ready = not doctor_blocked
calamares_runtime = installer.get("calamares_runtime") or next(
    (item.get("state") for item in installer.get("checks", []) if item.get("key") == "calamares-runtime"),
    "unknown",
)
calamares_runtime_detail = (
    "Calamares runtime installed in the ISO environment."
    if calamares_runtime in {"OK", "iso-runtime-ready"}
    else f"Calamares runtime policy: {calamares_runtime}; graphical public release still requires the runtime package in the ISO."
)
calamares_command = (
    "seven installer iso-runtime build-local-repo --dry-run"
    if calamares_runtime in {"aur-candidate", "source-declared", "iso-source-ready"}
    else "seven installer release"
)

release_actions = [
    {
        "key": "daily-driver-health",
        "state": "OK" if daily_ready else "PENDING",
        "title": "Conserver le socle daily-driver stable",
        "detail": f"{summary.get('critical', 0)} critical, {summary.get('high', 0)} high issue(s).",
        "command": "seven doctor check --json",
    },
    {
        "key": "freeze-worktree",
        "state": "OK" if dirty_count == 0 else "PENDING",
        "title": "Figer le dépôt avec un commit propre",
        "detail": f"{dirty_count} fichier(s) modifié(s) ou non suivis.",
        "command": "git status --short && git add <files> && git commit",
    },
    {
        "key": "calamares-iso",
        "state": "OK" if installer.get("state") == "graphical-ready" else "PENDING",
        "title": "Fournir Calamares dans l'environnement ISO",
        "detail": f"Installer state: {installer.get('state', 'unknown')}. {calamares_runtime_detail}",
        "command": calamares_command,
    },
    {
        "key": "atlas-readiness",
        "state": "OK" if not atlas.get("missing_required") else "PENDING",
        "title": "Compléter Atlas Explorer",
        "detail": f"Atlas state: {atlas.get('state', 'unknown')}; missing: {len(atlas.get('missing_required') or [])}.",
        "command": "seven atlas install --yes",
    },
]
release_issues = [item for item in release_actions if item["state"] not in {"OK", "READY", "RUN"}]
public_ready = not release_issues

print(json.dumps({
    "schema": "sevenos.release.v1",
    "root": os.environ.get("ROOT_DIR"),
    "branch": os.environ.get("BRANCH"),
    "commit": os.environ.get("COMMIT"),
    "channel": channel.get("channel", "dev"),
    "channel_state": channel.get("state", "unknown"),
    "state": "public-release-ready" if public_ready else "daily-driver-ready" if daily_ready else "release-blocked",
    "daily_driver_ready": daily_ready,
    "public_release_ready": public_ready,
    "worktree": {
        "dirty_count": dirty_count,
        "freeze_state": os.environ.get("FREEZE_STATE", "MISS"),
        "freeze_path": os.environ.get("FREEZE_PATH", ""),
        "summary": dirty_summary,
        "commands": {
            "status": "git status --short",
            "review": "seven release freeze --json",
            "commit": "git add <files> && git commit",
        },
    },
    "installer": {
        "state": installer.get("state", "unknown"),
        "calamares_runtime": calamares_runtime,
    },
    "atlas": {
        "state": atlas.get("state", "unknown"),
        "missing_required": atlas.get("missing_required", []),
    },
    "issues": doctor.get("issues", []) + release_issues,
    "release_actions": release_actions,
}, indent=2))
PY
}

release_plan_json() {
  local status
  status="$(release_status_json)"
  STATUS_JSON="$status" python - <<'PY'
import json
import os

data = json.loads(os.environ["STATUS_JSON"])
actions = data.get("release_actions", [])
installer = data.get("installer", {})
calamares_runtime = installer.get("calamares_runtime", "unknown")
installer_command = (
    "seven installer iso-runtime build-local-repo --dry-run"
    if calamares_runtime in {"aur-candidate", "source-declared", "iso-source-ready"}
    else "seven installer release"
)
installer_goal = (
    f"Transformer la source Calamares {calamares_runtime} en runtime embarqué dans l'ISO."
    if calamares_runtime in {"aur-candidate", "source-declared", "iso-source-ready"}
    else "Installer ou embarquer Calamares dans l'environnement ISO."
)
plan = [
    {
        "phase": "daily-driver",
        "state": "OK" if data.get("daily_driver_ready") else "PART",
        "goal": "Conserver SevenOS stable en usage quotidien.",
        "command": "seven doctor check --json",
    },
    {
        "phase": "repository-freeze",
        "state": next((item["state"] for item in actions if item["key"] == "freeze-worktree"), "PENDING"),
        "goal": "Créer un point de version vérifiable avant ISO publique.",
        "command": "seven release freeze && git status --short",
    },
    {
        "phase": "installer-iso",
        "state": next((item["state"] for item in actions if item["key"] == "calamares-iso"), "PENDING"),
        "goal": installer_goal,
        "command": installer_command,
    },
    {
        "phase": "atlas-explorer",
        "state": next((item["state"] for item in actions if item["key"] == "atlas-readiness"), "PENDING"),
        "goal": "Garder SevenOS à sept identités natives avec Atlas Explorer complet.",
        "command": "seven atlas status",
    },
]
print(json.dumps({
    "schema": "sevenos.release-plan.v1",
    "public_release_ready": data.get("public_release_ready", False),
    "plan": plan,
}, indent=2))
PY
}

release_review_json() {
  local status
  status="$(release_status_json)"
  STATUS_JSON="$status" ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
from pathlib import Path

data = json.loads(os.environ["STATUS_JSON"])
worktree = data.get("worktree", {})
summary = worktree.get("summary") if isinstance(worktree.get("summary"), dict) else {}
samples = summary.get("samples") if isinstance(summary.get("samples"), list) else []
all_paths = summary.get("paths") if isinstance(summary.get("paths"), list) else []
counts = summary.get("counts") if isinstance(summary.get("counts"), dict) else {}

groups = [
    {
        "key": "core-surfaces",
        "title": "Surfaces utilisateur SevenOS",
        "prefixes": ("bin/seven-", "bin/seven", "identity/", "hyprland", "branding/", "seven-shell/"),
        "reason": "UI, helper, terminal, dock, settings, notifications and visible OS behavior.",
    },
    {
        "key": "system-routes",
        "title": "Routes système et qualité",
        "prefixes": ("scripts/", "server/", "install.sh"),
        "reason": "Update, release, quality gates, server/deploy and install routes.",
    },
    {
        "key": "docs",
        "title": "Documentation et helper",
        "prefixes": ("docs/", "README", "progress.md"),
        "reason": "Public guidance, helper references and release notes.",
    },
]

paths = [str(path) for path in all_paths if path] or [item.get("path", "") for item in samples if isinstance(item, dict)]
for group in groups:
    group["sample_paths"] = [path for path in paths if path.startswith(group["prefixes"])][:8]
    group["state"] = "PRESENT" if group["sample_paths"] else "QUIET"
    group.pop("prefixes", None)

print(json.dumps({
    "schema": "sevenos.release-review.v1",
    "state": "clean" if int(worktree.get("dirty_count", 0) or 0) == 0 else "needs-freeze",
    "root": data.get("root") or os.environ["ROOT_DIR"],
    "branch": data.get("branch"),
    "commit": data.get("commit"),
    "dirty_count": int(worktree.get("dirty_count", 0) or 0),
    "counts": counts,
    "samples": samples,
    "groups": groups,
    "files": {
        "git_status": str(Path.home() / ".local/state/sevenos/release/git-status.txt"),
        "diff_stat": str(Path.home() / ".local/state/sevenos/release/diff-stat.txt"),
        "freeze_manifest": worktree.get("freeze_path") or str(Path.home() / ".local/state/sevenos/release/release-freeze.json"),
    },
    "commands": {
        "status": "git status --short",
        "freeze": "seven release freeze --json",
        "review": "seven release review --json",
        "identity": "seven identity experience",
        "commit_all": "git add -A && git commit",
        "release_doctor": "seven release doctor",
        "quality": "seven quality doctor",
    },
    "guidance": [
        "Review generated files before committing.",
        "Keep the SevenOS identity gate green before tagging a public build.",
        "Keep public release freeze separate from feature work when possible.",
        "Run seven quality doctor after the commit.",
    ],
}, indent=2, ensure_ascii=False))
PY
}

release_freeze_json() {
  mkdir -p "$STATE_DIR"
  git -C "$ROOT_DIR" status --short >"$GIT_STATUS_TXT" 2>/dev/null || true
  git -C "$ROOT_DIR" diff --stat >"$DIFF_STAT_TXT" 2>/dev/null || true

  local status dirty_count branch commit timestamp
  status="$(release_status_json)"
  dirty_count="$(git_dirty_count)"
  branch="$(git_value unknown rev-parse --abbrev-ref HEAD)"
  commit="$(git_value unknown rev-parse --short HEAD)"
  timestamp="$(date -Is)"
  STATUS_JSON="$status" DIRTY_COUNT="$dirty_count" BRANCH="$branch" COMMIT="$commit" \
  TIMESTAMP="$timestamp" ROOT_DIR="$ROOT_DIR" GIT_STATUS_TXT="$GIT_STATUS_TXT" DIFF_STAT_TXT="$DIFF_STAT_TXT" \
  python - <<'PY' >"$FREEZE_JSON"
import json
import os

status = json.loads(os.environ["STATUS_JSON"])
worktree = status.get("worktree") or {}
print(json.dumps({
    "schema": "sevenos.release-freeze.v1",
    "timestamp": os.environ["TIMESTAMP"],
    "root": os.environ["ROOT_DIR"],
    "branch": os.environ["BRANCH"],
    "commit": os.environ["COMMIT"],
    "dirty_count": int(os.environ["DIRTY_COUNT"]),
    "worktree": worktree,
    "git_status_path": os.environ["GIT_STATUS_TXT"],
    "diff_stat_path": os.environ["DIFF_STAT_TXT"],
    "daily_driver_ready": status.get("daily_driver_ready", False),
    "public_release_ready": status.get("public_release_ready", False),
    "state": status.get("state", "unknown"),
    "remaining_release_actions": [
        item for item in status.get("release_actions", [])
        if item.get("state") not in {"OK", "READY", "RUN"}
    ],
}, indent=2))
PY
  cat "$FREEZE_JSON"
}

print_status_human() {
  STATUS_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["STATUS_JSON"])
print("SevenOS Release Status")
print("======================")
print(f"Daily driver:   {data.get('daily_driver_ready')}")
print(f"Public release: {data.get('public_release_ready')}")
print(f"State:          {data.get('state')}")
print(f"Branch/commit:  {data.get('branch')} / {data.get('commit')}")
print(f"Dirty files:    {data.get('worktree', {}).get('dirty_count')}")
print()
print("Release gates:")
for item in data.get("release_actions", []):
    print(f"  - {item['state']:<13} {item['title']}")
    print(f"    {item['detail']}")
PY
}

print_plan_human() {
  PLAN_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PLAN_JSON"])
print("SevenOS Public Release Plan")
print("===========================")
for item in data.get("plan", []):
    print(f"  - {item['state']:<13} {item['phase']}: {item['goal']}")
    print(f"    {item['command']}")
PY
}

case "$ACTION" in
  status|json)
    payload="$(release_status_json)"
    if [[ "$JSON_OUTPUT" -eq 1 || "$ACTION" == "json" ]]; then
      printf '%s\n' "$payload"
    else
      print_status_human "$payload"
    fi
    ;;
  plan)
    payload="$(release_plan_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan_human "$payload"
    fi
    ;;
  review)
    payload="$(release_review_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      REVIEW_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["REVIEW_JSON"])
print("SevenOS Release Review")
print("======================")
print(f"State:       {data.get('state')}")
print(f"Dirty files: {data.get('dirty_count')}")
print("Counts:")
for key, value in (data.get("counts") or {}).items():
    if value:
        print(f"  - {key}: {value}")
print()
print("Groups:")
for group in data.get("groups", []):
    print(f"  - {group.get('state'):<7} {group.get('title')}")
    for path in group.get("sample_paths", [])[:5]:
        print(f"      {path}")
print()
print("Next:")
for label, command in (data.get("commands") or {}).items():
    if label in {"freeze", "commit_all", "quality"}:
        print(f"  {command}")
PY
    fi
    ;;
  freeze)
    payload="$(release_freeze_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      FREEZE_PAYLOAD="$payload" python - <<'PY'
import json
import os
data = json.loads(os.environ["FREEZE_PAYLOAD"])
print("SevenOS release freeze written")
print("==============================")
print(f"Manifest: {os.environ.get('XDG_STATE_HOME', os.path.expanduser('~/.local/state'))}/sevenos/release/release-freeze.json")
print(f"State:    {data.get('state')}")
print(f"Dirty:    {data.get('dirty_count')}")
print("Note: no git commit was created automatically.")
PY
    fi
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      doctor_release_json
    else
      "$ROOT_DIR/scripts/doctor.sh" release
    fi
    ;;
  *)
    log_error "Unknown release action: $ACTION"
    exit 1
    ;;
esac
