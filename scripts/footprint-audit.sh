#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${PWD:-}/install.sh" && -d "${PWD:-}/.git" ]]; then
  ROOT_DIR="$PWD"
else
  ROOT_DIR="${SEVENOS_SOURCE_ROOT:-$SCRIPT_ROOT}"
fi
RUNTIME_ROOT="${SEVENOS_RUNTIME_ROOT:-/opt/SevenOS}"
ACTION="${1:-status}"
JSON=0
FAST=0

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON=1 ;;
    --fast) FAST=1 ;;
  esac
done

if [[ "$ACTION" == "--json" || "$ACTION" == "--fast" ]]; then
  ACTION="status"
fi

usage() {
  cat <<'EOF'
SevenOS Footprint Audit

Usage:
  seven footprint
  seven footprint --json
  seven footprint --fast --json
  seven footprint plan
  seven footprint cleanup
  seven footprint record
  seven footprint compare
  seven footprint trend
  seven footprint guard
  scripts/footprint-audit.sh [status|json|plan|cleanup|record|evidence|compare|trend|guard]

The audit is read-only. The cleanup action removes only reconstructible caches
and build work directories; it never removes notes, rootfs, Windows prefixes,
VMs or user documents.
EOF
}

human_bytes() {
  python - "$1" <<'PY'
import sys
value = int(sys.argv[1] or 0)
units = ["B", "KiB", "MiB", "GiB", "TiB"]
size = float(value)
unit = units[0]
for unit in units:
    if size < 1024 or unit == units[-1]:
        break
    size /= 1024
if unit == "B":
    print(f"{int(size)} {unit}")
else:
    print(f"{size:.1f} {unit}")
PY
}

path_bytes() {
  local path="$1"
  [[ -e "$path" ]] || { printf '0\n'; return 0; }
  du -sb "$path" 2>/dev/null | awk '{print $1}'
}

remove_user_path() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  rm -rf -- "$path" 2>/dev/null || return 1
}

remove_admin_path() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  if [[ "$(id -u)" == "0" ]]; then
    rm -rf -- "$path"
    return $?
  fi
  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo rm -rf -- "$path"
    return $?
  fi
  return 77
}

cleanup_json() {
  local before after before_path after_path reclaimed=0 blocked=0 failed=0
  local -a records=()
  local path status bytes_after bytes_before

  before="$(df -B1 "$HOME" | awk 'NR==2 {print $4}')"

  for path in \
    "$HOME/.cache/yay" \
    "$HOME/.cache/ms-playwright" \
    "$HOME/.cache/sevenos/aur" \
    "$HOME/.cache/sevenos/file-thumbnails" \
    "$HOME/.cache/sevenos/reader" \
    "$HOME/.cache/go-build" \
    "$HOME/.cache/pip/http-v2"
  do
    bytes_before="$(path_bytes "$path")"
    status="missing"
    if [[ "$bytes_before" -gt 0 ]]; then
      if remove_user_path "$path"; then
        status="removed"
      else
        status="failed"
        failed=$((failed + 1))
      fi
    fi
    bytes_after="$(path_bytes "$path")"
    reclaimed=$((reclaimed + bytes_before - bytes_after))
    records+=("{\"path\":\"$path\",\"scope\":\"user-cache\",\"state\":\"$status\",\"reclaimed_bytes\":$((bytes_before - bytes_after))}")
  done

  local state_dir="$HOME/.local/state/sevenos"
  local removed_help=0 removed_events=0 before_state after_state
  if [[ -d "$state_dir" ]]; then
    shopt -s nullglob
    local -a help_files=("$state_dir"/help-center-*.md)
    local -a event_backups=("$state_dir"/events.jsonl.*.bak)
    shopt -u nullglob

    for path in "${help_files[@]}"; do
      before_state="$(path_bytes "$path")"
      rm -f -- "$path" 2>/dev/null || true
      after_state="$(path_bytes "$path")"
      removed_help=$((removed_help + before_state - after_state))
    done
    for path in "${event_backups[@]}"; do
      before_state="$(path_bytes "$path")"
      rm -f -- "$path" 2>/dev/null || true
      after_state="$(path_bytes "$path")"
      removed_events=$((removed_events + before_state - after_state))
    done
  fi
  reclaimed=$((reclaimed + removed_help + removed_events))
  records+=("{\"path\":\"$HOME/.local/state/sevenos/help-center-*.md\",\"scope\":\"state-cache\",\"state\":\"trimmed\",\"reclaimed_bytes\":$removed_help}")
  records+=("{\"path\":\"$HOME/.local/state/sevenos/events.jsonl.*.bak\",\"scope\":\"state-cache\",\"state\":\"trimmed\",\"reclaimed_bytes\":$removed_events}")

  for path in "$ROOT_DIR/out/archiso" "$ROOT_DIR/out/calamares-aur" "$RUNTIME_ROOT/out/archiso" "$RUNTIME_ROOT/out/calamares-aur"
  do
    bytes_before="$(path_bytes "$path")"
    status="missing"
    if [[ "$bytes_before" -gt 0 ]]; then
      if remove_admin_path "$path"; then
        status="removed"
      else
        code=$?
        if [[ "$code" == 77 ]]; then
          status="admin-required"
          blocked=$((blocked + 1))
        else
          status="failed"
          failed=$((failed + 1))
        fi
      fi
    fi
    bytes_after="$(path_bytes "$path")"
    reclaimed=$((reclaimed + bytes_before - bytes_after))
    records+=("{\"path\":\"$path\",\"scope\":\"admin-build-cache\",\"state\":\"$status\",\"reclaimed_bytes\":$((bytes_before - bytes_after))}")
  done

  after="$(df -B1 "$HOME" | awk 'NR==2 {print $4}')"
  local state="cleaned"
  [[ "$blocked" -gt 0 ]] && state="admin-required"
  [[ "$failed" -gt 0 ]] && state="attention"
  printf '{"schema":"sevenos.footprint-cleanup.v1","state":"%s","reclaimed_bytes":%s,"reclaimed":"%s","free_before":"%s","free_after":"%s","blocked":%s,"failed":%s,"items":[%s],"admin_command":"sudo rm -rf %q %q %q %q","policy":"Only reconstructible caches and build work directories are touched. Rootfs, VMs, Windows prefixes, notes and user documents are preserved."}\n' \
    "$state" "$reclaimed" "$(human_bytes "$reclaimed")" "$(human_bytes "$before")" "$(human_bytes "$after")" "$blocked" "$failed" \
    "$(IFS=,; printf '%s' "${records[*]}")" \
    "$ROOT_DIR/out/archiso" "$ROOT_DIR/out/calamares-aur" "$RUNTIME_ROOT/out/archiso" "$RUNTIME_ROOT/out/calamares-aur"
}

latest_iso_in() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | awk 'NR==1 {sub(/^[^ ]+ /,""); print}'
}

collect_json() {
  local source_iso opt_iso
  source_iso="$(latest_iso_in "$ROOT_DIR/out/iso" || true)"
  opt_iso="$(latest_iso_in "$RUNTIME_ROOT/out/iso" || true)"
  ROOT_DIR="$ROOT_DIR" RUNTIME_ROOT="$RUNTIME_ROOT" SOURCE_ISO="$source_iso" OPT_ISO="$opt_iso" FAST="$FAST" python - <<'PY'
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

root = Path(os.environ["ROOT_DIR"]).resolve()
opt = Path(os.environ.get("RUNTIME_ROOT", "/opt/SevenOS")).resolve()
source_iso = Path(os.environ["SOURCE_ISO"]) if os.environ.get("SOURCE_ISO") else None
opt_iso = Path(os.environ["OPT_ISO"]) if os.environ.get("OPT_ISO") else None
fast = os.environ.get("FAST") == "1"

def bytes_of(path: Path) -> int:
    try:
        if path.is_file():
            return path.stat().st_size
        if not path.exists():
            return 0
        result = subprocess.run(
            ["du", "-sb", str(path)],
            text=True,
            capture_output=True,
            check=False,
            timeout=float(os.environ.get("SEVENOS_FOOTPRINT_DU_TIMEOUT", "4.0")),
        )
        if result.stdout.strip():
            return int(result.stdout.split()[0])
    except subprocess.TimeoutExpired:
        return -1
    except Exception:
        pass
    return -2

def human(size: int) -> str:
    if size < 0:
        return "timeout" if size == -1 else "unavailable"
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{size} B"

def top_dirs(path: Path, depth: int = 1, limit: int = 12) -> list[dict]:
    if not path.exists() or not path.is_dir():
        return []
    candidates: list[Path] = []
    try:
        if depth <= 1:
            candidates = [p for p in path.iterdir() if p.is_dir()]
        else:
            candidates = [p for p in path.glob("*/*") if p.is_dir()]
    except Exception:
        return []
    rows = []
    for item in candidates:
        rows.append({"path": str(item), "bytes": bytes_of(item)})
    rows.sort(key=lambda row: row["bytes"], reverse=True)
    return [{**row, "size": human(row["bytes"])} for row in rows[:limit]]

def find_dir(path: Path, candidates: list[str]) -> dict | None:
    for suffix in candidates:
        item = path / suffix
        if item.exists():
            size = bytes_of(item)
            return {"path": str(item), "bytes": size, "size": human(size)}
    return None

def command_json(command: list[str], timeout: float = 8.0) -> dict:
    try:
        result = subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
        if result.returncode != 0:
            return {
                "state": "MISS",
                "error": result.stderr.strip() or result.stdout.strip() or f"exit={result.returncode}",
            }
        return json.loads(result.stdout)
    except Exception as exc:
        return {"state": "MISS", "error": str(exc)}

def iso_info(path: Path | None) -> dict:
    if not path or not path.exists():
        return {"state": "MISS", "path": "", "size": "0 B", "bytes": 0, "age_hours": None}
    try:
        age_hours = round((time.time() - path.stat().st_mtime) / 3600, 1)
    except Exception:
        age_hours = None
    size = bytes_of(path)
    return {"state": "OK", "path": str(path), "size": human(size), "bytes": size, "age_hours": age_hours}

def git_snapshot(path: Path) -> dict:
    if not (path / ".git").exists():
        return {"state": "not-a-git-tree", "dirty_count": 0, "branch": "", "commit": "", "paths": []}
    def run_git(args: list[str], timeout: float = 2.0) -> str:
        try:
            result = subprocess.run(
                ["git", "-C", str(path), *args],
                text=True,
                capture_output=True,
                check=False,
                timeout=timeout,
            )
            return result.stdout.strip() if result.returncode == 0 else ""
        except Exception:
            return ""
    status = run_git(["status", "--short"], timeout=4.0)
    paths = [line for line in status.splitlines() if line.strip()]
    branch = run_git(["rev-parse", "--abbrev-ref", "HEAD"]) or "unknown"
    commit = run_git(["rev-parse", "--short", "HEAD"]) or "unknown"
    return {
        "state": "dirty" if paths else "clean",
        "dirty_count": len(paths),
        "branch": branch,
        "commit": commit,
        "paths": paths[:80],
    }

repo_bytes = 0 if fast else bytes_of(root)
opt_bytes = 0 if fast else bytes_of(opt)
git = git_snapshot(root)
home_cache = Path.home() / ".cache"
sevenos_share = Path.home() / ".local/share/sevenos"
sevenos_share_bytes = 0 if fast else bytes_of(sevenos_share)
state_dir = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "sevenos"
event_file = state_dir / "events.jsonl"
events_bytes = bytes_of(event_file)
package_footprint = command_json([str(root / "bin" / "sevenpkg"), "footprint", "--fast", "--json"])
package_summary = package_footprint.get("summary") if isinstance(package_footprint, dict) else {}
duplicated_packages = int((package_summary or {}).get("duplicated_packages") or 0)
ready_rootfs = int((package_summary or {}).get("ready_rootfs") or 0)
mini_os_count = int((package_summary or {}).get("mini_os") or 0)

checks = []
def check(key, state, title, detail, command=""):
    checks.append({"key": key, "state": state, "title": title, "detail": detail, "command": command})

if fast:
    check("repo-size", "SKIP", "Source repository footprint", f"Skipped in fast mode for {root}", "seven footprint --json")
    check("opt-size", "SKIP", "Installed runtime footprint", "Skipped in fast mode for /opt/SevenOS", "seven footprint --json")
    check("sevenos-share-size", "SKIP", "SevenOS local state footprint", f"Skipped in fast mode for {sevenos_share}", "seven footprint plan")
else:
    check("repo-size", "SKIP" if repo_bytes < 0 else ("ATTENTION" if repo_bytes > 10 * 1024**3 else "OK"), "Source repository footprint", f"{human(repo_bytes)} in {root}", "SEVENOS_FOOTPRINT_DU_TIMEOUT=20 seven footprint --json" if repo_bytes < 0 else "")
    check("opt-size", "SKIP" if opt_bytes < 0 else ("ATTENTION" if opt_bytes > 12 * 1024**3 else "OK"), "Installed runtime footprint", f"{human(opt_bytes)} in /opt/SevenOS", "SEVENOS_FOOTPRINT_DU_TIMEOUT=20 seven footprint --json" if opt_bytes < 0 else "")
    check("sevenos-share-size", "SKIP" if sevenos_share_bytes < 0 else ("ATTENTION" if sevenos_share_bytes > 70 * 1024**3 else "OK"), "SevenOS local state footprint", f"{human(sevenos_share_bytes)} in {sevenos_share}", "seven footprint plan")
check(
    "rootfs-duplication",
    "ATTENTION" if duplicated_packages > 800 else "OK",
    "Mini OS rootfs package duplication",
    f"{duplicated_packages} duplicated package name(s); {ready_rootfs}/{mini_os_count} mini OS rootfs ready",
    "sevenpkg footprint --fast --json",
)
src_iso = iso_info(source_iso)
installed_iso = iso_info(opt_iso)
check("source-iso", src_iso["state"], "Source tree ISO artifact", src_iso["path"] or "No ISO in source out/iso.")
check("installed-iso", installed_iso["state"], "Installed runtime ISO artifact", installed_iso["path"] or "No ISO in /opt/SevenOS/out/iso.")
check("sevenbus-size", "ATTENTION" if events_bytes > 20 * 1024**2 else "OK", "SevenBus event journal", f"{human(events_bytes)} at {event_file}", "seven core compact-bus --keep 5000 --json")
check("git-freeze", "ATTENTION" if git["dirty_count"] else "OK", "Release freeze worktree", f"{git['dirty_count']} modified/untracked path(s) on {git['branch']}@{git['commit']}", "git status --short")

recommendations = [
    {
        "title": "Keep source and installed ISO states separate",
        "detail": "A runtime ISO under /opt is useful evidence, but release work should validate the source tree out/iso artifact.",
        "command": "ls -lh out/iso /opt/SevenOS/out/iso 2>/dev/null",
        "risk": "low",
    },
    {
        "title": "Compact SevenBus periodically",
        "detail": "The JSONL bus is safe but should stay bounded until typed IPC replaces it.",
        "command": "seven core compact-bus --keep 5000 --json",
        "risk": "low",
    },
    {
        "title": "Review large directories before deleting anything",
        "detail": "This audit is read-only. Cleanups should be explicit and never remove user data automatically.",
        "command": "seven footprint --json",
        "risk": "low",
    },
    {
        "title": "Treat ~/.local/share/sevenos as platform state, not cache",
        "detail": "Rootfs, VM disks and Windows prefixes can be large but are user-visible system state. They should be archived, compacted or removed only through guided flows.",
        "command": "seven footprint plan",
        "risk": "low",
    },
]

cleanup_plan = []
def plan_item(key, title, detail, path, command, risk="low", reclaim_bytes=0, confirm=False, reclaimable=True):
    cleanup_plan.append({
        "key": key,
        "title": title,
        "detail": detail,
        "path": str(path) if path else "",
        "command": command,
        "risk": risk,
        "reclaim_bytes": int(reclaim_bytes or 0),
        "reclaim": human(int(reclaim_bytes or 0)),
        "reclaimable": bool(reclaimable),
        "requires_confirmation": bool(confirm),
    })

out_archiso = None if fast else find_dir(root, ["out/archiso"])
if out_archiso and out_archiso["bytes"] > 1024**3:
    plan_item(
        "source-build-cache",
        "Review source archiso build cache",
        "Generated archiso work directories are useful while debugging ISO builds, but should not live inside a release-freeze tree.",
        out_archiso["path"],
        "du -sh out/archiso && find out/archiso -maxdepth 2 -type d | head -n 40",
        "low",
        out_archiso["bytes"],
        False,
    )

calamares_aur = None if fast else find_dir(root, ["out/calamares-aur"])
if calamares_aur and calamares_aur["bytes"] > 200 * 1024**2:
    plan_item(
        "calamares-build-cache",
        "Review Calamares AUR build cache",
        "The local Calamares package should stay in archiso/localrepo; the temporary AUR build tree can be reviewed separately.",
        calamares_aur["path"],
        "du -sh out/calamares-aur archiso/localrepo/x86_64 2>/dev/null",
        "low",
        calamares_aur["bytes"],
        False,
    )

opt_archiso = None if fast else find_dir(opt, ["out/archiso"])
if opt_archiso and opt_archiso["bytes"] > 1024**3:
    plan_item(
        "runtime-build-cache",
        "Review installed runtime build cache",
        "The installed runtime should not carry heavy ISO work directories unless actively building there.",
        opt_archiso["path"],
        "du -sh /opt/SevenOS/out/archiso /opt/SevenOS/out/iso 2>/dev/null",
        "medium",
        opt_archiso["bytes"],
        True,
    )

yay_cache = Path.home() / ".cache/yay"
if yay_cache.exists() and not fast:
    yay_bytes = bytes_of(yay_cache)
    if yay_bytes > 5 * 1024**3:
        plan_item(
            "aur-user-cache",
            "Review AUR user cache",
            "Large AUR caches are outside SevenOS core. They can explain disk pressure but must remain user-controlled.",
            yay_cache,
            "du -sh ~/.cache/yay && yay -Sc",
            "medium",
            yay_bytes,
            True,
        )

seven_cache = Path.home() / ".cache/sevenos"
if seven_cache.exists() and not fast:
    cache_bytes = bytes_of(seven_cache)
    if cache_bytes > 1024**3:
        plan_item(
            "sevenos-user-cache",
            "Review SevenOS user cache",
            "SevenOS cache can be useful for diagnostics and previews; inspect before trimming.",
            seven_cache,
            "du -sh ~/.cache/sevenos && find ~/.cache/sevenos -maxdepth 2 -type d -printf '%p\\n' | head -n 80",
            "low",
            cache_bytes,
            False,
        )

rootfs_dir = sevenos_share / "profile-rootfs"
if rootfs_dir.exists() and not fast:
    rootfs_bytes = bytes_of(rootfs_dir)
    if rootfs_bytes > 40 * 1024**3:
        plan_item(
            "profile-rootfs-footprint",
            "Audit mini OS rootfs footprint",
            "Rootfs trees are core SevenOS state, not disposable cache. Review per-profile size and duplication before installing more optional stacks.",
            rootfs_dir,
            "du -h -d 2 ~/.local/share/sevenos/profile-rootfs | sort -hr | head -n 40 && sevenpkg footprint --json",
            "medium",
            rootfs_bytes,
            True,
            False,
        )

podman_dir = sevenos_share / "profile-rootfs-podman"
if podman_dir.exists() and not fast:
    podman_bytes = bytes_of(podman_dir)
    if podman_bytes > 5 * 1024**3:
        plan_item(
            "profile-rootfs-podman",
            "Review mini OS container storage",
            "Podman storage can grow with build layers and temporary containers. Prune only after confirming no active Forge/Pulse/Studio workload needs them.",
            podman_dir,
            "du -sh ~/.local/share/sevenos/profile-rootfs-podman && podman system df",
            "medium",
            podman_bytes,
            True,
            False,
        )

vm_dir = sevenos_share / "vm"
if vm_dir.exists() and not fast:
    vm_bytes = bytes_of(vm_dir)
    if vm_bytes > 10 * 1024**3:
        plan_item(
            "sevenos-vm-images",
            "Review SevenOS VM images",
            "VM disks are user-visible system assets. Compact, move to external storage or delete only from the VM manager.",
            vm_dir,
            "du -h -d 2 ~/.local/share/sevenos/vm | sort -hr | head -n 40",
            "high",
            vm_bytes,
            True,
            False,
        )

profile_containers = sevenos_share / "profile-containers"
if profile_containers.exists() and not fast:
    containers_bytes = bytes_of(profile_containers)
    if containers_bytes > 2 * 1024**3:
        plan_item(
            "profile-containers",
            "Review legacy profile containers",
            "Profile container folders may include older compatibility state. Keep them unless the matching mini OS route confirms they are unused.",
            profile_containers,
            "du -h -d 2 ~/.local/share/sevenos/profile-containers | sort -hr | head -n 40",
            "medium",
            containers_bytes,
            True,
            False,
        )

attention = sum(1 for item in checks if item["state"] == "ATTENTION")
missing = sum(1 for item in checks if item["state"] == "MISS")
state = "needs-trim" if attention else "needs-source-iso" if missing else "ready"
score = max(0, 100 - attention * 12 - missing * 8)

payload = {
    "schema": "sevenos.footprint-audit.v1",
    "state": state,
    "score": score,
    "generated_at": int(time.time()),
    "fast": fast,
    "root": str(root),
    "runtime_root": str(opt),
    "summary": {
        "repo": human(repo_bytes),
        "repo_bytes": repo_bytes,
        "opt": human(opt_bytes),
        "opt_bytes": opt_bytes,
        "sevenos_share": human(sevenos_share_bytes),
        "sevenos_share_bytes": sevenos_share_bytes,
        "sevenbus": human(events_bytes),
        "sevenbus_bytes": events_bytes,
        "rootfs_duplication": {
            "duplicated_packages": duplicated_packages,
            "ready_rootfs": ready_rootfs,
            "mini_os": mini_os_count,
            "state": package_footprint.get("state", "unknown") if isinstance(package_footprint, dict) else "unknown",
        },
        "source_iso": src_iso,
        "installed_iso": installed_iso,
        "git": {
            "state": git["state"],
            "dirty_count": git["dirty_count"],
            "branch": git["branch"],
            "commit": git["commit"],
        },
    },
    "top": {
        "repo": [] if fast else top_dirs(root, depth=1),
        "repo_nested": [] if fast else top_dirs(root, depth=2),
        "opt": [] if fast else top_dirs(opt, depth=1),
        "home_cache": [] if fast else top_dirs(home_cache, depth=1, limit=8),
        "sevenos_share": [] if fast else top_dirs(sevenos_share, depth=1, limit=12),
        "sevenos_share_nested": [] if fast else top_dirs(sevenos_share, depth=2, limit=16),
    },
    "package_footprint": package_footprint,
    "checks": checks,
    "recommendations": recommendations,
    "cleanup_plan": cleanup_plan,
    "cleanup_summary": {
        "items": len(cleanup_plan),
        "reviewable_footprint": human(sum(item["reclaim_bytes"] for item in cleanup_plan)),
        "safe_reclaim_candidate": human(sum(item["reclaim_bytes"] for item in cleanup_plan if item.get("reclaimable"))),
        "automatic_cleanup": False,
        "policy": "plan-only; commands are shown for review and require explicit user action; rootfs, VM images and profile state are audit targets, not automatic cleanup targets",
    },
    "commands": {
        "json": "seven footprint --json",
        "plan": "seven footprint plan --json",
        "record": "seven footprint record --json",
        "evidence": "seven footprint record --json",
        "compare": "seven footprint compare --json",
        "trend": "seven footprint trend --json",
        "guard": "seven footprint guard --json",
        "compact_bus": "seven core compact-bus --keep 5000 --json",
        "package_footprint": "seven core packages-footprint --json",
    },
    "evidence": {
        "git": git,
        "record_command": "seven footprint record --json",
        "latest_path": str(root / "out/footprint/latest.json"),
    },
    "policy": "read-only audit; no cache, ISO, package or user data is removed automatically",
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
}

latest_evidence_file() {
  find "$ROOT_DIR/out/footprint" -maxdepth 1 -type f -name 'footprint-*.json' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | awk 'NR==1 {sub(/^[^ ]+ /,""); print}'
}

compare_json() {
  local baseline current baseline_path
  baseline_path="$(latest_evidence_file || true)"
  current="$(collect_json)"
  if [[ -z "$baseline_path" || ! -f "$baseline_path" ]]; then
    CURRENT="$current" python - <<'PY'
import json, os, time
current = json.loads(os.environ.get("CURRENT", "{}"))
print(json.dumps({
    "schema": "sevenos.footprint-compare.v1",
    "state": "needs-baseline",
    "score": 0,
    "generated_at": int(time.time()),
    "baseline": {"state": "MISS", "path": ""},
    "current": {
        "state": current.get("state", "unknown"),
        "score": current.get("score", 0),
        "summary": current.get("summary", {}),
    },
    "deltas": {},
    "recommendations": [{
        "title": "Record a footprint baseline",
        "detail": "Run seven footprint evidence --json once before comparing optimizations.",
        "command": "seven footprint evidence --json",
        "risk": "low",
    }],
    "policy": "read-only comparison; no cache, ISO, package or user data is removed automatically",
}, ensure_ascii=False, indent=2))
PY
    return 0
  fi
  baseline="$(cat "$baseline_path")"
  BASELINE="$baseline" CURRENT="$current" BASELINE_PATH="$baseline_path" python - <<'PY'
import json
import os
import time

baseline = json.loads(os.environ.get("BASELINE", "{}"))
current = json.loads(os.environ.get("CURRENT", "{}"))
baseline_path = os.environ.get("BASELINE_PATH", "")

def human(size: int) -> str:
    sign = "-" if size < 0 else "+" if size > 0 else ""
    value = abs(float(size))
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    for unit in units:
        if value < 1024 or unit == units[-1]:
            body = f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
            return f"{sign}{body}" if sign else body
        value /= 1024
    return f"{size} B"

def nested(data, *keys, default=0):
    item = data
    for key in keys:
        if not isinstance(item, dict):
            return default
        item = item.get(key)
    return item if item is not None else default

def plan_reclaim(data: dict) -> int:
    items = data.get("cleanup_plan", [])
    if not isinstance(items, list):
        return 0
    total = 0
    for item in items:
        if isinstance(item, dict):
            if not item.get("reclaimable", True):
                continue
            try:
                total += int(item.get("reclaim_bytes") or 0)
            except Exception:
                pass
    return total

fields = {
    "repo": ("summary", "repo_bytes"),
    "runtime": ("summary", "opt_bytes"),
    "sevenbus": ("summary", "sevenbus_bytes"),
    "cleanup_reclaim": None,
}
thresholds = {
    "repo": 100 * 1024**2,
    "runtime": 100 * 1024**2,
    "sevenbus": 5 * 1024**2,
    "cleanup_reclaim": 100 * 1024**2,
}
deltas = {}
for key, path in fields.items():
    if path is None:
        before = plan_reclaim(baseline)
        after = plan_reclaim(current)
    else:
        before = int(nested(baseline, *path, default=0) or 0)
        after = int(nested(current, *path, default=0) or 0)
    delta = after - before
    threshold = thresholds.get(key, 0)
    if abs(delta) < threshold:
        direction = "unchanged"
    else:
        direction = "improved" if delta < 0 else "regressed" if delta > 0 else "unchanged"
    deltas[key] = {
        "before_bytes": before,
        "after_bytes": after,
        "delta_bytes": delta,
        "delta": human(delta),
        "noise_threshold_bytes": threshold,
        "direction": direction,
    }

before_dirty = int(nested(baseline, "summary", "git", "dirty_count", default=0) or 0)
after_dirty = int(nested(current, "summary", "git", "dirty_count", default=0) or 0)
dirty_delta = after_dirty - before_dirty
deltas["git_dirty"] = {
    "before": before_dirty,
    "after": after_dirty,
    "delta": dirty_delta,
    "direction": "improved" if dirty_delta < 0 else "regressed" if dirty_delta > 0 else "unchanged",
}

score_delta = int(current.get("score", 0) or 0) - int(baseline.get("score", 0) or 0)
deltas["score"] = {
    "before": int(baseline.get("score", 0) or 0),
    "after": int(current.get("score", 0) or 0),
    "delta": score_delta,
    "direction": "improved" if score_delta > 0 else "regressed" if score_delta < 0 else "unchanged",
}

regressions = []
improvements = []
for key, value in deltas.items():
    direction = value.get("direction")
    if direction == "regressed":
        regressions.append(key)
    elif direction == "improved":
        improvements.append(key)

state = "unchanged"
if regressions and not improvements:
    state = "regressed"
elif improvements and not regressions:
    state = "improved"
elif improvements and regressions:
    state = "mixed"

recommendations = []
if state == "improved":
    recommendations.append({
        "title": "Record the improved footprint",
        "detail": "This comparison shows an improvement. Keep an evidence snapshot before the next cleanup.",
        "command": "seven footprint evidence --json",
        "risk": "low",
    })
elif state == "regressed":
    recommendations.append({
        "title": "Inspect new weight before release freeze",
        "detail": "The current footprint grew compared with the latest evidence.",
        "command": "seven footprint plan",
        "risk": "low",
    })
else:
    recommendations.append({
        "title": "Use the cleanup plan for the next measurable change",
        "detail": "The footprint is stable. Review the plan, apply only confirmed cleanups, then compare again.",
        "command": "seven footprint plan",
        "risk": "low",
    })

payload = {
    "schema": "sevenos.footprint-compare.v1",
    "state": state,
    "score": max(0, min(100, 80 + len(improvements) * 5 - len(regressions) * 8)),
    "generated_at": int(time.time()),
    "baseline": {
        "state": baseline.get("state", "unknown"),
        "score": baseline.get("score", 0),
        "path": baseline_path,
        "recorded_at": nested(baseline, "evidence", "recorded_at", default=baseline.get("generated_at")),
        "summary": baseline.get("summary", {}),
    },
    "current": {
        "state": current.get("state", "unknown"),
        "score": current.get("score", 0),
        "summary": current.get("summary", {}),
    },
    "deltas": deltas,
    "summary": {
        "state": state,
        "repo_delta": deltas["repo"]["delta"],
        "runtime_delta": deltas["runtime"]["delta"],
        "sevenbus_delta": deltas["sevenbus"]["delta"],
        "git_dirty_delta": dirty_delta,
        "score_delta": score_delta,
        "improvements": improvements,
        "regressions": regressions,
    },
    "recommendations": recommendations,
    "policy": "read-only comparison; no cache, ISO, package or user data is removed automatically",
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
}

trend_json() {
  ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
import time
from pathlib import Path

root = Path(os.environ["ROOT_DIR"]).resolve()
files = sorted((root / "out/footprint").glob("footprint-*.json"), key=lambda p: p.stat().st_mtime if p.exists() else 0)

def human(size: int) -> str:
    sign = "-" if size < 0 else "+" if size > 0 else ""
    value = abs(float(size))
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    for unit in units:
        if value < 1024 or unit == units[-1]:
            body = f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
            return f"{sign}{body}" if sign else body
        value /= 1024
    return f"{size} B"

def load(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        data["_path"] = str(path)
        data["_mtime"] = int(path.stat().st_mtime)
        return data
    except Exception:
        return {"_path": str(path), "_mtime": 0, "state": "invalid", "score": 0, "summary": {}}

items = [load(path) for path in files]
if not items:
    print(json.dumps({
        "schema": "sevenos.footprint-trend.v1",
        "state": "needs-evidence",
        "score": 0,
        "generated_at": int(time.time()),
        "samples": 0,
        "timeline": [],
        "summary": {},
        "recommendations": [{
            "title": "Record the first footprint evidence",
            "detail": "Trend needs at least one evidence snapshot.",
            "command": "seven footprint evidence --json",
            "risk": "low",
        }],
        "policy": "read-only trend; no cache, ISO, package or user data is removed automatically",
    }, ensure_ascii=False, indent=2))
    raise SystemExit(0)

def summary_value(item: dict, key: str) -> int:
    summary = item.get("summary") if isinstance(item.get("summary"), dict) else {}
    try:
        return int(summary.get(key) or 0)
    except Exception:
        return 0

def dirty_count(item: dict) -> int:
    summary = item.get("summary") if isinstance(item.get("summary"), dict) else {}
    git = summary.get("git") if isinstance(summary.get("git"), dict) else {}
    try:
        return int(git.get("dirty_count") or 0)
    except Exception:
        return 0

first = items[0]
last = items[-1]
repo_delta = summary_value(last, "repo_bytes") - summary_value(first, "repo_bytes")
opt_delta = summary_value(last, "opt_bytes") - summary_value(first, "opt_bytes")
bus_delta = summary_value(last, "sevenbus_bytes") - summary_value(first, "sevenbus_bytes")
dirty_delta = dirty_count(last) - dirty_count(first)
score_delta = int(last.get("score", 0) or 0) - int(first.get("score", 0) or 0)

thresholds = {"repo": 100 * 1024**2, "runtime": 100 * 1024**2, "sevenbus": 5 * 1024**2}
regressions = []
improvements = []
for key, delta in (("repo", repo_delta), ("runtime", opt_delta), ("sevenbus", bus_delta)):
    if abs(delta) < thresholds[key]:
        continue
    (improvements if delta < 0 else regressions).append(key)
if dirty_delta < 0 or score_delta > 0:
    improvements.append("release_state")
elif dirty_delta > 0 or score_delta < 0:
    regressions.append("release_state")

state = "stable"
if len(items) < 2:
    state = "single-sample"
elif regressions and not improvements:
    state = "regressing"
elif improvements and not regressions:
    state = "improving"
elif improvements and regressions:
    state = "mixed"

timeline = []
for item in items[-12:]:
    summary = item.get("summary") if isinstance(item.get("summary"), dict) else {}
    timeline.append({
        "path": item.get("_path", ""),
        "recorded_at": (item.get("evidence") or {}).get("recorded_at") if isinstance(item.get("evidence"), dict) else item.get("generated_at"),
        "state": item.get("state", "unknown"),
        "score": item.get("score", 0),
        "repo": summary.get("repo", "unknown"),
        "repo_bytes": summary.get("repo_bytes", 0),
        "runtime": summary.get("opt", "unknown"),
        "runtime_bytes": summary.get("opt_bytes", 0),
        "sevenbus": summary.get("sevenbus", "unknown"),
        "sevenbus_bytes": summary.get("sevenbus_bytes", 0),
        "dirty_count": dirty_count(item),
    })

recommendations = []
if state == "single-sample":
    recommendations.append({
        "title": "Record one more evidence after a real change",
        "detail": "A trend becomes useful after at least two snapshots.",
        "command": "seven footprint evidence --json",
        "risk": "low",
    })
elif state == "regressing":
    recommendations.append({
        "title": "Inspect the footprint plan before the next freeze",
        "detail": "The trend shows growth or a worse release state.",
        "command": "seven footprint plan",
        "risk": "low",
    })
else:
    recommendations.append({
        "title": "Keep recording evidence after large changes",
        "detail": "The current trend is stable enough to use as release evidence.",
        "command": "seven footprint evidence --json",
        "risk": "low",
    })

print(json.dumps({
    "schema": "sevenos.footprint-trend.v1",
    "state": state,
    "score": max(0, min(100, 80 + len(improvements) * 5 - len(regressions) * 8)),
    "generated_at": int(time.time()),
    "samples": len(items),
    "first": timeline[0] if timeline else {},
    "last": timeline[-1] if timeline else {},
    "timeline": timeline,
    "summary": {
        "repo_delta": human(repo_delta),
        "repo_delta_bytes": repo_delta,
        "runtime_delta": human(opt_delta),
        "runtime_delta_bytes": opt_delta,
        "sevenbus_delta": human(bus_delta),
        "sevenbus_delta_bytes": bus_delta,
        "git_dirty_delta": dirty_delta,
        "score_delta": score_delta,
        "improvements": improvements,
        "regressions": regressions,
    },
    "recommendations": recommendations,
    "policy": "read-only trend; no cache, ISO, package or user data is removed automatically",
}, ensure_ascii=False, indent=2))
PY
}

guard_json() {
  local compare
  compare="$(compare_json)"
  COMPARE="$compare" python - <<'PY'
import json
import os
import time

compare = json.loads(os.environ.get("COMPARE", "{}"))
state = str(compare.get("state", "unknown"))
summary = compare.get("summary") if isinstance(compare.get("summary"), dict) else {}
current = compare.get("current") if isinstance(compare.get("current"), dict) else {}
current_state = str(current.get("state", "unknown"))
recommendations = []

decision = "pass"
score = 100
reasons = []
if state == "needs-baseline":
    decision = "warn"
    score = 70
    reasons.append("No footprint evidence baseline exists yet.")
    recommendations.append({
        "title": "Record a baseline",
        "detail": "A footprint guard is strongest after one recorded evidence snapshot.",
        "command": "seven footprint evidence --json",
        "risk": "low",
    })
elif state in {"regressed", "mixed"}:
    decision = "block"
    score = 40 if state == "regressed" else 55
    reasons.append("The live footprint regressed compared with the latest evidence.")
    recommendations.append({
        "title": "Inspect footprint plan",
        "detail": "Review large directories and release state before freezing.",
        "command": "seven footprint plan",
        "risk": "low",
    })
elif current_state == "needs-trim":
    decision = "warn"
    score = 82
    reasons.append("Footprint is stable but still above the preferred trim threshold.")
    recommendations.append({
        "title": "Keep trim plan visible",
        "detail": "This is not a regression, but size should stay visible before public ISO work.",
        "command": "seven footprint plan",
        "risk": "low",
    })
else:
    reasons.append("Footprint is stable or improved compared with the latest evidence.")
    recommendations.append({
        "title": "Continue with evidence-based changes",
        "detail": "Record another evidence snapshot after the next meaningful optimization.",
        "command": "seven footprint evidence --json",
        "risk": "low",
    })

print(json.dumps({
    "schema": "sevenos.footprint-guard.v1",
    "state": decision,
    "score": score,
    "generated_at": int(time.time()),
    "compare_state": state,
    "current_state": current_state,
    "summary": {
        "repo_delta": summary.get("repo_delta", "unknown"),
        "runtime_delta": summary.get("runtime_delta", "unknown"),
        "sevenbus_delta": summary.get("sevenbus_delta", "unknown"),
        "git_dirty_delta": summary.get("git_dirty_delta", "unknown"),
        "score_delta": summary.get("score_delta", "unknown"),
    },
    "reasons": reasons,
    "recommendations": recommendations,
    "compare": compare,
    "policy": "read-only guard; no cache, ISO, package or user data is removed automatically",
}, ensure_ascii=False, indent=2))
PY
}

case "$ACTION" in
  cleanup)
    payload="$(cleanup_json)"
    if [[ "$JSON" == 1 ]]; then
      printf '%s\n' "$payload"
    else
      printf 'SevenOS Footprint Cleanup\n'
      printf '=========================\n'
      PAYLOAD="$payload" python - <<'PY'
import json, os
data = json.loads(os.environ.get("PAYLOAD", "{}"))
print(f"State: {data.get('state', 'unknown')}")
print(f"Reclaimed: {data.get('reclaimed', '0 B')}")
print(f"Free: {data.get('free_before', 'unknown')} -> {data.get('free_after', 'unknown')}")
for item in data.get("items", []):
    state = item.get("state", "unknown")
    reclaimed = item.get("reclaimed_bytes", 0)
    print(f"- {state}: {item.get('path')} ({reclaimed} bytes)")
if data.get("blocked"):
    print("")
    print("Admin cleanup still needed:")
    print(data.get("admin_command"))
PY
    fi
    ;;
  status|json|plan)
    payload="$(collect_json)"
    if [[ "$JSON" == 1 || "$ACTION" == "json" ]]; then
      if [[ "$ACTION" == "plan" ]]; then
        PAYLOAD="$payload" python - <<'PY'
import json, os
data = json.loads(os.environ.get("PAYLOAD", "{}"))
print(json.dumps({
    "schema": "sevenos.footprint-plan.v1",
    "state": data.get("state", "unknown"),
    "score": data.get("score", 0),
    "summary": data.get("summary", {}),
    "cleanup_summary": data.get("cleanup_summary", {}),
    "cleanup_plan": data.get("cleanup_plan", []),
    "policy": data.get("policy", ""),
}, ensure_ascii=False, indent=2))
PY
      else
        printf '%s\n' "$payload"
      fi
    else
      if [[ "$ACTION" == "plan" ]]; then
        printf 'SevenOS Footprint Plan\n'
        printf '======================\n'
      else
        printf 'SevenOS Footprint Audit\n'
        printf '=======================\n'
      fi
      ACTION="$ACTION" PAYLOAD="$payload" python - <<'PY'
import json, sys
import os
data = json.loads(os.environ.get("PAYLOAD", "{}"))
print(f"State: {data.get('state', 'unknown')}")
print(f"Score: {data.get('score', 0)}%")
summary = data.get("summary", {})
print(f"Source repo: {summary.get('repo', 'unknown')}")
print(f"/opt/SevenOS: {summary.get('opt', 'unknown')}")
print(f"SevenOS local state: {summary.get('sevenos_share', 'unknown')}")
print(f"SevenBus: {summary.get('sevenbus', 'unknown')}")
rootfs = summary.get("rootfs_duplication", {})
if rootfs:
    print(f"Rootfs duplication: {rootfs.get('duplicated_packages', 0)} package name(s) · {rootfs.get('ready_rootfs', 0)}/{rootfs.get('mini_os', 0)} ready")
git = summary.get("git", {})
if git:
    print(f"Git: {git.get('state', 'unknown')} · {git.get('dirty_count', 0)} path(s) · {git.get('branch', 'unknown')}@{git.get('commit', 'unknown')}")
for item in data.get("checks", []):
    print(f"- {item.get('state')}: {item.get('title')} — {item.get('detail')}")
if os.environ.get("ACTION") == "plan":
    cleanup = data.get("cleanup_summary", {})
    print("")
    print(f"Footprint under review: {cleanup.get('reviewable_footprint', 'unknown')}")
    print(f"Safe reclaim candidate: {cleanup.get('safe_reclaim_candidate', 'unknown')}")
    print("Automatic cleanup: no")
    for item in data.get("cleanup_plan", []):
        if item.get("reclaimable"):
            confirm = "requires confirmation" if item.get("requires_confirmation") else "review only"
        else:
            confirm = "audit only"
        print(f"- {item.get('title')} — {item.get('reclaim')} · {confirm}")
        print(f"  {item.get('command')}")
PY
    fi
    ;;
  compare)
    payload="$(compare_json)"
    if [[ "$JSON" == 1 ]]; then
      printf '%s\n' "$payload"
    else
      printf 'SevenOS Footprint Compare\n'
      printf '=========================\n'
      PAYLOAD="$payload" python - <<'PY'
import json, os
data = json.loads(os.environ.get("PAYLOAD", "{}"))
print(f"State: {data.get('state', 'unknown')}")
print(f"Score: {data.get('score', 0)}%")
baseline = data.get("baseline", {})
if baseline.get("path"):
    print(f"Baseline: {baseline.get('path')}")
else:
    print("Baseline: missing")
current = data.get("current", {})
print(f"Current: {current.get('state', 'unknown')} · score {current.get('score', 0)}%")
summary = data.get("summary", {})
if summary:
    print(f"Repo delta: {summary.get('repo_delta', 'unknown')}")
    print(f"/opt delta: {summary.get('runtime_delta', 'unknown')}")
    print(f"SevenBus delta: {summary.get('sevenbus_delta', 'unknown')}")
    print(f"Git dirty delta: {summary.get('git_dirty_delta', 'unknown')}")
    print(f"Score delta: {summary.get('score_delta', 'unknown')}")
for item in data.get("recommendations", []):
    print(f"- {item.get('title')}: {item.get('detail')}")
    if item.get("command"):
        print(f"  {item.get('command')}")
PY
    fi
    ;;
  trend)
    payload="$(trend_json)"
    if [[ "$JSON" == 1 ]]; then
      printf '%s\n' "$payload"
    else
      printf 'SevenOS Footprint Trend\n'
      printf '=======================\n'
      PAYLOAD="$payload" python - <<'PY'
import json, os
data = json.loads(os.environ.get("PAYLOAD", "{}"))
print(f"State: {data.get('state', 'unknown')}")
print(f"Score: {data.get('score', 0)}%")
print(f"Samples: {data.get('samples', 0)}")
summary = data.get("summary", {})
if summary:
    print(f"Repo trend: {summary.get('repo_delta', 'unknown')}")
    print(f"/opt trend: {summary.get('runtime_delta', 'unknown')}")
    print(f"SevenBus trend: {summary.get('sevenbus_delta', 'unknown')}")
    print(f"Git dirty trend: {summary.get('git_dirty_delta', 'unknown')}")
    print(f"Score trend: {summary.get('score_delta', 'unknown')}")
for item in data.get("recommendations", []):
    print(f"- {item.get('title')}: {item.get('detail')}")
    if item.get("command"):
        print(f"  {item.get('command')}")
PY
    fi
    ;;
  guard)
    payload="$(guard_json)"
    if [[ "$JSON" == 1 ]]; then
      printf '%s\n' "$payload"
    else
      printf 'SevenOS Footprint Guard\n'
      printf '=======================\n'
      PAYLOAD="$payload" python - <<'PY'
import json, os
data = json.loads(os.environ.get("PAYLOAD", "{}"))
print(f"State: {data.get('state', 'unknown')}")
print(f"Score: {data.get('score', 0)}%")
print(f"Compare: {data.get('compare_state', 'unknown')}")
print(f"Current: {data.get('current_state', 'unknown')}")
summary = data.get("summary", {})
print(f"Repo delta: {summary.get('repo_delta', 'unknown')}")
print(f"/opt delta: {summary.get('runtime_delta', 'unknown')}")
print(f"SevenBus delta: {summary.get('sevenbus_delta', 'unknown')}")
print(f"Git dirty delta: {summary.get('git_dirty_delta', 'unknown')}")
for reason in data.get("reasons", []):
    print(f"- {reason}")
for item in data.get("recommendations", []):
    print(f"- {item.get('title')}: {item.get('detail')}")
    if item.get("command"):
        print(f"  {item.get('command')}")
PY
    fi
    ;;
  record|evidence)
    mkdir -p "$ROOT_DIR/out/footprint"
    payload="$(collect_json)"
    stamp="$(date +%Y%m%d-%H%M%S)"
    path="$ROOT_DIR/out/footprint/footprint-$stamp.json"
    PAYLOAD="$payload" EVIDENCE_PATH="$path" python - <<'PY' >"$path"
import json, os
data = json.loads(os.environ.get("PAYLOAD", "{}"))
evidence = data.setdefault("evidence", {})
evidence["path"] = os.environ.get("EVIDENCE_PATH", "")
evidence["recorded_at"] = data.get("generated_at")
print(json.dumps(data, ensure_ascii=False, indent=2))
PY
    ln -sfn "$(basename "$path")" "$ROOT_DIR/out/footprint/latest.json"
    if [[ "$JSON" == 1 ]]; then
      cat "$path"
    else
      printf 'SevenOS footprint evidence recorded: %s\n' "$path"
    fi
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
