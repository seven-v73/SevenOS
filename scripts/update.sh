#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS update

Usage:
  seven update [status|check|plan|doctor|apply|install|rollback|json] [--json] [--yes] [--dry-run]
  ./scripts/update.sh [status|check|plan|doctor|apply|install|rollback|json] [--json] [--yes] [--dry-run]

This is the SevenOS-first update route. It updates the SevenOS system tree,
refreshes command wrappers and then delegates package updates to pacman,
Flatpak or AUR helpers.
EOF
}

ACTION="status"
JSON_OUTPUT=0
YES=0
REFRESH_CACHE="${SEVENOS_UPDATE_REFRESH:-0}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
UPDATE_CACHE="$CACHE_DIR/update.json"
UPDATE_CACHE_TTL="${SEVENOS_UPDATE_CACHE_TTL:-300}"
for arg in "$@"; do
  case "$arg" in
    status|check|plan|doctor|apply|install|rollback|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    --refresh|--no-cache) REFRESH_CACHE=1 ;;
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown update option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1
[[ "$ACTION" == "check" ]] && ACTION="doctor"
[[ "$ACTION" == "install" ]] && ACTION="apply"

git_run() {
  if [[ -w "$ROOT_DIR/.git" || -w "$ROOT_DIR" ]]; then
    run_cmd git -C "$ROOT_DIR" "$@"
  else
    run_privileged_cmd git -C "$ROOT_DIR" "$@"
  fi
}

UPDATE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/update"
LAST_SNAPSHOT_LINK="$UPDATE_STATE_DIR/last-successful-tree"
LAST_REPORT_FILE="$UPDATE_STATE_DIR/last-report.json"

json_cache_valid() {
  [[ -s "$1" ]] || return 1
  python -m json.tool "$1" >/dev/null 2>&1
}

cache_is_fresh() {
  local path="$1"
  local ttl="$2"
  local now mtime
  [[ "$REFRESH_CACHE" == 1 ]] && return 1
  json_cache_valid "$path" || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || printf 0)"
  (( now - mtime < ttl ))
}

write_json_cache() {
  local path="$1"
  local tmp
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.XXXXXX")"
  cat >"$tmp"
  if json_cache_valid "$tmp"; then
    mv -f "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
}

clear_update_cache() {
  rm -f "$UPDATE_CACHE" 2>/dev/null || true
}

snapshot_excludes() {
  printf '%s\n' \
    "--exclude=.git" \
    "--exclude=out" \
    "--exclude=work" \
    "--exclude=iso" \
    "--exclude=dist" \
    "--exclude=target" \
    "--exclude=node_modules" \
    "--exclude=archiso/localrepo"
}

create_update_snapshot() {
  local target
  target="$UPDATE_STATE_DIR/snapshots/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$(dirname -- "$target")"
  log_info "Creating SevenOS rollback snapshot: $target"
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$target"
    printf 'rsync -a --delete <excludes> %q/ %q/\n' "$ROOT_DIR" "$target"
    return 0
  fi
  local excludes=()
  mapfile -t excludes < <(snapshot_excludes)
  rsync -a --delete "${excludes[@]}" "$ROOT_DIR"/ "$target"/
  ln -sfn "$target" "$LAST_SNAPSHOT_LINK"
  printf '%s\n' "$target"
}

notify_update() {
  local title="$1"
  local message="$2"
  if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$message" >/dev/null 2>&1 || true
  fi
}

write_update_report() {
  local status="$1"
  local snapshot="${2:-}"
  local message="${3:-}"
  mkdir -p "$UPDATE_STATE_DIR"
  SEVENOS_UPDATE_STATUS="$status" \
  SEVENOS_UPDATE_SNAPSHOT="$snapshot" \
  SEVENOS_UPDATE_MESSAGE="$message" \
  SEVENOS_UPDATE_JSON="$(update_json)" \
  SEVENOS_UPDATE_REPORT="$LAST_REPORT_FILE" \
  python - <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

payload = json.loads(os.environ.get("SEVENOS_UPDATE_JSON", "{}") or "{}")
report = {
    "schema": "sevenos.update-report.v1",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "status": os.environ.get("SEVENOS_UPDATE_STATUS", "unknown"),
    "message": os.environ.get("SEVENOS_UPDATE_MESSAGE", ""),
    "snapshot": os.environ.get("SEVENOS_UPDATE_SNAPSHOT", ""),
    "state": payload.get("state", "unknown"),
    "score": payload.get("score", 0),
    "pending_total": payload.get("pending_total"),
    "rollback": payload.get("rollback") or {},
    "repository": payload.get("repository") or {},
    "commands": payload.get("commands") or {},
}
target = Path(os.environ["SEVENOS_UPDATE_REPORT"])
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(target)
PY
}

restart_user_surfaces() {
  if is_dry_run; then
    printf 'hyprctl reload\n'
    printf 'systemctl --user try-restart sevenos-waybar.service sevenos-notifications.service sevenos-wallpaper.service sevenos-dock.service sevenos-shell-experience.service\n'
    printf 'pkill -x waybar swaync hyprpaper || true; seven-session\n'
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user try-restart \
      sevenos-waybar.service \
      sevenos-notifications.service \
      sevenos-wallpaper.service \
      sevenos-dock.service \
      sevenos-shell-experience.service >/dev/null 2>&1 || true
    systemctl --user start sevenos-session.target >/dev/null 2>&1 || true
  fi
  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
  fi
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    pkill -x waybar >/dev/null 2>&1 || true
    pkill -x swaync >/dev/null 2>&1 || true
    pkill -x hyprpaper >/dev/null 2>&1 || true
    if [[ -x "$ROOT_DIR/bin/seven-session" ]]; then
      "$ROOT_DIR/bin/seven-session" >/tmp/sevenos-session.log 2>&1 || true
    fi
  fi
}

restore_update_snapshot() {
  local snapshot="${1:-}"
  if [[ -z "$snapshot" || ! -d "$snapshot" ]]; then
    log_warn "No valid SevenOS rollback snapshot was found."
    return 1
  fi
  log_warn "Restoring SevenOS from rollback snapshot: $snapshot"
  if is_dry_run; then
    printf 'rsync -a --delete %q/ %q/\n' "$snapshot" "$ROOT_DIR"
    return 0
  fi
  local excludes=()
  mapfile -t excludes < <(snapshot_excludes)
  if [[ -w "$ROOT_DIR" ]]; then
    rsync -a --delete "${excludes[@]}" "$snapshot"/ "$ROOT_DIR"/
  else
    run_privileged_cmd rsync -a --delete "${excludes[@]}" "$snapshot"/ "$ROOT_DIR"/
  fi
  env SEVENOS_ROOT="$ROOT_DIR" "$ROOT_DIR/install.sh" cli || true
}

repo_update_preview() {
  printf 'seven migrate backup\n'
  printf 'git -C %q fetch --prune\n' "$ROOT_DIR"
  printf 'git -C %q pull --ff-only\n' "$ROOT_DIR"
  printf 'env SEVENOS_ROOT=%q %q cli\n' "$ROOT_DIR" "$ROOT_DIR/install.sh"
  printf 'env SEVENOS_ROOT=%q %q post-install\n' "$ROOT_DIR" "$ROOT_DIR/install.sh"
}

apply_repo_update() {
  if [[ ! -d "$ROOT_DIR/.git" ]]; then
    log_warn "SevenOS root is not a Git checkout: $ROOT_DIR"
    log_warn "Repository updates skipped; package updates will continue."
    return 0
  fi

  log_info "Backing up protected SevenOS user state before update..."
  "$ROOT_DIR/scripts/migrate.sh" backup || log_warn "Migration backup failed; continuing cautiously."

  log_info "Updating SevenOS system tree: $ROOT_DIR"
  git_run fetch --prune
  git_run pull --ff-only

  log_info "Refreshing SevenOS public commands and post-update checks..."
  env SEVENOS_ROOT="$ROOT_DIR" "$ROOT_DIR/install.sh" cli
  env SEVENOS_ROOT="$ROOT_DIR" "$ROOT_DIR/install.sh" post-install || true
}

update_json_uncached() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import shutil
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
last_snapshot = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "sevenos/update/last-successful-tree"


def run_lines(command, timeout=8):
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except Exception:
        return None
    if result.returncode not in (0, 1):
        return None
    output = result.stdout.strip()
    return [line for line in output.splitlines() if line.strip()]


def command_ok(command):
    return shutil.which(command) is not None

def git_text(args, timeout=5):
    try:
        result = subprocess.run(["git", "-C", str(root), *args], text=True, capture_output=True, check=False, timeout=timeout)
    except Exception:
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""

fast_mode = os.environ.get("SEVENOS_UPDATE_FAST") == "1"
is_git = (root / ".git").exists()
branch = git_text(["rev-parse", "--abbrev-ref", "HEAD"]) if is_git else ""
commit = git_text(["rev-parse", "--short", "HEAD"]) if is_git else ""
upstream = git_text(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]) if is_git else ""
dirty = len(git_text(["status", "--short"]).splitlines()) if is_git else None
behind = None
ahead = None
if is_git and upstream:
    counts = git_text(["rev-list", "--left-right", "--count", f"HEAD...{upstream}"]).split()
    if len(counts) == 2:
        ahead = int(counts[0])
        behind = int(counts[1])
pacman_updates = run_lines(["pacman", "-Qu"]) if command_ok("pacman") and not fast_mode else None
flatpak_updates = run_lines(["flatpak", "remote-ls", "--updates", "--columns=application,version", "flathub"]) if command_ok("flatpak") and not fast_mode else None
aur_helper = "paru" if command_ok("paru") else "yay" if command_ok("yay") else ""
aur_updates = run_lines([aur_helper, "-Qua"], timeout=10) if aur_helper and not fast_mode else None

sources = [
    {
        "key": "system",
        "public_name": "SevenOS System",
        "backend": "pacman",
        "available": command_ok("pacman"),
        "pending": len(pacman_updates) if isinstance(pacman_updates, list) else None,
        "state": "OK" if command_ok("pacman") else "MISS",
        "command": "seven update apply",
    },
    {
        "key": "apps",
        "public_name": "SevenOS Apps",
        "backend": "Flatpak",
        "available": command_ok("flatpak"),
        "pending": len(flatpak_updates) if isinstance(flatpak_updates, list) else None,
        "state": "OK" if command_ok("flatpak") else "PART",
        "command": "seven flatpak status",
    },
    {
        "key": "community",
        "public_name": "SevenOS Community Apps",
        "backend": aur_helper or "AUR helper",
        "available": bool(aur_helper),
        "pending": len(aur_updates) if isinstance(aur_updates, list) else None,
        "state": "OK" if aur_helper else "PART",
        "command": "./install.sh aur-helpers --yes",
    },
    {
        "key": "profiles",
        "public_name": "Mini OS Bundles",
        "backend": "sevenpkg",
        "available": (root / "bin/sevenpkg").is_file(),
        "pending": None,
        "state": "OK" if (root / "bin/sevenpkg").is_file() else "MISS",
        "command": "sevenpkg status",
    },
]

missing = [item for item in sources if item["state"] == "MISS"]
partial = [item for item in sources if item["state"] == "PART"]
known_pending = [
    item["pending"]
    for item in sources
    if isinstance(item.get("pending"), int)
]
pending_total = sum(known_pending)
repo_pending = isinstance(behind, int) and behind > 0
state = "updates-available" if pending_total > 0 or repo_pending else "ready" if not missing else "partial"
if fast_mode and not missing:
    state = "ready"
score = round((sum(1 for item in sources if item["state"] == "OK") + len(partial) * 0.5) / len(sources) * 100)

print(json.dumps({
    "schema": "sevenos.update.v1",
    "state": state,
    "score": score,
    "pending_total": pending_total,
    "repo_pending": repo_pending,
    "pending_known": len(known_pending) == 3,
    "fast_mode": fast_mode,
    "root": str(root),
    "preferred_root": "/opt/SevenOS",
    "repository": {
        "state": "OK" if is_git and upstream else "PART" if is_git else "MISS",
        "git": is_git,
        "branch": branch,
        "commit": commit,
        "upstream": upstream,
        "ahead": ahead,
        "behind": behind,
        "dirty_count": dirty,
        "public_location": str(root) == "/opt/SevenOS",
        "command": "seven update install --yes",
    },
    "rollback": {
        "available": last_snapshot.exists(),
        "snapshot": str(last_snapshot.resolve()) if last_snapshot.exists() else "",
        "command": "seven update rollback",
    },
    "sources": sources,
    "policy": [
        "SevenOS explains updates before backend commands run.",
        "Public installs should live in /opt/SevenOS so commands work from any directory.",
        "SevenOS updates its own system tree before refreshing wrappers and package sources.",
        "System packages use pacman through the SevenOS route.",
        "Flatpak and AUR are app sources, not the public product identity.",
        "Profile bundles remain visible through sevenpkg and SevenStore.",
    ],
    "plan": [
        {
            "title": "Review update state",
            "command": "seven update check",
            "impact": "safe",
        },
        {
            "title": "Back up protected SevenOS state",
            "command": "seven migrate backup",
            "impact": "safe",
        },
        {
            "title": "Apply SevenOS update route",
            "command": "seven update install --yes",
            "impact": "packages",
        },
        {
            "title": "Rollback the last SevenOS tree snapshot if needed",
            "command": "seven update rollback",
            "impact": "safe",
        },
        {
            "title": "Refresh SevenOS health after updates",
            "command": "seven doctor",
            "impact": "safe",
        },
    ],
    "issues": missing + partial,
    "commands": {
        "status": "seven update",
        "check": "seven update check",
        "json": "seven update --json",
        "apply": "seven update install --yes",
        "rollback": "seven update rollback",
        "store": "seven store",
    },
}, indent=2))
PY
}

update_json() {
  if [[ "$ACTION" != "apply" && "$ACTION" != "rollback" ]] && cache_is_fresh "$UPDATE_CACHE" "$UPDATE_CACHE_TTL"; then
    cat "$UPDATE_CACHE"
    return 0
  fi

  local payload
  payload="$(update_json_uncached)"
  if [[ "$ACTION" != "apply" && "$ACTION" != "rollback" ]]; then
    printf '%s\n' "$payload" | write_json_cache "$UPDATE_CACHE" || true
  fi
  printf '%s\n' "$payload"
}

print_human() {
  UPDATE_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["UPDATE_JSON"])
print("SevenOS Update")
print("==============")
print(f"State:    {data.get('state')}")
print(f"Score:    {data.get('score')}%")
print(f"Pending:  {data.get('pending_total')} known update(s)")
repo = data.get("repository", {})
if repo:
    behind = repo.get("behind")
    pending = "yes" if data.get("repo_pending") else "no" if behind is not None else "unknown"
    print(f"SevenOS:  {repo.get('commit') or 'unknown'} on {repo.get('branch') or 'unknown'} · repo update: {pending}")
    print(f"Root:     {data.get('root')}")
rollback = data.get("rollback") or {}
print(f"Rollback: {'available' if rollback.get('available') else 'not available'} · {rollback.get('command', 'seven update rollback')}")
print()
for item in data.get("sources", []):
    pending = item.get("pending")
    pending_text = "unknown" if pending is None else str(pending)
    print(f"{item.get('state','MISS'):<4} {item.get('public_name')} · {pending_text} pending")
    print(f"     Foundation: {item.get('backend')} · route: {item.get('command')}")
print()
print("Next:")
if data.get("state") == "updates-available":
    print("  seven update plan")
    print("  seven update install --yes")
else:
    print("  seven update check")
print("  seven update rollback   # restore the last SevenOS tree snapshot")
PY
}

print_plan() {
  UPDATE_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["UPDATE_JSON"])
print("SevenOS Update Plan")
print("===================")
for item in data.get("plan", []):
    print(f"- {item.get('title')}: {item.get('command')}")
PY
}

apply_updates() {
  local snapshot=""
  local report_path=""
  clear_update_cache
  log_info "Applying SevenOS update route"
  notify_update "SevenOS Update" "Preparing update route and rollback snapshot."
  if is_dry_run; then
    repo_update_preview
    printf '%q ' "$ROOT_DIR/bin/sevenpkg" update
    printf '\n'
    if command -v flatpak >/dev/null 2>&1; then
      printf 'flatpak update --assumeyes\n'
    fi
    write_update_report "dry-run" "" "Dry-run completed." >/dev/null || true
    return 0
  fi

  snapshot="$(create_update_snapshot | tail -n 1 || true)"
  if ! (
    apply_repo_update
    "$ROOT_DIR/bin/sevenpkg" update
    if command -v flatpak >/dev/null 2>&1; then
      if [[ "$YES" -eq 1 || "${SEVENOS_YES:-0}" == "1" ]]; then
        flatpak update --assumeyes || true
      else
        flatpak update || true
      fi
    fi
    restart_user_surfaces
  ); then
    log_error "SevenOS update failed; attempting rollback."
    restore_update_snapshot "$snapshot" || true
    report_path="$(write_update_report "failed" "$snapshot" "Update failed; rollback was attempted." | tail -n 1 || true)"
    notify_update "SevenOS Update" "Update failed. Rollback was attempted."
    return 1
  fi
  report_path="$(write_update_report "success" "$snapshot" "SevenOS update completed." | tail -n 1 || true)"
  log_success "SevenOS update route completed."
  [[ -n "$report_path" ]] && log_info "Update report: $report_path"
  notify_update "SevenOS Update" "Update completed. SevenOS surfaces were refreshed."
}

rollback_update() {
  local snapshot="${1:-}"
  clear_update_cache
  if [[ -z "$snapshot" && -L "$LAST_SNAPSHOT_LINK" ]]; then
    snapshot="$(readlink -f "$LAST_SNAPSHOT_LINK")"
  fi
  restore_update_snapshot "$snapshot"
}

case "$ACTION" in
  status|json)
    payload="$(update_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  plan)
    payload="$(update_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan "$payload"
    fi
    ;;
  doctor)
    payload="$(update_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    UPDATE_JSON="$payload" python - <<'PY'
import json, os, sys
data = json.loads(os.environ["UPDATE_JSON"])
sys.exit(0 if data.get("score", 0) >= 75 else 1)
PY
    ;;
  apply) apply_updates ;;
  rollback) rollback_update ;;
esac
