#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/sevenos"
EXPERIENCE_DIR="$CONFIG_HOME/sevenos"
EXPERIENCE_STATE="$EXPERIENCE_DIR/shell-experience.json"
EXPERIENCE_EVENTS="$STATE_HOME/sevenos/shell-experience-events.jsonl"
EXPERIENCE_WARMUP_STAMP="$RUNTIME_DIR/shell-experience-warmup.stamp"

usage() {
  cat <<'EOF'
SevenOS Shell Experience

Usage:
  seven experience status [--json]
  seven experience apply
  seven experience doctor
  seven experience launch <label>
  seven experience focus <label>
  seven experience workspace <id>
  seven experience notify <title> [message]
  seven experience warmup
  seven experience events
  seven experience recommend

This is the shared OS-experience layer: motion grammar, feedback,
focus continuity, workspace memory and mini OS behavior hints.
EOF
}

json_escape() {
  if [[ "$#" -gt 0 ]]; then
    python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
  else
    python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
  fi
}

active_profile() {
  local profile_file="$CONFIG_HOME/sevenos/profile.env"
  if [[ -f "$profile_file" ]]; then
    # shellcheck disable=SC1090
    source "$profile_file"
  fi
  printf '%s\n' "${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_PROFILE:-equinox}}"
}

profile_role() {
  case "$1" in
    baobab) printf 'Culture, documents, reading, offline knowledge' ;;
    forge) printf 'Development, Git, containers, build feedback' ;;
    shield) printf 'Security, audit, sandbox, cautious opening' ;;
    studio) printf 'Media, assets, previews, creative flow' ;;
    atlas) printf 'Atlas Explorer, documents, maps, OCR and references' ;;
    pulse) printf 'Games, captures, performance, low-latency focus' ;;
    *) printf 'Balanced SevenOS daily workspace' ;;
  esac
}

profile_motion() {
  "$ROOT_DIR/scripts/motion.sh" status --json 2>/dev/null |
    python -c 'import json,sys; d=json.load(sys.stdin); print(d.get("profile_motion") or "balanced fade")' 2>/dev/null ||
    printf 'balanced fade'
}

workspace_id() {
  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl activeworkspace -j 2>/dev/null |
      python -c 'import json,sys; d=json.load(sys.stdin); print(d.get("name") or d.get("id") or "1")' 2>/dev/null ||
      printf '1'
  else
    printf '1'
  fi
}

surface_state() {
  local path="$1"
  [[ -x "$ROOT_DIR/$path" ]] && printf ready || printf missing
}

write_state() {
  local profile motion workspace now
  profile="$(active_profile)"
  motion="$(profile_motion)"
  workspace="$(workspace_id)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$EXPERIENCE_DIR" "$(dirname "$EXPERIENCE_EVENTS")" "$RUNTIME_DIR"
  cat >"$EXPERIENCE_STATE" <<EOF
{
  "schema": "sevenos.shell-experience.v1",
  "state": "ready",
  "updated_at": "$now",
  "profile": "$profile",
  "profile_role": $(json_escape "$(profile_role "$profile")"),
  "workspace": $(json_escape "$workspace"),
  "motion": {
    "grammar": "seven-motion-system",
    "profile_motion": $(json_escape "$motion"),
    "curves": ["sevenMotion", "sevenMotionOpen", "sevenMotionExit", "sevenMotionWorkspace", "sevenMotionLayer"],
    "durations": {"press": 120, "hover": 160, "open": 260, "close": 180, "workspace": 320},
    "reduced_motion": "seven motion reduced"
  },
  "continuity": {
    "launch_feedback": true,
    "focus_memory": true,
    "workspace_memory": true,
    "dock_launch_contract": true,
    "spotlight_action_contract": true
  },
  "window_policy": {
    "front_door": "seven-window",
    "placement": "center important surfaces, remember workspace state, keep Hyprland hidden behind SevenOS commands",
    "fullscreen": "seven-window fullscreen",
    "float": "seven-window toggle-float",
    "memory": "seven-window memory --json",
    "restore": "seven-window restore"
  },
  "feedback": {
    "notify_command": "seven experience notify",
    "launch_command": "seven experience launch",
    "warmup_command": "seven experience warmup",
    "event_log": "$EXPERIENCE_EVENTS",
    "errors": "actionable SevenOS notifications first, terminal logs second"
  },
  "mini_os": {
    "baobab": ["reader", "documents", "offline collections"],
    "forge": ["terminal", "git", "containers", "logs"],
    "shield": ["sandbox", "hash", "audit", "read-only open"],
    "studio": ["media previews", "assets", "metadata"],
    "atlas": ["documents", "maps", "OCR", "references"],
    "pulse": ["games", "captures", "performance"]
  },
  "surfaces": {
    "dock": "$(surface_state bin/seven-dock-native)",
    "launchpad": "$(surface_state bin/seven-launchpad-native)",
    "spotlight": "$(surface_state bin/seven-spotlight-native)",
    "files": "$(surface_state bin/seven-files-native)",
    "terminal": "$(surface_state bin/seven-terminal-native)",
    "settings": "$(surface_state bin/seven-settings-native)",
    "notifications": "$(surface_state bin/seven-notification-center-native)",
    "quick_settings": "$(surface_state bin/seven-quick-settings-native)"
  },
  "accessibility": {
    "keyboard_first": true,
    "focus_visible": true,
    "reduced_motion_command": "seven motion reduced",
    "discoverable_actions": "seven-actions --json"
  }
}
EOF
}

recent_events_json() {
  if [[ ! -s "$EXPERIENCE_EVENTS" ]]; then
    printf '[]'
    return 0
  fi
  RECENT_EVENT_LINES="$(tail -n 12 "$EXPERIENCE_EVENTS")" python - <<'PY'
import json
import os
import sys

items = []
for raw in os.environ.get("RECENT_EVENT_LINES", "").splitlines():
    try:
        items.append(json.loads(raw))
    except Exception:
        pass
print(json.dumps(items, ensure_ascii=False))
PY
}

recommendation_json() {
  local payload recent waybar_status
  [[ -s "$EXPERIENCE_STATE" ]] || write_state
  payload="$(cat "$EXPERIENCE_STATE")"
  recent="$(recent_events_json)"
  if [[ -x "$ROOT_DIR/bin/seven-waybar" ]]; then
    waybar_status="$("$ROOT_DIR/bin/seven-waybar" status --json 2>/dev/null || printf '{}')"
  else
    waybar_status="{}"
  fi
  SEVENOS_SHELL_EXPERIENCE_JSON="$payload" SEVENOS_SHELL_EXPERIENCE_EVENTS="$recent" SEVENOS_WAYBAR_STATUS_JSON="$waybar_status" python - <<'PY'
import json
import os

data = json.loads(os.environ.get("SEVENOS_SHELL_EXPERIENCE_JSON", "{}"))
events = json.loads(os.environ.get("SEVENOS_SHELL_EXPERIENCE_EVENTS", "[]"))
try:
    waybar = json.loads(os.environ.get("SEVENOS_WAYBAR_STATUS_JSON", "{}"))
except Exception:
    waybar = {}
profile = str(data.get("profile") or "equinox")
surfaces = data.get("surfaces", {}) if isinstance(data.get("surfaces"), dict) else {}
missing = [name for name, state in surfaces.items() if state != "ready"]
last = events[-1] if events else {}

profile_actions = {
    "baobab": ("Open Reader", "seven-reader", "Continue reading, documents and offline collections."),
    "forge": ("Open Forge Terminal", "seven-terminal forge", "Jump into Git, builds and project logs."),
    "shield": ("Open Shield Center", "seven-shield-center-native", "Review scope, audit state and safe-open paths."),
    "studio": ("Open Studio Assets", "seven-files pictures", "Resume media, assets and creative previews."),
    "atlas": ("Open Atlas Explorer", "seven atlas status", "Check documents, maps, OCR and reference readiness."),
    "pulse": ("Open Pulse Captures", "seven-files videos", "Review captures, games and performance context."),
    "equinox": ("Open Spotlight", "seven-spotlight field", "Search apps, actions, files and windows."),
}

if waybar and waybar.get("state") != "OK":
    title, command, reason = ("Repair Waybar", "seven-waybar repair", "The menu bar context or runtime needs attention.")
elif missing:
    title, command, reason = ("Repair Shell Surface", "seven surfaces doctor", f"Surface needs attention: {missing[0]}.")
elif last.get("kind") == "launch":
    title, command, reason = ("Show Windows", "seven-overview windows", "A launch just happened; jump to active windows if focus was lost.")
elif last.get("kind") == "workspace":
    title, command, reason = ("Open Spotlight", "seven-spotlight field", "Workspace changed; Spotlight is the fastest next action.")
elif last.get("kind") == "warmup":
    title, command, reason = profile_actions.get(profile, profile_actions["equinox"])
else:
    title, command, reason = profile_actions.get(profile, profile_actions["equinox"])

print(json.dumps({
    "schema": "sevenos.shell-experience.recommendation.v1",
    "profile": profile,
    "title": title,
    "command": command,
    "reason": reason,
    "last_event": last,
    "missing_surfaces": missing,
}, ensure_ascii=False, indent=2))
PY
}

status_json() {
  [[ -s "$EXPERIENCE_STATE" ]] || write_state
  RECENT_EVENTS="$(recent_events_json)" RECOMMENDATION="$(recommendation_json)" python - "$EXPERIENCE_STATE" <<'PY'
import json
import os
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
try:
    data["recent_events"] = json.loads(os.environ.get("RECENT_EVENTS", "[]"))
except Exception:
    data["recent_events"] = []
try:
    data["recommendation"] = json.loads(os.environ.get("RECOMMENDATION", "{}"))
except Exception:
    data["recommendation"] = {}
print(json.dumps(data, ensure_ascii=False, indent=2))
PY
}

score_json() {
  local payload
  payload="$(status_json)"
  SEVENOS_SHELL_EXPERIENCE_JSON="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ.get("SEVENOS_SHELL_EXPERIENCE_JSON", "{}"))
surfaces = data.get("surfaces", {})
ready = sum(1 for value in surfaces.values() if value == "ready")
total = max(len(surfaces), 1)
checks = [
    ("motion", data.get("motion", {}).get("grammar") == "seven-motion-system"),
    ("continuity", bool(data.get("continuity", {}).get("launch_feedback"))),
    ("window_policy", data.get("window_policy", {}).get("front_door") == "seven-window"),
    ("feedback", data.get("feedback", {}).get("notify_command") == "seven experience notify"),
    ("mini_os", len(data.get("mini_os", {})) >= 6),
    ("recommendation", data.get("recommendation", {}).get("schema") == "sevenos.shell-experience.recommendation.v1"),
    ("surfaces", ready >= max(6, total - 1)),
    ("accessibility", bool(data.get("accessibility", {}).get("keyboard_first"))),
]
score = round(sum(1 for _, ok in checks if ok) * 100 / len(checks))
print(json.dumps({
    "schema": "sevenos.shell-experience.score.v1",
    "state": "ready" if score >= 90 else "partial",
    "score": score,
    "checks": [{"id": key, "state": "OK" if ok else "PART"} for key, ok in checks],
    "surface_ready": ready,
    "surface_total": total,
}, indent=2))
PY
}

notify_user() {
  local title="$1"
  local message="${2:-}"
  if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY-RUN > Experience > Notify > %s > %s\n' "$title" "$message"
    return 0
  fi
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    notify-send -a "SevenOS" -h string:x-canonical-private-synchronous:sevenos-experience -t 1200 "$title" "$message" >/dev/null 2>&1 || true
  fi
}

event_log() {
  local kind="$1"
  local label="$2"
  local detail="${3:-}"
  mkdir -p "$(dirname "$EXPERIENCE_EVENTS")"
  {
    printf '{"time":%s,' "$(json_escape "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
    printf '"kind":%s,' "$(json_escape "$kind")"
    printf '"profile":%s,' "$(json_escape "$(active_profile)")"
    printf '"workspace":%s,' "$(json_escape "$(workspace_id)")"
    printf '"label":%s,' "$(json_escape "$label")"
    printf '"detail":%s}\n' "$(json_escape "$detail")"
  } >>"$EXPERIENCE_EVENTS"
}

launch_feedback() {
  local label="${1:-Application}"
  if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY-RUN > Experience > Launch > %s\n' "$label"
    return 0
  fi
  event_log launch "$label" "opening"
  notify_user "Opening $label" "$(active_profile) · $(profile_motion)"
}

focus_feedback() {
  local label="${1:-Window}"
  if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY-RUN > Experience > Focus > %s\n' "$label"
    return 0
  fi
  event_log focus "$label" "active"
}

workspace_feedback() {
  local id="${1:-$(workspace_id)}"
  if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY-RUN > Experience > Workspace > %s\n' "$id"
    return 0
  fi
  event_log workspace "$id" "switched"
  write_state
}

apply_experience() {
  if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY-RUN > Experience > Apply shell-experience contract\n'
    return 0
  fi
  "$ROOT_DIR/scripts/motion.sh" profile "$(active_profile)" >/dev/null 2>&1 || true
  write_state
  notify_user "SevenOS Experience" "Motion, focus, feedback and mini OS continuity are synchronized."
  log_success "SevenOS Shell Experience applied"
}

warmup_experience() {
  if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY-RUN > Experience > Warmup Spotlight, apps, motion and state caches\n'
    return 0
  fi
  mkdir -p "$RUNTIME_DIR"
  prewarm_waybar_status() {
    local module
    for module in sevenos profile mini-context experience control-center system-status wifi bluetooth; do
      if command -v timeout >/dev/null 2>&1; then
        timeout 3 "$ROOT_DIR/bin/seven-waybar-status" "$module" >/dev/null 2>&1 || true
      else
        "$ROOT_DIR/bin/seven-waybar-status" "$module" >/dev/null 2>&1 || true
      fi
    done
  }
  if [[ -f "$EXPERIENCE_WARMUP_STAMP" ]] &&
     [[ $(( $(date +%s) - $(stat -c %Y "$EXPERIENCE_WARMUP_STAMP" 2>/dev/null || printf 0) )) -lt 45 ]]; then
    prewarm_waybar_status
    write_state >/dev/null 2>&1 || true
    return 0
  fi
  : >"$EXPERIENCE_WARMUP_STAMP"
  event_log warmup "SevenOS Shell" "cache refresh"
  {
    run_warmup() {
      if command -v timeout >/dev/null 2>&1; then
        timeout "${1:-5}" "${@:2}" >/dev/null 2>&1 || true
      else
        "${@:2}" >/dev/null 2>&1 || true
      fi
    }
    if command -v ionice >/dev/null 2>&1; then
      renice 10 "$$" >/dev/null 2>&1 || true
      ionice -c 3 -p "$$" >/dev/null 2>&1 || true
    fi
    run_warmup 12 "$ROOT_DIR/scripts/state.sh" --json --refresh &
    state_warmup_pid=$!
    run_warmup 6 "$ROOT_DIR/bin/seven-spotlight" index
    run_warmup 4 "$ROOT_DIR/bin/seven-apps" json
    run_warmup 4 "$ROOT_DIR/bin/seven-launchpad-native" --doctor --json
    run_warmup 5 "$ROOT_DIR/bin/seven-store-native" --json
    run_warmup 5 "$ROOT_DIR/profiles/profile-manager.sh" list --json
    run_warmup 4 "$ROOT_DIR/bin/seven-home-native" --json
    run_warmup 4 "$ROOT_DIR/scripts/shell.sh" status --json --refresh
    run_warmup 5 "$ROOT_DIR/scripts/store.sh" json --refresh
    run_warmup 5 "$ROOT_DIR/scripts/surfaces.sh" json --refresh
    run_warmup 15 "$ROOT_DIR/scripts/public-experience.sh" json --refresh
    run_warmup 3 "$ROOT_DIR/scripts/motion.sh" status --json
    run_warmup 3 "$ROOT_DIR/scripts/theme-session.sh" status --json
    prewarm_waybar_status
    wait "$state_warmup_pid" 2>/dev/null || true
    write_state >/dev/null 2>&1 || true
  } &
  if [[ "${SEVENOS_EXPERIENCE_SILENT_WARMUP:-0}" != "1" ]]; then
    notify_user "SevenOS Experience" "Search, apps, profiles and Store are warming up."
  fi
}

doctor() {
  local score
  score="$(score_json)"
  if grep -q '"state": "ready"' <<<"$score"; then
    printf 'SevenOS Shell Experience doctor: ready\n'
    return 0
  fi
  printf 'SevenOS Shell Experience doctor: partial\n'
  printf '%s\n' "$score"
  return 1
}

human_status() {
  local profile
  profile="$(active_profile)"
  printf 'SevenOS Shell Experience\n'
  printf '========================\n'
  printf 'Profile: %s\n' "$profile"
  printf 'Role:    %s\n' "$(profile_role "$profile")"
  printf 'Motion:  %s\n' "$(profile_motion)"
  printf 'State:   %s\n' "$EXPERIENCE_STATE"
  printf 'Events:  %s\n' "$EXPERIENCE_EVENTS"
}

action="${1:-status}"
case "$action" in
  status)
    if [[ "${2:-}" == "--json" || "${SEVENOS_JSON:-0}" == "1" ]]; then
      status_json
    else
      human_status
    fi
    ;;
  json)
    status_json
    ;;
  score)
    score_json
    ;;
  apply)
    apply_experience
    ;;
  doctor)
    doctor
    ;;
  launch)
    shift || true
    launch_feedback "${*:-Application}"
    ;;
  focus)
    shift || true
    focus_feedback "${*:-Window}"
    ;;
  workspace)
    workspace_feedback "${2:-$(workspace_id)}"
    ;;
  notify)
    notify_user "${2:-SevenOS}" "${3:-}"
    ;;
  warmup)
    warmup_experience
    ;;
  events)
    recent_events_json | python -m json.tool
    ;;
  recommend|recommendation)
    recommendation_json
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
