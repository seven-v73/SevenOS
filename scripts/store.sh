#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenStore Preview

Usage:
  seven store [status|modules|apps|actions|doctor|json]
  seven store install <module>

SevenStore is the user-facing catalog contract for SevenOS bundles, Flatpak
apps and safe system actions. It does not install anything unless you call
install explicitly.
EOF
}

payload_json() {
  ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])


def run_json(command, fallback):
    result = subprocess.run(
        command,
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback


def module_sort_key(item):
    order = {
        "baobab": 0,
        "forge": 1,
        "shield": 2,
        "studio": 3,
        "windows": 4,
        "horizon": 5,
        "griot": 6,
    }
    return (order.get(item["key"], 99), item["key"])


manifest_path = root / "sevenpkg" / "metapackages.json"
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
status = run_json([str(root / "bin" / "sevenpkg"), "status", "--json"], [])
flatpak = run_json(
    [str(root / "scripts" / "flatpak.sh"), "status", "--json"],
    {"ready": False, "apps": [], "installed": 0, "total": 0},
)
actions_payload = run_json(
    [str(root / "scripts" / "actions.sh"), "--json"],
    {"actions": []},
)

state_by_key = {
    item.get("name"): item
    for item in status
    if isinstance(item, dict) and item.get("name")
}

modules = []
for key, meta in manifest.items():
    state = state_by_key.get(key, {})
    modules.append({
        "key": key,
        "title": key.title(),
        "description": meta.get("description", ""),
        "category": meta.get("category", meta.get("target", meta.get("kind", "software"))),
        "kind": meta.get("kind", ""),
        "optional": bool(meta.get("optional", False)),
        "state": state.get("state", "UNKNOWN"),
        "installed": state.get("installed", 0),
        "total": state.get("total", len(meta.get("packages", []))),
        "command": f"sevenpkg install {key}",
        "trust": {
            "source": "SevenOS manifest",
            "scope": "system packages",
            "confirmation": "required",
            "privacy": "local package metadata only",
        },
    })
modules.sort(key=module_sort_key)

apps = []
for app in flatpak.get("apps", []) or []:
    app_state = app.get("state", "MISS")
    apps.append({
        "key": app.get("id", app.get("name", "")),
        "name": app.get("name", app.get("id", "")),
        "source": "flatpak",
        "state": app_state,
        "command": f"flatpak install flathub {app.get('id')}" if app.get("id") else "seven flatpak install",
        "trust": {
            "source": "Flathub",
            "scope": "sandboxed application",
            "confirmation": "required",
            "privacy": "Flatpak metadata and runtime permissions",
        },
    })

catalog_actions = []
for action in actions_payload.get("actions", []) or []:
    if not isinstance(action, dict):
        continue
    category = action.get("category", "")
    if category in {"Apps", "Profiles", "Desktop", "Ecosystem", "Installer"}:
        catalog_actions.append({
            "id": action.get("id", ""),
            "title": action.get("title", ""),
            "category": category,
            "impact": action.get("impact", "safe"),
            "command": action.get("command", ""),
            "description": action.get("description", ""),
            "trust": {
                "source": "SevenOS action registry",
                "scope": action.get("impact", "safe"),
                "confirmation": "required" if action.get("impact") not in {"safe"} else "not required",
                "privacy": "local command execution",
            },
        })

payload = {
    "schema": "sevenos.store.v1",
    "state": "product-preview",
    "writer": "scripts/store.sh",
    "trust_policy": {
        "default": "preview first, install only after explicit user confirmation",
        "sources": ["SevenOS manifest", "Flathub", "SevenOS action registry"],
        "privacy": "local-first; no account required for catalog inspection",
    },
    "summary": {
        "modules": len(modules),
        "modules_ready": sum(1 for item in modules if item["state"] == "OK"),
        "optional_modules": sum(1 for item in modules if item["optional"]),
        "flatpak_ready": bool(flatpak.get("ready", False)),
        "flatpak_apps": flatpak.get("installed", 0),
        "flatpak_total": flatpak.get("total", len(apps)),
        "actions": len(catalog_actions),
    },
    "modules": modules,
    "apps": apps,
    "actions": catalog_actions,
}
print(json.dumps(payload, indent=2))
PY
}

status() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json
import os

payload = json.loads(os.environ["PAYLOAD"])
summary = payload["summary"]
print("SevenStore Preview")
print("==================")
print(f"State:          {payload['state']}")
print(f"Modules:        {summary['modules_ready']}/{summary['modules']} ready")
print(f"Optional:       {summary['optional_modules']} module(s)")
print(f"Flatpak:        {'ready' if summary['flatpak_ready'] else 'not ready'} ({summary['flatpak_apps']}/{summary['flatpak_total']})")
print(f"Safe actions:   {summary['actions']}")
print()
print("Featured modules:")
for item in payload["modules"][:8]:
    optional = " optional" if item["optional"] else ""
    print(f"  - {item['title']:<8} {item['state']:<7} {item['installed']}/{item['total']}  {item['description']}{optional}")
print()
print("Commands:")
print("  seven store modules")
print("  seven store apps")
print("  seven store install <module>")
PY
}

modules() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json
import os

payload = json.loads(os.environ["PAYLOAD"])
print("SevenStore Modules")
print("==================")
for item in payload["modules"]:
    optional = " optional" if item["optional"] else ""
    print(f"{item['key']:<10} {item['state']:<7} {item['installed']}/{item['total']}  {item['description']}{optional}")
    print(f"{'':<10} command: {item['command']}")
PY
}

apps() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json
import os

payload = json.loads(os.environ["PAYLOAD"])
print("SevenStore Apps")
print("===============")
if not payload["apps"]:
    print("No Flatpak app catalog is available yet. Run: seven flatpak status")
else:
    for item in payload["apps"]:
        print(f"{item['name']:<28} {item['state']:<5} {item['key']}")
PY
}

actions() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json
import os

payload = json.loads(os.environ["PAYLOAD"])
print("SevenStore Actions")
print("==================")
for item in payload["actions"]:
    print(f"{item['id']:<28} {item['category']:<10} {item['impact']:<8} {item['title']}")
    print(f"{'':<28} command: {item['command']}")
PY
}

doctor() {
  local failures=0
  printf 'SevenStore Doctor\n'
  printf '=================\n'

  for path in \
    "sevenpkg/metapackages.json" \
    "bin/sevenpkg" \
    "scripts/flatpak.sh" \
    "scripts/actions.sh"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  payload_json | python -m json.tool >/dev/null || failures=$((failures + 1))

  if [[ "$failures" -gt 0 ]]; then
    log_error "SevenStore preview has $failures issue(s)."
    return 1
  fi
  log_success "SevenStore preview catalog is coherent."
}

install_module() {
  local module="${1:-}"
  if [[ -z "$module" ]]; then
    log_error "Missing module name."
    printf 'Try: seven store modules\n'
    return 1
  fi
  exec "$ROOT_DIR/bin/sevenpkg" install "$module"
}

action="${1:-status}"
case "$action" in
  status) status ;;
  modules|catalog) modules ;;
  apps) apps ;;
  actions) actions ;;
  json|--json) payload_json ;;
  doctor) doctor ;;
  install) shift; install_module "${1:-}" ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown store action: $action"; usage; exit 1 ;;
esac
