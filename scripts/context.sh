#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS Context Engine

Usage:
  seven context status [--json]
  seven context graph [--json]
  seven context plan [--json]
  seven context emit [--json]

Seven Context Engine turns process/window signals into human workflow context.
It is not a scheduler. It feeds Seven Scheduler, Seven Shell, Seven Hub and the
future SevenAI with semantic state.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|graph|plan|emit) ACTION="$1" ;;
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown context option: $1"; usage; exit 1 ;;
  esac
  shift
done

active_profile() {
  local state_file="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env"
  if [[ -f "$state_file" ]]; then
    # shellcheck disable=SC1090
    source "$state_file"
    printf '%s' "${SEVENOS_ACTIVE_PROFILE:-equinox}"
  else
    printf 'equinox'
  fi
}

hypr_clients_json() {
  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl clients -j 2>/dev/null || printf '[]'
  else
    printf '[]'
  fi
}

json_payload() {
  local waybar_context_file shell_recommendation_file
  waybar_context_file="$(mktemp)"
  shell_recommendation_file="$(mktemp)"
  if [[ -x "$ROOT_DIR/bin/seven-waybar-context" ]]; then
    "$ROOT_DIR/bin/seven-waybar-context" status >"$waybar_context_file" 2>/dev/null || printf '{}\n' >"$waybar_context_file"
  else
    printf '{}\n' >"$waybar_context_file"
  fi
  if [[ -x "$ROOT_DIR/scripts/shell-experience.sh" ]]; then
    "$ROOT_DIR/scripts/shell-experience.sh" recommend >"$shell_recommendation_file" 2>/dev/null || printf '{}\n' >"$shell_recommendation_file"
  else
    printf '{}\n' >"$shell_recommendation_file"
  fi
  SEVENOS_ROOT="$ROOT_DIR" ACTIVE_PROFILE="$(active_profile)" CONTEXT_ACTION="$ACTION" HYPR_CLIENTS="$(hypr_clients_json)" WAYBAR_CONTEXT_FILE="$waybar_context_file" SHELL_RECOMMENDATION_FILE="$shell_recommendation_file" python - <<'PY'
import json
import os
import subprocess
from collections import Counter

active_profile = os.environ.get("ACTIVE_PROFILE", "equinox")
detail_mode = os.environ.get("CONTEXT_ACTION") == "graph"

try:
    clients = json.loads(os.environ.get("HYPR_CLIENTS", "[]"))
except json.JSONDecodeError:
    clients = []


def read_json_file(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {}


waybar_context = read_json_file(os.environ.get("WAYBAR_CONTEXT_FILE", ""))
shell_recommendation = read_json_file(os.environ.get("SHELL_RECOMMENDATION_FILE", ""))

CONTEXTS = {
    "equinox": {
        "title": "Equinox Workspace",
        "intent": "balanced daily computing",
        "profile": "equinox",
        "classes": ["waybar", "kitty", "org.gnome.Nautilus", "firefox", "chromium"],
        "processes": ["seven", "seven-daemon", "seven-server", "waybar", "hyprpaper", "mako", "swaync", "nautilus", "kitty"],
        "signals": ["system", "files", "shell", "browser"],
        "scheduler_group": "equinox",
    },
    "forge": {
        "title": "Forge Environment",
        "intent": "development",
        "profile": "forge",
        "classes": ["code", "codium", "kitty", "Alacritty", "firefox", "chromium"],
        "processes": ["code", "codium", "helix", "hx", "nvim", "node", "npm", "cargo", "rustc", "docker", "podman", "postgres"],
        "signals": ["editor", "terminal", "container", "documentation"],
        "scheduler_group": "forge",
    },
    "studio": {
        "title": "Studio Session",
        "intent": "creative production",
        "profile": "studio",
        "classes": ["blender", "krita", "gimp", "inkscape", "kdenlive", "obs"],
        "processes": ["blender", "krita", "gimp", "inkscape", "kdenlive", "ardour", "obs", "pipewire", "wireplumber"],
        "signals": ["creative-app", "media", "audio"],
        "scheduler_group": "studio",
    },
    "shield": {
        "title": "Security Audit",
        "intent": "cybersecurity",
        "profile": "shield",
        "classes": ["wireshark", "burpsuite", "zaproxy", "kitty"],
        "processes": ["wireshark", "nmap", "burpsuite", "zaproxy", "john", "hashcat", "aircrack-ng", "firejail"],
        "signals": ["network-audit", "sandbox", "forensics"],
        "scheduler_group": "shield",
    },
    "windows": {
        "title": "Windows Mode",
        "intent": "compatibility",
        "profile": "windows",
        "classes": ["virt-manager", "Bottles", "lutris"],
        "processes": ["qemu-system-x86_64", "virt-manager", "wineserver", "wine", "bottles", "lutris"],
        "signals": ["vm", "wine", "compatibility"],
        "scheduler_group": "windows",
    },
    "devops": {
        "title": "Forge DevOps",
        "intent": "software development and deployment",
        "profile": "forge",
        "classes": ["kitty", "code", "firefox"],
        "processes": ["podman", "conmon", "caddy", "go", "seven-server", "seven-deploy", "ssh", "rsync"],
        "signals": ["container", "server", "network", "deploy"],
        "scheduler_group": "forge",
    },
    "baobab": {
        "title": "Baobab System",
        "intent": "system maintenance",
        "profile": "baobab",
        "classes": ["waybar", "kitty", "org.gnome.Nautilus"],
        "processes": ["seven", "seven-daemon", "seven-server", "waybar", "hyprpaper", "mako", "nautilus"],
        "signals": ["system", "files", "shell"],
        "scheduler_group": "baobab",
    },
    "streaming": {
        "title": "Streaming Context",
        "intent": "streaming",
        "profile": "studio",
        "classes": ["obs", "discord", "firefox", "chromium"],
        "processes": ["obs", "Discord", "discord", "firefox", "chromium", "spotify"],
        "signals": ["capture", "chat", "browser", "audio"],
        "scheduler_group": "studio",
    },
}


def run(command):
    return subprocess.run(command, text=True, capture_output=True, check=False)


def process_rows():
    result = run(["ps", "-eo", "pid=,ppid=,ni=,pcpu=,pmem=,comm="])
    rows = []
    if result.returncode != 0:
        return rows
    for raw in result.stdout.splitlines():
        parts = raw.split(None, 5)
        if len(parts) < 6:
            continue
        pid, ppid, nice, pcpu, pmem, comm = parts
        try:
            nice_value = int(nice)
        except ValueError:
            nice_value = 0
        rows.append({
            "id": f"pid:{pid}",
            "pid": int(pid),
            "ppid": int(ppid),
            "nice": nice_value,
            "pcpu": float(pcpu),
            "pmem": float(pmem),
            "command": comm,
            "type": "process",
        })
    return rows


def match_name(name, candidates):
    value = (name or "").lower()
    return any(value == item.lower() or value.startswith(item.lower()) for item in candidates)


processes = process_rows()
window_nodes = []
for index, client in enumerate(clients):
    cls = client.get("class") or client.get("initialClass") or ""
    title = client.get("title") or ""
    workspace = client.get("workspace", {}).get("name") or client.get("workspace", {}).get("id")
    window_nodes.append({
        "id": f"window:{index}",
        "type": "window",
        "class": cls,
        "title": title,
        "workspace": workspace,
        "focused": bool(client.get("focusHistoryID") == 0),
    })

nodes = processes[:120] + window_nodes
relationships = []
pid_index = {item["pid"]: item for item in processes}
for process in processes[:120]:
    parent = pid_index.get(process.get("ppid"))
    if parent:
        relationships.append({
            "from": parent["id"],
            "to": process["id"],
            "type": "parent-child",
        })

contexts = []
for key, context in CONTEXTS.items():
    matched_processes = [item for item in processes if match_name(item.get("command"), context["processes"])]
    matched_windows = [item for item in window_nodes if match_name(item.get("class"), context["classes"]) or match_name(item.get("title"), context["classes"])]
    score = len(matched_processes) * 2 + len(matched_windows) * 3
    if context["profile"] == active_profile:
        score += 10
    confidence = min(100, score * 10)
    contexts.append({
        "key": key,
        **context,
        "score": score,
        "confidence": confidence,
        "active_profile_match": context["profile"] == active_profile,
        "process_matches": len(matched_processes),
        "window_matches": len(matched_windows),
        "sample_processes": matched_processes[:8],
        "sample_windows": matched_windows[:8],
    })

contexts.sort(key=lambda item: (item["confidence"], item["score"]), reverse=True)
primary = contexts[0] if contexts else CONTEXTS["equinox"]
if primary.get("confidence", 0) < 25:
    primary = next(item for item in contexts if item["key"] == active_profile) if any(item["key"] == active_profile for item in contexts) else primary

classes = Counter(item.get("class") or "unknown" for item in window_nodes)
commands = Counter(item.get("command") or "unknown" for item in processes)

active_app = waybar_context.get("app") if isinstance(waybar_context.get("app"), dict) else {}
active_layout = waybar_context.get("layout") if isinstance(waybar_context.get("layout"), dict) else {}
active_key = str(active_app.get("key") or "")
active_service = str(active_app.get("service") or "")
active_density = str(active_layout.get("density") or "")
active_priority = str(active_layout.get("priority") or "")


def foreground_context():
    if active_service in {"streaming", "youtube"} or active_density == "immersive" or active_priority == "content":
        return {
            "key": "foreground.content",
            "title": "Foreground Content",
            "intent": "immersive foreground use",
            "profile": active_profile,
            "scheduler_group": active_profile,
            "confidence": 100,
            "signals": ["foreground", "content", "fullscreen"],
            "source": "active-window",
        }
    if active_key in {"developer", "terminal"}:
        return {
            "key": "foreground.forge",
            "title": "Foreground Development",
            "intent": "active development workflow",
            "profile": "forge",
            "scheduler_group": "forge",
            "confidence": 92,
            "signals": ["foreground", "developer", active_key],
            "source": "active-window",
        }
    if active_key in {"studio", "media"}:
        return {
            "key": "foreground.studio",
            "title": "Foreground Studio",
            "intent": "active media or creative workflow",
            "profile": "studio",
            "scheduler_group": "studio",
            "confidence": 90,
            "signals": ["foreground", "media", active_key],
            "source": "active-window",
        }
    if active_key in {"files"}:
        return {
            "key": "foreground.files",
            "title": "Foreground Files",
            "intent": "file management",
            "profile": active_profile,
            "scheduler_group": active_profile,
            "confidence": 82,
            "signals": ["foreground", "files"],
            "source": "active-window",
        }
    return {}


focused = foreground_context()
effective = primary
effective_reason = "semantic-background"
if focused and (focused.get("confidence", 0) >= primary.get("confidence", 0) - 20 or active_density in {"immersive", "compact"}):
    effective = focused
    effective_reason = "active-window"

alignment = {
    "active_profile": active_profile,
    "semantic_profile": primary.get("profile"),
    "effective_profile": effective.get("profile"),
    "foreground_profile": focused.get("profile", "") if focused else "",
    "foreground_overrode_semantic": bool(focused and effective.get("key") == focused.get("key")),
    "reason": effective_reason,
    "profile_aligned": effective.get("profile") == active_profile,
}

actions = []
if effective.get("profile") != active_profile and effective.get("confidence", 0) >= 50:
    actions.append({
        "key": "profile.switch-suggested",
        "severity": "medium",
        "impact": "changes",
        "title": f"Switch to {effective.get('profile').title()} profile",
        "command": f"seven profile activate {effective.get('profile')}",
        "reason": f"Detected {effective.get('title')} with {effective.get('confidence')}% confidence.",
    })
actions.append({
    "key": "scheduler.context",
    "severity": "medium",
    "impact": "safe",
    "title": "Review scheduler policy for current context",
    "command": "seven scheduler plan",
    "reason": f"Effective context maps to scheduler group {effective.get('scheduler_group')}.",
})

print(json.dumps({
    "schema": "sevenos.context.v1",
    "state": "foundation",
    "active_profile": active_profile,
    "active": {
        "profile": waybar_context.get("profile", {}),
        "app": waybar_context.get("app", {}),
        "window": waybar_context.get("window", {}),
        "layout": waybar_context.get("layout", {}),
        "workspace": (waybar_context.get("app") or {}).get("workspace", ""),
    },
    "primary_context": {
        "key": primary.get("key"),
        "title": primary.get("title"),
        "intent": primary.get("intent"),
        "confidence": primary.get("confidence"),
        "profile": primary.get("profile"),
        "scheduler_group": primary.get("scheduler_group"),
        "signals": primary.get("signals", []),
    },
    "foreground_context": focused,
    "effective_context": {
        "key": effective.get("key"),
        "title": effective.get("title"),
        "intent": effective.get("intent"),
        "confidence": effective.get("confidence"),
        "profile": effective.get("profile"),
        "scheduler_group": effective.get("scheduler_group"),
        "signals": effective.get("signals", []),
        "source": effective.get("source", effective_reason),
    },
    "alignment": alignment,
    "contexts": contexts,
    "graph": {
        "node_count": len(nodes),
        "relationship_count": len(relationships),
        "nodes": nodes[:80] if detail_mode else [],
        "relationships": relationships[:120] if detail_mode else [],
    },
    "observations": {
        "process_count": len(processes),
        "window_count": len(window_nodes),
        "top_commands": commands.most_common(8),
        "top_window_classes": classes.most_common(8),
    },
    "shell_recommendation": shell_recommendation,
    "waybar_context": {
        "schema": waybar_context.get("schema", ""),
        "event": waybar_context.get("event", ""),
        "time": waybar_context.get("time", 0),
        "profile": waybar_context.get("profile", {}),
        "app": waybar_context.get("app", {}),
        "layout": waybar_context.get("layout", {}),
        "window_memory": waybar_context.get("window_memory", {}),
    },
    "actions": actions,
}, indent=2))
PY
  rm -f "$waybar_context_file" "$shell_recommendation_file"
}

status() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    json_payload
    return 0
  fi

  CONTEXT_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTEXT_PAYLOAD"])
primary = data.get("primary_context", {})
effective = data.get("effective_context", {})
alignment = data.get("alignment", {})
obs = data.get("observations", {})
print("SevenOS Context Engine")
print("======================")
print(f"state:      {data.get('state')}")
print(f"profile:    {data.get('active_profile')}")
print(f"context:    {primary.get('title')} ({primary.get('confidence')}%)")
print(f"effective:  {effective.get('title')} ({effective.get('confidence')}%)")
print(f"intent:     {primary.get('intent')}")
print(f"scheduler:  {effective.get('scheduler_group') or primary.get('scheduler_group')}")
print(f"alignment:  {alignment.get('reason')} / profile-aligned={alignment.get('profile_aligned')}")
print(f"signals:    {', '.join(primary.get('signals', []))}")
print(f"observed:   {obs.get('process_count', 0)} processes / {obs.get('window_count', 0)} windows")
PY
}

graph() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    json_payload
    return 0
  fi

  CONTEXT_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTEXT_PAYLOAD"])
graph = data.get("graph", {})
print("SevenOS Context Graph")
print("=====================")
print(f"nodes:         {graph.get('node_count', 0)}")
print(f"relationships: {graph.get('relationship_count', 0)}")
print()
for item in data.get("contexts", [])[:6]:
    print(f"{item.get('confidence', 0):>3}%  {item.get('title'):<22} process={item.get('process_matches')} window={item.get('window_matches')}")
PY
}

plan() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    json_payload
    return 0
  fi

  CONTEXT_PAYLOAD="$(json_payload)" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTEXT_PAYLOAD"])
print("SevenOS Context Plan")
print("====================")
effective = data.get("effective_context", {})
alignment = data.get("alignment", {})
if effective:
    print(f"effective {effective.get('profile', ''):<8} {effective.get('title')} · {alignment.get('reason')}")
    print()
for item in data.get("actions", []):
    print(f"{item.get('severity', 'medium'):<8} {item.get('impact', 'safe'):<8} {item.get('command')}")
    print(f"         {item.get('reason')}")
PY
}

emit_context() {
  local payload compact message state emit_output
  payload="$(json_payload)"
  compact="$(
    CONTEXT_PAYLOAD="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTEXT_PAYLOAD"])
primary = data.get("primary_context", {})
print(json.dumps({
    "schema": "sevenos.context-event.v1",
    "active_profile": data.get("active_profile"),
    "primary_context": primary,
    "effective_context": data.get("effective_context", {}),
    "alignment": data.get("alignment", {}),
    "graph": data.get("graph", {}),
    "observations": data.get("observations", {}),
    "recommended_actions": data.get("actions", []),
}, separators=(",", ":")))
PY
  )"
  message="$(
    CONTEXT_PAYLOAD="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTEXT_PAYLOAD"])
primary = data.get("primary_context", {})
effective = data.get("effective_context", primary)
print(f"Context detected: {primary.get('title')} ({primary.get('confidence')}%) · effective: {effective.get('title')} -> {effective.get('scheduler_group')}")
PY
  )"
  state="$(
    CONTEXT_PAYLOAD="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTEXT_PAYLOAD"])
confidence = data.get("effective_context", data.get("primary_context", {})).get("confidence", 0) or 0
print("OK" if confidence >= 50 else "WARN")
PY
  )"

  if is_dry_run; then
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      CONTEXT_PAYLOAD="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTEXT_PAYLOAD"])
print(json.dumps({
    "schema": "sevenos.context.emit.v1",
    "state": "DRY_RUN",
    "message": "context event preview",
    "primary_context": data.get("primary_context", {}),
    "effective_context": data.get("effective_context", {}),
    "alignment": data.get("alignment", {}),
}, indent=2))
PY
      return 0
    fi
    printf 'DRY-RUN > SevenBus > Context > %s\n' "$message"
    return 0
  fi

  emit_output="$("$ROOT_DIR/scripts/events.sh" log --source context --type context --state "$state" --message "$message" --command "seven context status" --payload-json "$compact" 2>&1 || true)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    CONTEXT_PAYLOAD="$payload" EMIT_OUTPUT="$emit_output" EMIT_STATE="$state" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTEXT_PAYLOAD"])
print(json.dumps({
    "schema": "sevenos.context.emit.v1",
    "state": os.environ["EMIT_STATE"],
    "message": os.environ["EMIT_OUTPUT"] or "context event recorded",
    "primary_context": data.get("primary_context", {}),
    "effective_context": data.get("effective_context", {}),
    "alignment": data.get("alignment", {}),
}, indent=2))
PY
  else
    printf 'SevenOS Context Emit\n'
    printf '====================\n'
    printf '%s\n' "$message"
    [[ -n "$emit_output" ]] && printf '%s\n' "$emit_output"
  fi
}

case "$ACTION" in
  status) status ;;
  graph) graph ;;
  plan) plan ;;
  emit) emit_context ;;
  *) log_error "Unknown context action: $ACTION"; usage; exit 1 ;;
esac
