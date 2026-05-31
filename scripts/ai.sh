#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenAI Local

Usage:
  seven ai [brief|plan|focus|doctor|json]
  seven ai open blender
  seven ai "mon wifi ne marche pas"
  seven ai intent "open blender" --json
  seven ai operate "installe blender" --json
  seven ai apps --json
  seven ai context --json
  seven ai memory --json
  seven ai memory --compact --json
  seven ai shortcuts --json
  seven ai llm --json
  seven ai models --json
  seven ai manager --json
  seven ai diagnose system --json
  seven ai playbook wifi_repair --json
  seven ai provider "mon wifi ne marche pas" --json
  seven ai research "Hyprland release notes" --json --web
  SEVENAI_WEB=1 seven ai web "SevenOS Hyprland" --json
  ./scripts/ai.sh [brief|plan|focus|doctor|json|ask|intent|operate|apps|context|memory|knowledge|shortcuts|workflow|llm|models|manager|web|research|diagnose|playbook|provider]

SevenAI Local is a provider-neutral system assistant preview. It does not call
an online model; it reads SevenOS state, insights and actions, then turns them
into a short operational plan for the user.

The agent mode adds local intent parsing, app discovery, cautious execution,
system context and a local-only memory log.
EOF
}

agent() {
  python "$ROOT_DIR/scripts/seven_ai_agent.py" "$@"
}

command_json() {
  local fallback="$1"
  shift
  python - "$fallback" "$@" <<'PY'
import json
import subprocess
import sys

fallback = json.loads(sys.argv[1])
try:
    result = subprocess.run(sys.argv[2:], text=True, capture_output=True, check=False, timeout=8)
except subprocess.TimeoutExpired:
    print(json.dumps(fallback))
    raise SystemExit(0)
if result.returncode != 0 or not result.stdout.strip():
    print(json.dumps(fallback))
    raise SystemExit(0)
try:
    print(json.dumps(json.loads(result.stdout)))
except json.JSONDecodeError:
    print(json.dumps(fallback))
PY
}

payload_json() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap "rm -rf '$tmp_dir'" RETURN

  command_json '{}' "$ROOT_DIR/scripts/state.sh" --json > "$tmp_dir/state.json"
  command_json '{"insights":[],"summary":{}}' "$ROOT_DIR/scripts/insights.sh" --json > "$tmp_dir/insights.json"
  command_json '{"actions":[]}' "$ROOT_DIR/scripts/actions.sh" --json > "$tmp_dir/actions.json"
  command_json '{}' "$ROOT_DIR/scripts/shell.sh" status --json > "$tmp_dir/shell.json"
  command_json '{}' "$ROOT_DIR/scripts/installer-stack.sh" status --json > "$tmp_dir/installer.json"
  command_json '{"state":"unknown"}' "$ROOT_DIR/bin/seven" installer release --json > "$tmp_dir/installer-release.json"
  command_json '{"summary":{},"next":[]}' "$ROOT_DIR/profiles/profile-manager.sh" plan --json > "$tmp_dir/profiles.json"
  command_json '{"summary":{},"next":[]}' "$ROOT_DIR/bin/sevenpkg" plan --json > "$tmp_dir/packages.json"
  command_json '{"summary":{}}' "$ROOT_DIR/scripts/store.sh" json > "$tmp_dir/store.json"
  command_json '{"summary":{}}' "$ROOT_DIR/scripts/box.sh" json > "$tmp_dir/box.json"
  command_json '{"summary":{}}' "$ROOT_DIR/scripts/cloud.sh" json > "$tmp_dir/cloud.json"
  command_json '{"summary":{}}' "$ROOT_DIR/scripts/flow.sh" json > "$tmp_dir/flow.json"
  command_json '{"summary":{}}' "$ROOT_DIR/scripts/cluster.sh" json > "$tmp_dir/cluster.json"
  command_json '{"maturity":{"summary":{},"modules":[]}}' "$ROOT_DIR/scripts/ecosystem.sh" json > "$tmp_dir/ecosystem.json"
  command_json '{"overall":0,"actions":[],"summary":{}}' "$ROOT_DIR/scripts/control-plane.sh" --json > "$tmp_dir/control.json"

  SEVENAI_TMP="$tmp_dir" \
  python - <<'PY'
import json
import os
from pathlib import Path

tmp = Path(os.environ["SEVENAI_TMP"])

def load_file(name, fallback):
    try:
        return json.loads((tmp / name).read_text(encoding="utf-8"))
    except Exception:
        return fallback

def as_dict(value, fallback=None):
    return value if isinstance(value, dict) else (fallback or {})

state = as_dict(load_file("state.json", {}))
insights = as_dict(load_file("insights.json", {"insights": [], "summary": {}}), {"insights": [], "summary": {}})
actions = as_dict(load_file("actions.json", {"actions": []}), {"actions": []})
shell = as_dict(load_file("shell.json", {}))
installer = as_dict(load_file("installer.json", {}))
installer_release = as_dict(load_file("installer-release.json", {"state": "unknown"}), {"state": "unknown"})
profiles = as_dict(load_file("profiles.json", {"summary": {}, "next": []}), {"summary": {}, "next": []})
packages = as_dict(load_file("packages.json", {"summary": {}, "next": []}), {"summary": {}, "next": []})
store = as_dict(load_file("store.json", {"summary": {}}), {"summary": {}})
box = as_dict(load_file("box.json", {"summary": {}}), {"summary": {}})
cloud = as_dict(load_file("cloud.json", {"summary": {}}), {"summary": {}})
flow = as_dict(load_file("flow.json", {"summary": {}}), {"summary": {}})
cluster = as_dict(load_file("cluster.json", {"summary": {}}), {"summary": {}})
ecosystem = as_dict(load_file("ecosystem.json", {"maturity": {"summary": {}, "modules": []}}), {"maturity": {"summary": {}, "modules": []}})
control = as_dict(load_file("control.json", {"overall": 0, "actions": [], "summary": {}}), {"overall": 0, "actions": [], "summary": {}})

daily = state.get("daily") or {}
daily_summary = daily.get("summary") or {}
decision = daily.get("decision") or "unknown"
readiness_state = state.get("readiness") or {}
readiness = daily_summary.get("readiness", readiness_state.get("percent", 0))

recommendations = []

def add(key, title, command, reason, impact="safe", priority="medium"):
    if any(item["key"] == key for item in recommendations):
        return
    recommendations.append({
        "key": key,
        "title": title,
        "command": command,
        "reason": reason,
        "impact": impact,
        "priority": priority,
    })

if decision != "ready":
    add("daily", "Finish daily readiness", "seven daily apply --yes", "The daily gate is the closest thing to a whole-system readiness contract.", "packages", "high")

for item in (profiles.get("next") or [])[:2]:
    add(
        f"profile.{item.get('key', 'unknown')}",
        f"Complete {item.get('title', 'profile')}",
        item.get("command") or "seven profile plan",
        item.get("reason") or "A profile still has missing packages or bootstrap files.",
        "packages",
        item.get("priority", "medium"),
    )

for item in (packages.get("next") or [])[:2]:
    add(
        f"package.{item.get('key', 'unknown')}",
        item.get("title") or "Complete software layer",
        item.get("command") or "sevenpkg plan",
        item.get("reason") or "A software layer still needs installation work.",
        item.get("impact", "packages"),
        item.get("severity", "medium"),
    )

shell_state = shell.get("state", "unknown")
if shell_state not in ("READY", "NATIVE_READY", "FOUNDATION"):
    add("shell", "Stabilize Seven Shell", "seven shell doctor", "The shell should expose a coherent native fallback before the AGS migration.", "safe", "high")
elif shell_state == "NATIVE_READY":
    add("shell.next", "Plan AGS migration carefully", "seven shell plan", "The native fallback is usable; AGS can stay an explicit B3 migration instead of disrupting the desktop.", "safe", "medium")

if not installer.get("ready"):
    add("installer", "Prepare installer path", "seven installer plan", "SevenOS should stay installable for normal users, not only repaired after install.", "safe", "medium")

store_summary = store.get("summary") or {}
box_summary = box.get("summary") or {}
cloud_summary = cloud.get("summary") or {}
flow_summary = flow.get("summary") or {}
cluster_summary = cluster.get("summary") or {}
ecosystem_maturity = (ecosystem.get("maturity") or {})
ecosystem_maturity_summary = ecosystem_maturity.get("summary") or {}
ecosystem_maturity_modules = ecosystem_maturity.get("modules") or []
installer_status_release = installer.get("release") or {}
if installer_release.get("state") == "unknown" and isinstance(installer_status_release, dict):
    installer_release = installer_status_release
installer_mode = "graphical-ready" if installer_release.get("state") == "graphical-ready" else installer.get("mode", "unknown")

required_modules = max(store_summary.get("modules", 0) - store_summary.get("optional_modules", 0), 0)
if store_summary and store_summary.get("modules_ready", 0) < required_modules:
    add("store", "Complete Store modules", "seven store modules", "SevenStore still has required modules that are not ready.", "safe", "medium")
if box_summary and box_summary.get("ready", 0) < box_summary.get("total", 0):
    add("box", "Prepare sandbox runtime", "seven box doctor", "SevenBox needs all sandbox/container checks ready before workflow isolation feels complete.", "packages", "medium")
if cloud_summary and cloud_summary.get("tools_ready", 0) < cloud_summary.get("tools_total", 0):
    add("cloud", "Prepare protection tools", "seven cloud doctor", "SevenCloud backup planning needs its local tooling ready first.", "packages", "medium")
if flow_summary and flow_summary.get("ready", 0) < flow_summary.get("recipes", 0):
    add("flow", "Resolve automation recipes", "seven flow doctor", "SevenFlow recipes should all resolve to action registry commands before automation expands.", "safe", "medium")
if cluster_summary and cluster_summary.get("tools_ready", 0) < cluster_summary.get("tools_total", 0):
    add("cluster", "Prepare private mesh tools", "seven cluster doctor", "SevenCluster needs its transport/runtime checks ready before multi-machine workflows expand.", "packages", "medium")

for module in ecosystem_maturity_modules[:3]:
    if module.get("level") == "active":
        continue
    if int(module.get("score", 0) or 0) >= 85:
        continue
    add(
        f"focus.{module.get('name', 'module').lower().replace(' ', '-')}",
        f"Harden {module.get('name', 'SevenOS module')}",
        "seven ecosystem maturity",
        module.get("next") or "Move this preview toward a product-ready surface.",
        "safe",
        "medium",
    )

for insight in (insights.get("insights") or [])[:3]:
    key = f"insight.{insight.get('key', insight.get('area', 'item'))}"
    add(
        key,
        insight.get("title") or "Review insight",
        insight.get("command") or "seven insights",
        insight.get("reason") or insight.get("detail") or "SevenOS insight requires attention.",
        insight.get("impact", "safe"),
        insight.get("severity", "medium"),
    )

priority_rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
recommendations.sort(key=lambda item: (priority_rank.get(item.get("priority"), 9), item["key"]))

available_actions = []
for item in actions.get("actions", actions.get("items", []))[:8]:
    available_actions.append({
        "key": item.get("key") or item.get("id"),
        "title": item.get("title"),
        "command": item.get("command"),
        "impact": item.get("impact"),
    })

print(json.dumps({
    "schema": "sevenos.ai-local.v1",
    "mode": "local",
    "provider": "seven-local",
    "summary": {
        "decision": decision,
        "readiness": readiness,
        "shell": shell_state,
        "installer": installer_mode,
        "installer_release": installer_release.get("state", "unknown"),
        "ecosystem_maturity": ecosystem_maturity_summary.get("average", 0),
        "ecosystem_guided_preview": ecosystem_maturity_summary.get("guided_preview", 0),
        "control": control.get("overall", 0),
        "profile_actions": (profiles.get("summary") or {}).get("total", 0),
        "package_actions": (packages.get("summary") or {}).get("total", 0),
        "store_modules": f"{store_summary.get('modules_ready', 0)}/{store_summary.get('modules', 0)}",
        "box_runtime": f"{box_summary.get('ready', 0)}/{box_summary.get('total', 0)}",
        "cloud_tools": f"{cloud_summary.get('tools_ready', 0)}/{cloud_summary.get('tools_total', 0)}",
        "flow_recipes": f"{flow_summary.get('ready', 0)}/{flow_summary.get('recipes', 0)}",
        "cluster_tools": f"{cluster_summary.get('tools_ready', 0)}/{cluster_summary.get('tools_total', 0)}",
    },
    "recommendations": recommendations[:6],
    "focus": [
        {
            "rank": index + 1,
            "module": item.get("name"),
            "score": item.get("score"),
            "level": item.get("level"),
            "command": item.get("command", "seven ecosystem maturity"),
            "reason": item.get("next"),
        }
        for index, item in enumerate([
            item for item in ecosystem_maturity_modules
            if item.get("level") != "active"
        ][:5])
    ],
    "actions": available_actions,
}, indent=2))
PY
}

brief() {
  SEVENAI_PAYLOAD="$(payload_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SEVENAI_PAYLOAD"])
summary = data.get("summary", {})
print("SevenAI Local")
print("=============")
print(f"Decision: {summary.get('decision', 'unknown')} · readiness: {summary.get('readiness', 0)}%")
print(f"Shell: {summary.get('shell', 'unknown')} · installer: {summary.get('installer', 'unknown')}")
items = data.get("recommendations", [])
if not items:
    print("Next: no urgent action.")
else:
    print("Next:")
    for item in items[:3]:
        print(f"- {item.get('title')}: {item.get('command')}")
PY
}

plan() {
  SEVENAI_PAYLOAD="$(payload_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SEVENAI_PAYLOAD"])
print("SevenAI Local Plan")
print("==================")
for item in data.get("recommendations", []):
    print(f"{item.get('priority', 'medium').upper():<8} {item.get('title')}")
    print(f"         {item.get('reason')}")
    print(f"         command: {item.get('command')}")
PY
}

focus() {
  SEVENAI_PAYLOAD="$(payload_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SEVENAI_PAYLOAD"])
summary = data.get("summary", {})
print("SevenAI Product Focus")
print("=====================")
print(
    f"Ecosystem maturity: {summary.get('ecosystem_maturity', 0)}% · "
    f"guided previews: {summary.get('ecosystem_guided_preview', 0)} · "
    f"installer release: {summary.get('installer_release', 'unknown')}"
)
print()
items = data.get("focus", [])
if not items:
    print("No product focus gaps found.")
else:
    for item in items:
        print(f"{item.get('rank')}. {item.get('module')} · {item.get('score')}% · {item.get('level')}")
        print(f"   {item.get('reason')}")
        print(f"   command: {item.get('command')}")
PY
}

doctor_json() {
  local payload
  payload="$(payload_json)"
  SEVENAI_PAYLOAD="$payload" SEVENAI_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess

payload = json.loads(os.environ.get("SEVENAI_PAYLOAD", "{}"))
root = os.environ.get("SEVENAI_ROOT", ".")

def run_json(command, fallback):
    try:
        result = subprocess.run(command, text=True, capture_output=True, check=False, timeout=8)
        if result.returncode != 0 or not result.stdout.strip():
            return fallback
        return json.loads(result.stdout)
    except Exception:
        return fallback

llm = run_json([f"{root}/scripts/ai.sh", "llm", "--json"], {})
provider = run_json([f"{root}/scripts/ai.sh", "provider", "mon wifi ne marche pas", "--json"], {})
memory = run_json([f"{root}/scripts/ai.sh", "memory", "--json"], {})
context = run_json([f"{root}/scripts/ai.sh", "context", "--json"], {})
operator = run_json([f"{root}/scripts/ai.sh", "operate", "installe blender", "--json"], {})

providers = llm.get("providers") if isinstance(llm.get("providers"), list) else []
active_providers = [item.get("key") for item in providers if item.get("status") == "active"]
available_providers = [item.get("key") for item in providers if item.get("status") in {"active", "available"}]
runtime = llm.get("runtime") if isinstance(llm.get("runtime"), dict) else {}
memory_health = memory.get("health") if isinstance(memory.get("health"), dict) else {}
events = memory_health.get("total_events", 0)
warnings = []
if payload.get("provider") != "seven-local":
    warnings.append("primary payload should expose seven-local provider")
if "seven-local" not in active_providers:
    warnings.append("seven-local provider is not active")
if events and events > 5000:
    warnings.append("memory event store is large; compacting is recommended")
if memory_health.get("retention") == "compact-recommended":
    warnings.append("memory contains repeated test-like intents; compacting is recommended")
if provider.get("external_calls"):
    warnings.append("local provider made external calls")
if operator.get("schema") != "sevenos.ai.operation-plan.v1":
    warnings.append("operation planner is not available")

print(json.dumps({
    "schema": "sevenos.ai.doctor.v1",
    "state": "ready" if not warnings else "needs-attention",
    "score": 100 if not warnings else 88,
    "provider": payload.get("provider", "unknown"),
    "active_providers": active_providers,
    "available_providers": available_providers,
    "model_runtime": runtime,
    "privacy": provider.get("privacy", "unknown"),
    "web_default": (llm.get("web_policy") or {}).get("default", "unknown"),
    "memory": memory_health,
    "operator": {
        "ready": operator.get("schema") == "sevenos.ai.operation-plan.v1",
        "domain": operator.get("domain"),
        "requires_confirmation": ((operator.get("summary") or {}).get("requires_confirmation")),
        "contract": list((operator.get("contract") or {}).keys()),
    },
    "context_available": bool(context.get("active_window") or context.get("shell_context")),
    "native_surface": "bin/seven-ai-native",
    "warnings": warnings,
    "limits": [
        "Local provider is deterministic and rule/context based; model-backed reasoning is future work.",
        "Memory is local SQLite and needs periodic compaction on heavy test machines.",
        "Web research is explicit opt-in and not part of the default local context.",
        "System-changing actions require preview/apply confirmation and should stay routed through SevenOS commands.",
    ],
}, indent=2))
PY
}

doctor() {
  if [[ "${1:-}" == "--json" ]]; then
    doctor_json
    return
  fi
  local failures=0
  printf 'SevenAI Local Doctor\n'
  printf '====================\n'
  for path in \
    "scripts/state.sh" \
    "scripts/insights.sh" \
    "scripts/actions.sh" \
    "scripts/ai.sh"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done
  payload_json >/dev/null
  if [[ "$failures" -gt 0 ]]; then
    log_error "SevenAI Local has $failures missing file(s)."
    return 1
  fi
  log_success "SevenAI Local can read SevenOS state."
}

action="${1:-brief}"
case "$action" in
  open|native|gui|interface)
    shift || true
    exec "$ROOT_DIR/bin/seven-ai-native" open "$@"
    ;;
  brief|status) brief ;;
  plan) plan ;;
  focus) focus ;;
  doctor) shift || true; doctor "$@" ;;
  json|--json) payload_json ;;
  ask|run|intent|operate|apps|context|memory|knowledge|shortcuts|workflow|llm|models|manager|web|research|diagnose|playbook|provider)
    shift
    agent "$action" "$@"
    ;;
  agent)
    shift
    agent ask "$@"
    ;;
  -h|--help|help) usage ;;
  *) agent ask "$@" ;;
esac
