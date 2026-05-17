#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenCluster Preview

Usage:
  seven cluster [status|nodes|plan|doctor|json]

SevenCluster is the local/private multi-machine contract for SevenOS. It does
not expose remote control; it reports readiness, node declarations and policy.
EOF
}

payload_json() {
  ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
import platform
import shutil
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
home = Path.home()
config_dir = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")) / "sevenos" / "cluster"
nodes_file = config_dir / "nodes.json"

tools = [
    {
        "key": "ssh",
        "label": "OpenSSH client",
        "state": "OK" if shutil.which("ssh") else "MISS",
        "command": "seven improve deployment --apply --yes",
    },
    {
        "key": "rsync",
        "label": "Rsync file transport",
        "state": "OK" if shutil.which("rsync") else "MISS",
        "command": "seven improve deployment --apply --yes",
    },
    {
        "key": "podman",
        "label": "Podman workload runtime",
        "state": "OK" if shutil.which("podman") else "MISS",
        "command": "seven improve deployment --apply --yes",
    },
    {
        "key": "caddy",
        "label": "Caddy local routing",
        "state": "OK" if shutil.which("caddy") else "MISS",
        "command": "seven improve deployment --apply --yes",
    },
]

nodes = []
if nodes_file.exists():
    try:
        loaded = json.loads(nodes_file.read_text(encoding="utf-8"))
        if isinstance(loaded, list):
            nodes = loaded
        elif isinstance(loaded, dict):
            nodes = loaded.get("nodes", [])
    except json.JSONDecodeError:
        nodes = []

local_node = {
    "id": platform.node() or "localhost",
    "role": "local",
    "address": "127.0.0.1",
    "state": "local",
    "source": "runtime",
}
declared_nodes = [
    {
        "id": item.get("id") or item.get("host") or item.get("address") or "node",
        "role": item.get("role", "worker"),
        "address": item.get("address") or item.get("host") or "",
        "state": "declared" if item.get("address") or item.get("host") else "incomplete",
        "source": str(nodes_file),
    }
    for item in nodes
    if isinstance(item, dict)
]

all_nodes = [local_node, *declared_nodes]
actions = []
if not nodes_file.exists():
    actions.append({
        "key": "declare-nodes",
        "title": "Declare private nodes",
        "severity": "medium",
        "impact": "safe",
        "command": "mkdir -p ~/.config/sevenos/cluster && $EDITOR ~/.config/sevenos/cluster/nodes.json",
        "reason": "SevenCluster needs an explicit local node registry before it can guide multi-machine work.",
    })
if any(item["state"] != "OK" for item in tools):
    actions.append({
        "key": "cluster-tools",
        "title": "Install cluster transport tools",
        "severity": "medium",
        "impact": "packages",
        "command": "seven improve deployment --apply --yes",
        "reason": "Private clustering depends on SSH, rsync, Podman and local routing tools.",
    })

payload = {
    "schema": "sevenos.cluster.v1",
    "state": "preview",
    "writer": "scripts/cluster.sh",
    "summary": {
        "tools_ready": sum(1 for item in tools if item["state"] == "OK"),
        "tools_total": len(tools),
        "nodes": len(all_nodes),
        "declared_nodes": len(declared_nodes),
        "actions": len(actions),
    },
    "policy": {
        "remote_control": False,
        "bind": "local-first",
        "requires_explicit_nodes": True,
        "requires_user_confirmation": True,
    },
    "tools": tools,
    "nodes": all_nodes,
    "config": str(nodes_file),
    "workspace": str(home / "SevenOS" / "Cluster"),
    "actions": actions,
    "docs": str(root / "docs" / "ECOSYSTEM.md"),
}
print(json.dumps(payload, indent=2))
PY
}

status() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
s = d["summary"]
print("SevenCluster Preview")
print("====================")
print(f"Tools:     {s['tools_ready']}/{s['tools_total']} ready")
print(f"Nodes:     {s['nodes']} total, {s['declared_nodes']} declared")
print(f"Policy:    local-first, no remote control")
print(f"Config:    {d['config']}")
print()
for item in d["tools"]:
    print(f"  - {item['key']:<8} {item['state']:<5} {item['label']}")
PY
}

nodes() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
print("SevenCluster Nodes")
print("==================")
for item in d["nodes"]:
    print(f"{item['id']:<24} {item['role']:<10} {item['state']:<10} {item['address']}")
PY
}

plan() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
print("SevenCluster Plan")
print("=================")
if not d["actions"]:
    print("No required actions. SevenCluster is ready for local preview planning.")
else:
    for item in d["actions"]:
        print(f"{item['severity'].upper():<8} {item['title']}")
        print(f"         {item['reason']}")
        print(f"         command: {item['command']}")
PY
}

doctor() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
print("SevenCluster Doctor")
print("===================")
for item in d["tools"]:
    print(f"[{item['state']}] {item['key']}")
if d["summary"]["tools_ready"] < 2:
    raise SystemExit(1)
PY
}

action="${1:-status}"
case "$action" in
  status) status ;;
  nodes) nodes ;;
  plan) plan ;;
  doctor) doctor ;;
  json|--json) payload_json ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown cluster action: $action"; usage; exit 1 ;;
esac
