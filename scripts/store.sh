#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenStore Preview

Usage:
  seven store [status|home|modules|apps|actions|doctor|json]
  seven store search <query> [--json]
  seven store detail <id> [--json]
  seven store install <module>
  seven store install-app <source> <id> [--profile <profile>] [--dry-run]

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


PROFILE_COLLECTIONS = {
    "equinox": {
        "title": "Equinox Essentials",
        "description": "Balanced everyday apps for a premium SevenOS baseline.",
        "accent": "indigo",
        "apps": ["sevenos-core", "desktop", "visual", "reader"],
    },
    "forge": {
        "title": "Forge Developer",
        "description": "Editors, SDKs, containers and local development services.",
        "accent": "gold",
        "apps": ["dev", "hub-gui", "server"],
    },
    "shield": {
        "title": "Shield Cybersecurity",
        "description": "Authorized audit, forensics, lab isolation and reporting tools.",
        "accent": "green",
        "apps": ["cybersecurity", "cyber-forensics", "cyber-reversing", "cyber-wireless", "cyber-sandbox"],
    },
    "studio": {
        "title": "Studio Creator",
        "description": "Design, video, audio, 3D, capture and asset production.",
        "accent": "mauve",
        "apps": ["creation", "visual"],
    },
    "windows": {
        "title": "Windows Bridge",
        "description": "VM-first Windows compatibility with Wine and Bottles fallback paths.",
        "accent": "sky",
        "apps": ["windows"],
    },
    "horizon": {
        "title": "Horizon Cloud",
        "description": "Deployment, containers, reverse proxy, logs and server workflows.",
        "accent": "cyan",
        "apps": ["server"],
    },
    "pulse": {
        "title": "Pulse Gaming",
        "description": "Linux gaming, overlays, low latency and frame pacing.",
        "accent": "blue",
        "apps": ["performance", "performance-optional"],
    },
    "baobab": {
        "title": "Baobab Culture",
        "description": "African culture, learning, reading and language tools.",
        "accent": "baobab",
        "apps": ["culture", "culture-optional"],
    },
}


UI_CONTRACT = {
    "schema": "sevenos.store-ui.v1",
    "design_language": "SevenOS Liquid Glass AppCenter",
    "principles": [
        "discovery before package names",
        "one-click actions with explicit trust and source badges",
        "profile-aware recommendations without hiding essential system apps",
        "minimal text, strong visuals, soft motion and clear install progress",
    ],
    "layout": {
        "topbar": {
            "style": "floating translucent glass, search centered, profile badge on the right",
            "slots": ["SevenStore logo", "profile switcher", "semantic search", "downloads", "updates", "account/settings"],
        },
        "sidebar": {
            "style": "compact icon-first glass rail",
            "items": ["Home", "Discover", "Installed", "Updates", "Categories", "Profiles", "Library", "Permissions", "VM Apps", "AI Picks"],
        },
        "home": {
            "style": "App Store + Steam discovery feed",
            "sections": ["Featured", "Trending", "Recommended", "Profile Essentials", "Creator Tools", "Gaming", "Security", "Cloud", "African Culture"],
        },
        "download_dock": {
            "style": "floating dynamic-island progress surface",
            "states": ["queued", "resolving dependencies", "installing", "verifying", "done", "needs attention"],
        },
    },
    "visual_style": {
        "background": "deep graphite with subtle indigo/cyan ambient light",
        "cards": "8px radius, glass border, screenshot-first layout, soft elevation on hover",
        "badges": ["OFFICIAL", "FLATPAK", "AUR", "VERIFIED", "SANDBOXED", "PROFILE", "AI OPTIMIZED"],
        "motion": "fade+slide page transitions, 1.02 card hover scale, progress pulse, no aggressive neon",
    },
    "technology": {
        "ui": "Tauri + React + TypeScript",
        "styling": "Tailwind tokens generated from SevenOS identity",
        "animation": "Framer Motion-style transform/opacity only",
        "backend": "Rust package engine with AppStream, pacman, AUR RPC and Flatpak adapters",
        "database": "SQLite local cache",
        "auth": "pkexec/polkit for privileged installs",
    },
}


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
        "badges": ["VERIFIED", "PROFILE"] if meta.get("kind") == "sevenos-target" else ["OFFICIAL"],
        "profiles": [key] if key in PROFILE_COLLECTIONS else [],
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
        "badges": ["FLATPAK", "SANDBOXED"],
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
    "engine": {
        "schema": "sevenos.package-engine.v1",
        "sources": [
            {"key": "pacman", "priority": 1, "trust": "official Arch/SevenOS repositories", "install": "pkexec pacman -S --needed <package>"},
            {"key": "flatpak", "priority": 2, "trust": "sandboxed Flathub applications", "install": "flatpak install flathub <app-id>"},
            {"key": "aur", "priority": 3, "trust": "community build recipes; advanced users", "install": "paru -S --needed <package>"},
            {"key": "vm", "priority": 4, "trust": "Windows Bridge managed VM applications", "install": "seven windows run <installer>"},
        ],
        "install_policy": "never install silently; generate a plan, show trust/source/dependencies, then execute with polkit or user confirmation",
    },
    "ui": UI_CONTRACT,
    "trust_policy": {
        "default": "preview first, install only after explicit user confirmation",
        "sources": ["SevenOS manifest", "AppStream", "Pacman", "AUR RPC", "Flathub", "SevenOS action registry"],
        "privacy": "local-first; no account required for catalog inspection",
        "aur": "show votes, popularity, maintainer and warning badge before install",
        "privileged": "use pkexec/polkit, not terminal sudo, for official repository installs",
    },
    "profile_collections": PROFILE_COLLECTIONS,
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

search_json() {
  local query="${1:-}"
  if [[ -z "$query" ]]; then
    log_error "Missing search query."
    return 1
  fi
  ROOT_DIR="$ROOT_DIR" QUERY="$query" python - <<'PY'
import json
import os
import shutil
import subprocess
import urllib.parse
import urllib.request

query = os.environ["QUERY"].strip()


def run(command, timeout=8):
    try:
        result = subprocess.run(command, text=True, capture_output=True, check=False, timeout=timeout)
    except Exception:
        return ""
    return result.stdout if result.returncode == 0 else ""


def pacman_results():
    if not shutil.which("pacman"):
        return []
    out = run(["pacman", "-Ss", query])
    items = []
    current = None
    for line in out.splitlines():
        if not line.strip():
            continue
        if not line.startswith(" "):
            if current:
                items.append(current)
            repo_name = line.split()[0]
            name = repo_name.split("/", 1)[-1]
            version = line.split()[1] if len(line.split()) > 1 else ""
            current = {
                "id": name,
                "name": name,
                "source": "pacman",
                "version": version,
                "summary": "",
                "badges": ["OFFICIAL"],
                "install_command": f"pkexec pacman -S --needed {name}",
                "score": 90,
            }
        elif current:
            current["summary"] = line.strip()
    if current:
        items.append(current)
    return items[:12]


def aur_results():
    url = "https://aur.archlinux.org/rpc/?" + urllib.parse.urlencode({"v": "5", "type": "search", "arg": query})
    try:
        with urllib.request.urlopen(url, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except Exception:
        return []
    items = []
    for item in payload.get("results", [])[:12]:
        name = item.get("Name", "")
        if not name:
            continue
        items.append({
            "id": name,
            "name": name,
            "source": "aur",
            "version": item.get("Version", ""),
            "summary": item.get("Description", "") or "",
            "votes": item.get("NumVotes", 0),
            "popularity": item.get("Popularity", 0),
            "maintainer": item.get("Maintainer"),
            "badges": ["AUR", "COMMUNITY"],
            "install_command": f"paru -S --needed {name}",
            "score": 55 + min(int(item.get("NumVotes", 0) or 0), 35),
        })
    return items


def flatpak_results():
    if not shutil.which("flatpak"):
        return []
    out = run(["flatpak", "search", "--columns=application,name,description", query])
    items = []
    for line in out.splitlines()[1:13]:
        parts = [part.strip() for part in line.split("\t") if part.strip()]
        if not parts:
            continue
        app_id = parts[0]
        name = parts[1] if len(parts) > 1 else app_id
        summary = parts[2] if len(parts) > 2 else ""
        items.append({
            "id": app_id,
            "name": name,
            "source": "flatpak",
            "summary": summary,
            "badges": ["FLATPAK", "SANDBOXED"],
            "install_command": f"flatpak install flathub {app_id}",
            "score": 80,
        })
    return items


results = pacman_results() + flatpak_results() + aur_results()
seen = set()
deduped = []
for item in sorted(results, key=lambda row: (-row.get("score", 0), row.get("source", ""), row.get("name", ""))):
    key = (item.get("source"), item.get("id"))
    if key in seen:
        continue
    seen.add(key)
    deduped.append(item)

print(json.dumps({
    "schema": "sevenos.store-search.v1",
    "query": query,
    "sources": {
        "pacman": bool(shutil.which("pacman")),
        "flatpak": bool(shutil.which("flatpak")),
        "aur_rpc": True,
    },
    "ranking": ["official repositories", "sandboxed Flatpak", "trusted/high-signal AUR"],
    "results": deduped[:30],
}, indent=2))
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

home() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json
import os

payload = json.loads(os.environ["PAYLOAD"])
print("SevenStore Home")
print("===============")
print("Premium AppCenter for SevenOS profiles, apps, updates, sandbox permissions and Windows Bridge apps.")
print()
print("Featured profile collections:")
for key, item in payload.get("profile_collections", {}).items():
    print(f"  {key:<8} {item['title']:<24} {item['description']}")
print()
print("Trust badges:")
for badge in payload["ui"]["visual_style"]["badges"]:
    print(f"  - {badge}")
PY
}

search() {
  local query="${1:-}"
  local json_output="${2:-}"
  local payload
  payload="$(search_json "$query")"
  if [[ "$json_output" == "--json" ]]; then
    printf '%s\n' "$payload"
    return 0
  fi
  PAYLOAD="$payload" python - <<'PY'
import json
import os

payload = json.loads(os.environ["PAYLOAD"])
print(f"SevenStore Search: {payload['query']}")
print("=" * (19 + len(payload["query"])))
for item in payload.get("results", []):
    badges = " ".join(f"[{badge}]" for badge in item.get("badges", []))
    print(f"{item['name']:<30} {item['source']:<8} {badges}")
    if item.get("summary"):
        print(f"  {item['summary']}")
    print(f"  install plan: {item['install_command']}")
PY
}

detail() {
  local app_id="${1:-}"
  local json_output="${2:-}"
  if [[ -z "$app_id" ]]; then
    log_error "Missing app or module id."
    return 1
  fi
  local payload
  payload="$(payload_json)"
  APP_ID="$app_id" PAYLOAD="$payload" python - <<'PY'
import json
import os
import sys

app_id = os.environ["APP_ID"]
payload = json.loads(os.environ["PAYLOAD"])
for section in ("modules", "apps", "actions"):
    for item in payload.get(section, []):
        keys = {str(item.get("key", "")), str(item.get("id", "")), str(item.get("name", ""))}
        if app_id in keys:
            print(json.dumps({"schema": "sevenos.store-detail.v1", "section": section, "item": item}, indent=2))
            raise SystemExit(0)
print(json.dumps({"schema": "sevenos.store-detail.v1", "state": "MISS", "id": app_id}, indent=2))
raise SystemExit(1)
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

install_app() {
  local source="${1:-}"
  local app_id="${2:-}"
  shift 2 || true
  local dry_run=0
  local profile=""
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1 ;;
      --profile)
        profile="${2:-}"
        shift
        ;;
      --profile=*) profile="${1#--profile=}" ;;
      "") ;;
      *) log_error "Unknown install option: $1"; return 1 ;;
    esac
    shift || true
  done
  if [[ -z "$source" || -z "$app_id" ]]; then
    log_error "Usage: seven store install-app <pacman|aur|flatpak|vm> <id> [--profile <profile>] [--dry-run]"
    return 1
  fi
  local command=()
  case "$source" in
    pacman) command=(pkexec pacman -S --needed "$app_id") ;;
    aur)
      if command -v paru >/dev/null 2>&1; then
        command=(paru -S --needed "$app_id")
      elif command -v yay >/dev/null 2>&1; then
        command=(yay -S --needed "$app_id")
      else
        log_error "AUR installs require paru or yay."
        return 1
      fi
      ;;
    flatpak) command=(flatpak install flathub "$app_id") ;;
    vm) command=(seven windows run "$app_id") ;;
    *) log_error "Unknown source: $source"; return 1 ;;
  esac
  if [[ "$dry_run" == "1" || "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'SevenStore install plan\n'
    printf 'source: %s\n' "$source"
    printf 'target: %s\n' "$app_id"
    [[ -n "$profile" ]] && printf 'profile: %s\n' "$profile"
    printf 'command: %s\n' "${command[*]}"
    return 0
  fi
  "${command[@]}"
  local status=$?
  if [[ "$status" -eq 0 && -n "$profile" ]]; then
    record_profile_app "$profile" "$source" "$app_id"
  fi
  return "$status"
}

record_profile_app() {
  local profile="$1"
  local source="$2"
  local app_id="$3"
  local profile_dir app_file
  profile_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile-apps"
  app_file="$profile_dir/$profile.json"
  mkdir -p "$profile_dir"
  python - "$app_file" "$profile" "$source" "$app_id" <<'PY'
import json
import sys
import time
from pathlib import Path

path = Path(sys.argv[1])
profile, source, app_id = sys.argv[2:]
try:
    payload = json.loads(path.read_text())
except Exception:
    payload = {"schema": "sevenos.profile-apps.v1", "profile": profile, "apps": []}

apps = payload.setdefault("apps", [])
entry = {
    "id": app_id,
    "source": source,
    "installed_at": int(time.time()),
}
apps[:] = [item for item in apps if not (item.get("id") == app_id and item.get("source") == source)]
apps.insert(0, entry)
payload["profile"] = profile
path.write_text(json.dumps(payload, indent=2) + "\n")
PY
  log_success "Associated $app_id with profile $profile."
}

action="${1:-status}"
case "$action" in
  status) status ;;
  home) home ;;
  modules|catalog) modules ;;
  apps) apps ;;
  actions) actions ;;
  search) shift; search "${1:-}" "${2:-}" ;;
  detail) shift; detail "${1:-}" "${2:-}" ;;
  json|--json) payload_json ;;
  doctor) doctor ;;
  install) shift; install_module "${1:-}" ;;
  install-app) shift; install_app "$@" ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown store action: $action"; usage; exit 1 ;;
esac
