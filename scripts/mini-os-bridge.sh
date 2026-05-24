#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$CONFIG_HOME/sevenos"
STATE_FILE="$STATE_DIR/mini-os-bridge.json"

ACTION="${1:-status}"
shift || true
JSON_OUTPUT=0
YES=0
ITEMS=()

usage() {
  cat <<'EOF'
SevenOS Mini OS Bridge
======================

Usage:
  seven mini-os status [--json]
  seven mini-os suggest [--json]
  seven mini-os plan [primary] [capability ...] [--json]
  seven mini-os activate <primary> [capability ...] [--yes] [--json]

Mini OS Bridge keeps profiles autonomous while allowing explicit, visible
capability collaboration when the user needs it.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json|json) JSON_OUTPUT=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) ITEMS+=("$1") ;;
  esac
  shift
done

active_profile() {
  if [[ -f "$STATE_DIR/profile.env" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_DIR/profile.env"
    printf '%s' "${SEVENOS_ACTIVE_PROFILE:-equinox}"
  else
    printf 'equinox'
  fi
}

items_json() {
  ITEMS_PAYLOAD="$(printf '%s\n' "${ITEMS[@]}")" python - <<'PY'
import json
import os

items = []
for raw in os.environ.get("ITEMS_PAYLOAD", "").splitlines():
    for token in raw.replace("+", " + ").split():
        token = token.strip()
        if token and token != "+":
            items.append(token)
print(json.dumps(items))
PY
}

context_json() {
  if [[ -x "$ROOT_DIR/scripts/context.sh" ]]; then
    "$ROOT_DIR/scripts/context.sh" status --json 2>/dev/null || printf '{}'
  else
    printf '{}'
  fi
}

runtime_json() {
  "$ROOT_DIR/scripts/runtime-orchestrator.sh" status --json 2>/dev/null || printf '{}'
}

bridge_payload() {
  ACTION="$ACTION" \
  ACTIVE_PROFILE="$(active_profile)" \
  ITEMS_JSON="$(items_json)" \
  CONTEXT_JSON="$(context_json)" \
  RUNTIME_JSON="$(runtime_json)" \
  STATE_FILE="$STATE_FILE" \
  python - <<'PY'
import json
import os
import time
from pathlib import Path

action = os.environ.get("ACTION", "status")
active = os.environ.get("ACTIVE_PROFILE", "equinox")
state_file = Path(os.environ["STATE_FILE"])

try:
    items = json.loads(os.environ.get("ITEMS_JSON", "[]"))
except json.JSONDecodeError:
    items = []
try:
    context = json.loads(os.environ.get("CONTEXT_JSON", "{}") or "{}")
except json.JSONDecodeError:
    context = {}
try:
    runtime = json.loads(os.environ.get("RUNTIME_JSON", "{}") or "{}")
except json.JSONDecodeError:
    runtime = {}

profiles = ["equinox", "baobab", "forge", "shield", "studio", "windows", "pulse"]
aliases = {"horizon": "forge"}
items = [aliases.get(item, item) for item in items]
capability_map = {
    "forge": {
        "offers": ["dev-tools", "containers", "builds", "local-services", "deployments", "reverse-proxy", "server-logs"],
        "helps": ["code", "terminal", "documentation", "container", "build", "server", "cloud", "ssh", "deploy", "endpoint", "service"],
        "borrow_label": "DevOps capability",
    },
    "shield": {
        "offers": ["basic-security", "audit", "forensics", "sandbox"],
        "helps": ["vpn", "network", "security", "audit", "unknown-service"],
        "borrow_label": "Security capability",
    },
    "studio": {
        "offers": ["creative-tools", "recording", "media-export", "assets"],
        "helps": ["media", "camera", "recording", "image", "video", "audio"],
        "borrow_label": "Creator capability",
    },
    "windows": {
        "offers": ["vm-first-windows", "wine-fallback", "shared-folders"],
        "helps": ["exe", "windows", "office", "vm", "compatibility"],
        "borrow_label": "Windows capability",
    },
    "pulse": {
        "offers": ["low-latency", "gaming", "overlays", "controllers"],
        "helps": ["game", "steam", "lutris", "fps", "latency", "controller"],
        "borrow_label": "Gaming capability",
    },
    "baobab": {
        "offers": ["heritage", "language", "story", "sound", "map", "fashion", "food", "wisdom", "offline-memory"],
        "helps": ["read", "language", "culture", "learn", "translation", "book", "story", "heritage", "fashion", "food", "map"],
        "borrow_label": "Cultural heritage capability",
    },
}

primary_context = (context.get("primary_context") or {}) if isinstance(context, dict) else {}
signals = [str(item).lower() for item in primary_context.get("signals", [])]
intent = str(primary_context.get("intent", "")).lower()
context_text = " ".join([intent, *signals])

def suggest_caps(primary, active_caps=()):
    suggestions = []
    for key, meta in capability_map.items():
        if key == primary or key in active_caps:
            continue
        matches = [token for token in meta["helps"] if token in context_text]
        score = len(matches) * 25
        if key == "shield" and primary != "shield":
            score += 12
        if primary == "equinox" and key in {"forge", "studio"} and matches:
            score += 10
        if score > 0:
            suggestions.append({
                "profile": key,
                "label": meta["borrow_label"],
                "score": min(100, score),
                "reason": f"Context matches: {', '.join(matches) or intent}",
                "offers": meta["offers"],
                "command": f"seven mini-os activate {primary} {key} --yes",
            })
    return sorted(suggestions, key=lambda item: (-item["score"], item["profile"]))

if items:
    primary = items[0] if items[0] in profiles else active
    capabilities = []
    for item in items[1:]:
        if item in profiles and item != primary and item not in capabilities:
            capabilities.append(item)
else:
    runtime_primary = ((runtime.get("primary_profile") or {}).get("key") if isinstance(runtime.get("primary_profile"), dict) else None)
    primary = runtime_primary if runtime_primary in profiles else active
    capabilities = [item.get("key") for item in runtime.get("capabilities", []) if isinstance(item, dict) and item.get("key") in profiles]

selected = [primary, *capabilities]
suggestions = suggest_caps(primary, capabilities) if action in {"suggest", "plan"} else []
payload = {
    "schema": "sevenos.mini-os-bridge.v1",
    "action": action,
    "generated_at": int(time.time()),
    "primary": primary,
    "capabilities": capabilities,
    "selected": selected,
    "context": primary_context,
    "suggestions": suggestions,
    "communication": {
        "rule": "autonomous profiles collaborate only through explicit capability borrowing",
        "active_bus": "profile-ui.json + runtime.json + profile-isolation.json",
        "no_pollution": True,
        "implicit_borrowing": False,
        "suggestions_visible": action in {"suggest", "plan"},
    },
    "next_actions": [
        {"label": item["label"], "command": item["command"], "reason": item["reason"]}
        for item in suggestions[:4]
    ],
}
state_file.parent.mkdir(parents=True, exist_ok=True)
state_file.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(payload, indent=2, ensure_ascii=False))
PY
}

payload="$(bridge_payload)"

case "$ACTION" in
  status|suggest|plan)
    if [[ "$JSON_OUTPUT" == "1" ]]; then
      printf '%s\n' "$payload"
    else
      PAYLOAD="$payload" python - <<'PY'
import json, sys
import os
data = json.loads(os.environ.get("PAYLOAD", "{}"))
print(f"Mini OS Bridge: {data['primary']} + {', '.join(data.get('capabilities') or []) or 'no borrowed capability'}")
print("Suggestions:")
for item in data.get("suggestions", [])[:5]:
    print(f"- {item['label']} ({item['profile']}): {item['reason']}")
print("Rule: no profile dependency, only explicit collaboration.")
PY
    fi
    ;;
  activate)
    if [[ "${#ITEMS[@]}" -lt 1 ]]; then
      printf 'seven mini-os activate needs a primary profile\n' >&2
      exit 2
    fi
    if [[ "$YES" != "1" ]]; then
      printf 'Refusing to activate mini OS composition without --yes.\n' >&2
      printf 'Preview first: seven mini-os plan %s --json\n' "${ITEMS[*]}" >&2
      exit 3
    fi
    if [[ -x "$ROOT_DIR/profiles/profile-manager.sh" ]]; then
      "$ROOT_DIR/profiles/profile-manager.sh" activate "${ITEMS[0]}" >/dev/null 2>&1 || true
    fi
    "$ROOT_DIR/scripts/runtime-orchestrator.sh" activate "${ITEMS[@]}" --apply --yes >/dev/null
    "$ROOT_DIR/scripts/profile-isolation.sh" apply "${ITEMS[@]}" --yes >/dev/null
    "$ROOT_DIR/bin/seven-profile-theme" apply >/dev/null 2>&1 || true
    if [[ "$JSON_OUTPUT" == "1" ]]; then
      "$ROOT_DIR/scripts/mini-os-bridge.sh" status --json
    else
      printf 'Mini OS composition activated: %s\n' "${ITEMS[*]}"
    fi
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
