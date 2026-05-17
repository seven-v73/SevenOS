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
    printf '%s' "${SEVENOS_ACTIVE_PROFILE:-baobab}"
  else
    printf 'baobab'
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
  SEVENOS_ROOT="$ROOT_DIR" ACTIVE_PROFILE="$(active_profile)" CONTEXT_ACTION="$ACTION" HYPR_CLIENTS="$(hypr_clients_json)" python - <<'PY'
import json
import os
import subprocess
from collections import Counter

active_profile = os.environ.get("ACTIVE_PROFILE", "baobab")
detail_mode = os.environ.get("CONTEXT_ACTION") == "graph"

try:
    clients = json.loads(os.environ.get("HYPR_CLIENTS", "[]"))
except json.JSONDecodeError:
    clients = []

CONTEXTS = {
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
    "horizon": {
        "title": "Horizon Deploy",
        "intent": "server deployment",
        "profile": "horizon",
        "classes": ["kitty", "code", "firefox"],
        "processes": ["podman", "conmon", "caddy", "go", "seven-server", "seven-deploy", "ssh", "rsync"],
        "signals": ["container", "server", "network"],
        "scheduler_group": "horizon",
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
primary = contexts[0] if contexts else CONTEXTS["baobab"]
if primary.get("confidence", 0) < 25:
    primary = next(item for item in contexts if item["key"] == active_profile) if any(item["key"] == active_profile for item in contexts) else primary

classes = Counter(item.get("class") or "unknown" for item in window_nodes)
commands = Counter(item.get("command") or "unknown" for item in processes)

actions = []
if primary.get("profile") != active_profile and primary.get("confidence", 0) >= 50:
    actions.append({
        "key": "profile.switch-suggested",
        "severity": "medium",
        "impact": "changes",
        "title": f"Switch to {primary.get('profile').title()} profile",
        "command": f"seven profile activate {primary.get('profile')}",
        "reason": f"Detected {primary.get('title')} with {primary.get('confidence')}% confidence.",
    })
actions.append({
    "key": "scheduler.context",
    "severity": "medium",
    "impact": "safe",
    "title": "Review scheduler policy for current context",
    "command": "seven scheduler plan",
    "reason": f"Primary context maps to scheduler group {primary.get('scheduler_group')}.",
})

print(json.dumps({
    "schema": "sevenos.context.v1",
    "state": "foundation",
    "active_profile": active_profile,
    "primary_context": {
        "key": primary.get("key"),
        "title": primary.get("title"),
        "intent": primary.get("intent"),
        "confidence": primary.get("confidence"),
        "profile": primary.get("profile"),
        "scheduler_group": primary.get("scheduler_group"),
        "signals": primary.get("signals", []),
    },
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
    "actions": actions,
}, indent=2))
PY
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
obs = data.get("observations", {})
print("SevenOS Context Engine")
print("======================")
print(f"state:      {data.get('state')}")
print(f"profile:    {data.get('active_profile')}")
print(f"context:    {primary.get('title')} ({primary.get('confidence')}%)")
print(f"intent:     {primary.get('intent')}")
print(f"scheduler:  {primary.get('scheduler_group')}")
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
print(f"Context detected: {primary.get('title')} ({primary.get('confidence')}%) -> {primary.get('scheduler_group')}")
PY
  )"
  state="$(
    CONTEXT_PAYLOAD="$payload" python - <<'PY'
import json
import os

confidence = json.loads(os.environ["CONTEXT_PAYLOAD"]).get("primary_context", {}).get("confidence", 0) or 0
print("OK" if confidence >= 50 else "WARN")
PY
  )"

  if is_dry_run; then
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
