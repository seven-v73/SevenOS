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
  seven store open-app <source> <id>
  seven store remove-app <source> <id>
  seven store repair-app <source> <id>
  seven store add-profile <profile> <source> <id>

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
desktop_apps = run_json(
    [str(root / "bin" / "seven-apps"), "json"],
    {"apps": []},
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

installed_library = []
for app in desktop_apps.get("apps", []) or []:
    if not isinstance(app, dict):
        continue
    name = app.get("name") or app.get("desktop_id") or ""
    desktop_id = app.get("desktop_id") or ""
    path = app.get("path", "")
    source = "flatpak" if "flatpak" in str(path).lower() else "desktop"
    installed_library.append({
        "id": desktop_id.removesuffix(".desktop"),
        "key": desktop_id,
        "name": name,
        "source": source,
        "summary": app.get("comment", "") or "Installed desktop application.",
        "icon": app.get("icon") or "application-x-executable",
        "installed": True,
        "desktop_id": desktop_id,
        "desktop_path": path,
        "categories": app.get("categories") or [],
        "kind": "graphical",
        "quality_score": 86,
        "quality_label": "Ready",
        "beginner_visible": True,
        "badges": ["INSTALLED", "GRAPHICAL"],
        "open_command": f"seven store open-app desktop {desktop_id.removesuffix('.desktop')}" if desktop_id else "",
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
    "state": "public-beta",
    "writer": "scripts/store.sh",
    "engine": {
        "schema": "sevenos.package-engine.v1",
        "sources": [
            {"key": "pacman", "priority": 1, "trust": "official Arch/SevenOS repositories", "install": "seven store install-app pacman <package>"},
            {"key": "flatpak", "priority": 2, "trust": "sandboxed Flathub applications", "install": "seven store install-app flatpak <app-id>"},
            {"key": "aur", "priority": 3, "trust": "community build recipes; advanced users", "install": "seven store install-app aur <package>"},
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
        "privileged": "use the SevenStore installer, which prefers Polkit and falls back to sudo only when no graphical agent is active",
    },
    "profile_collections": PROFILE_COLLECTIONS,
    "summary": {
        "modules": len(modules),
        "modules_ready": sum(1 for item in modules if item["state"] == "OK"),
        "optional_modules": sum(1 for item in modules if item["optional"]),
        "flatpak_ready": bool(flatpak.get("ready", False)),
        "flatpak_apps": flatpak.get("installed", 0),
        "flatpak_total": flatpak.get("total", len(apps)),
        "installed_apps": len(installed_library),
        "actions": len(catalog_actions),
    },
    "modules": modules,
    "apps": apps,
    "installed_library": installed_library,
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
from pathlib import Path

query = os.environ["QUERY"].strip()


def run(command, timeout=8):
    try:
        result = subprocess.run(command, text=True, capture_output=True, check=False, timeout=timeout)
    except Exception:
        return ""
    return result.stdout if result.returncode == 0 else ""


ICON_ALIASES = {
    "vlc": "vlc",
    "firefox": "firefox",
    "chromium": "chromium",
    "brave": "brave-browser",
    "discord": "discord",
    "telegram": "telegram",
    "steam": "steam",
    "lutris": "lutris",
    "blender": "blender",
    "gimp": "gimp",
    "krita": "krita",
    "inkscape": "inkscape",
    "obs-studio": "com.obsproject.Studio",
    "kdenlive": "kdenlive",
    "code": "visual-studio-code",
    "vscode": "visual-studio-code",
    "libreoffice": "libreoffice-startcenter",
    "thunderbird": "thunderbird",
    "spotify": "spotify",
    "qbittorrent": "qbittorrent",
    "wireshark-qt": "wireshark",
    "wireshark": "wireshark",
}


def icon_for(name, app_id="", source="pacman"):
    key = (name or app_id or "").lower()
    app_key = (app_id or name or "").lower()
    for candidate in (key, app_key):
        if candidate in ICON_ALIASES:
            return ICON_ALIASES[candidate]
        compact = candidate.removesuffix("-bin").removesuffix("-git")
        if compact in ICON_ALIASES:
            return ICON_ALIASES[compact]
    if source == "flatpak" and app_id:
        return app_id
    if source == "aur":
        return "applications-development"
    return "system-software-install"


def pacman_installed(name):
    if not name or not shutil.which("pacman"):
        return False
    return subprocess.run(["pacman", "-Qq", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0


def flatpak_installed(app_id):
    if not app_id or not shutil.which("flatpak"):
        return False
    return subprocess.run(["flatpak", "info", app_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0


def norm(value):
    return "".join(ch for ch in str(value).lower() if ch.isalnum())


def desktop_index():
    data_dirs = [
        Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")),
        Path.home() / ".local/share/flatpak/exports/share",
        Path("/var/lib/flatpak/exports/share"),
    ]
    for raw in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
        if raw:
            data_dirs.append(Path(raw))
    entries = []
    seen = set()
    for base in data_dirs:
        app_dir = base / "applications"
        if not app_dir.is_dir():
            continue
        for path in app_dir.glob("*.desktop"):
            resolved = str(path)
            if resolved in seen:
                continue
            seen.add(resolved)
            try:
                content = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            data = {}
            in_entry = False
            for raw in content.splitlines():
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    in_entry = line == "[Desktop Entry]"
                    continue
                if not in_entry or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                data.setdefault(key.strip(), value.strip())
            if data.get("Type", "Application") != "Application" or not data.get("Exec"):
                continue
            if str(data.get("Hidden", "false")).lower() in {"1", "true", "yes"}:
                continue
            entries.append({
                "desktop_id": path.name,
                "stem": path.stem,
                "name": data.get("Name", path.stem),
                "icon": data.get("Icon", ""),
                "exec": data.get("Exec", ""),
                "categories": data.get("Categories", ""),
            })
    return entries


DESKTOPS = desktop_index()


def desktop_available(name, app_id=""):
    target_names = {norm(name), norm(app_id)}
    for entry in DESKTOPS:
        values = {norm(entry.get("stem", "")), norm(entry.get("desktop_id", "").removesuffix(".desktop")), norm(entry.get("name", "")), norm(entry.get("icon", ""))}
        if target_names & values:
            return True
        haystack = norm(" ".join(str(entry.get(key, "")) for key in ("stem", "desktop_id", "name", "icon", "exec")))
        if any(target and target in haystack for target in target_names):
            return True
    return False


def app_kind(name, summary="", desktop=False):
    raw = f"{name} {summary}".lower()
    if desktop:
        return "graphical"
    if name.startswith(("lib", "python-", "perl-", "ruby-", "haskell-", "nodejs-", "gst-", "qt5-", "qt6-")):
        return "library"
    if any(token in raw for token in (" library", "bindings", "headers", "plugin", "backend", "cli", "command line", "runtime")):
        return "library" if "library" in raw or name.startswith("lib") else "cli"
    return "cli"


def quality_for(source, installed=False, kind="cli", votes=0, popularity=0):
    score = 50
    badges = []
    if source == "pacman":
        score += 28
        badges.extend(["OFFICIAL", "VERIFIED"])
    elif source == "flatpak":
        score += 24
        badges.extend(["FLATPAK", "SANDBOXED"])
    elif source == "aur":
        score += 8
        badges.extend(["AUR", "COMMUNITY", "ADVANCED"])
        score += min(int(votes or 0), 30) // 3
        if float(popularity or 0) > 1:
            score += 4
    if kind == "graphical":
        score += 12
        badges.append("GRAPHICAL")
    elif kind == "library":
        score -= 18
        badges.append("LIBRARY")
    else:
        score -= 8
        badges.append("CLI")
    if installed:
        score += 6
        badges.append("INSTALLED")
    score = max(10, min(score, 99))
    label = "Excellent" if score >= 86 else "Trusted" if score >= 72 else "Advanced" if score >= 55 else "Technical"
    return score, label, badges


def explain(name, source, kind):
    if kind == "graphical":
        return f"{name} est une application graphique que tu peux ouvrir depuis SevenStore, Launchpad ou Spotlight."
    if kind == "library":
        return f"{name} est surtout un composant technique utile à d'autres applications, pas une app à ouvrir directement."
    if source == "aur":
        return f"{name} vient de la communauté AUR. C'est puissant, mais recommandé aux utilisateurs avancés."
    return f"{name} est un outil système/terminal. SevenStore le garde visible en mode avancé."


def recommendations_for(name):
    key = name.lower()
    groups = {
        "blender": ["krita", "inkscape", "kdenlive", "obs-studio"],
        "krita": ["gimp", "inkscape", "blender"],
        "vlc": ["mpv", "kdenlive", "obs-studio"],
        "steam": ["lutris", "mangohud", "gamescope"],
        "code": ["git", "docker", "nodejs", "python"],
        "wireshark-qt": ["nmap", "tcpdump", "zenmap"],
    }
    return groups.get(key, [])


def enrich(item):
    name = item.get("name", item.get("id", ""))
    app_id = item.get("id", name)
    source = item.get("source", "")
    summary = item.get("summary", "")
    installed = bool(item.get("installed"))
    has_desktop = desktop_available(name, app_id) or source == "flatpak"
    kind = app_kind(name, summary, has_desktop)
    score, label, quality_badges = quality_for(source, installed, kind, item.get("votes", 0), item.get("popularity", 0))
    existing = list(item.get("badges", []))
    merged = []
    for badge in [*existing, *quality_badges]:
        if badge not in merged:
            merged.append(badge)
    item["kind"] = kind
    item["desktop_available"] = has_desktop
    item["quality_score"] = score
    item["quality_label"] = label
    item["badges"] = merged
    item["beginner_visible"] = kind == "graphical" and source in {"pacman", "flatpak"} and score >= 70
    item["explanation"] = explain(name, source, kind)
    item["permissions"] = ["Network", "Files"] if source == "flatpak" else ["System package"]
    item["recommendations"] = recommendations_for(name)
    item["preview"] = {"kind": "icon", "accent": source}
    return item


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
                "icon": icon_for(name, source="pacman"),
                "installed": pacman_installed(name),
                "install_command": f"seven store install-app pacman {name}",
                "open_command": f"seven store open-app pacman {name}",
                "score": 120 if name.lower() == query.lower() else 90,
            }
        elif current:
            current["summary"] = line.strip()
    if current:
        items.append(current)
    return [enrich(item) for item in items[:16]]


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
        items.append(enrich({
            "id": name,
            "name": name,
            "source": "aur",
            "version": item.get("Version", ""),
            "summary": item.get("Description", "") or "",
            "votes": item.get("NumVotes", 0),
            "popularity": item.get("Popularity", 0),
            "maintainer": item.get("Maintainer"),
            "badges": ["AUR", "COMMUNITY"],
            "icon": icon_for(name, source="aur"),
            "installed": pacman_installed(name),
            "install_command": f"seven store install-app aur {name}",
            "open_command": f"seven store open-app aur {name}",
            "score": (105 if name.lower() == query.lower() else 55) + min(int(item.get("NumVotes", 0) or 0), 35),
        }))
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
        items.append(enrich({
            "id": app_id,
            "name": name,
            "source": "flatpak",
            "summary": summary,
            "badges": ["FLATPAK", "SANDBOXED"],
            "icon": icon_for(name, app_id, "flatpak"),
            "installed": flatpak_installed(app_id),
            "install_command": f"seven store install-app flatpak {app_id}",
            "open_command": f"seven store open-app flatpak {app_id}",
            "score": 110 if app_id.lower() == query.lower() or name.lower() == query.lower() else 80,
        }))
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
  local payload payload_file
  payload="$(payload_json)"
  payload_file="$(mktemp)"
  printf '%s\n' "$payload" >"$payload_file"
  python - "$payload_file" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
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
  rm -f "$payload_file"
}

modules() {
  local payload payload_file
  payload="$(payload_json)"
  payload_file="$(mktemp)"
  printf '%s\n' "$payload" >"$payload_file"
  python - "$payload_file" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
print("SevenStore Modules")
print("==================")
for item in payload["modules"]:
    optional = " optional" if item["optional"] else ""
    print(f"{item['key']:<10} {item['state']:<7} {item['installed']}/{item['total']}  {item['description']}{optional}")
    print(f"{'':<10} command: {item['command']}")
PY
  rm -f "$payload_file"
}

apps() {
  local payload payload_file
  payload="$(payload_json)"
  payload_file="$(mktemp)"
  printf '%s\n' "$payload" >"$payload_file"
  python - "$payload_file" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
print("SevenStore Apps")
print("===============")
if not payload["apps"]:
    print("No Flatpak app catalog is available yet. Run: seven flatpak status")
else:
    for item in payload["apps"]:
        print(f"{item['name']:<28} {item['state']:<5} {item['key']}")
PY
  rm -f "$payload_file"
}

actions() {
  local payload payload_file
  payload="$(payload_json)"
  payload_file="$(mktemp)"
  printf '%s\n' "$payload" >"$payload_file"
  python - "$payload_file" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
print("SevenStore Actions")
print("==================")
for item in payload["actions"]:
    print(f"{item['id']:<28} {item['category']:<10} {item['impact']:<8} {item['title']}")
    print(f"{'':<28} command: {item['command']}")
PY
  rm -f "$payload_file"
}

home() {
  local payload payload_file
  payload="$(payload_json)"
  payload_file="$(mktemp)"
  printf '%s\n' "$payload" >"$payload_file"
  python - "$payload_file" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
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
  rm -f "$payload_file"
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
  local payload_file
  payload_file="$(mktemp)"
  printf '%s\n' "$payload" >"$payload_file"
  python - "$payload_file" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
print(f"SevenStore Search: {payload['query']}")
print("=" * (19 + len(payload["query"])))
for item in payload.get("results", []):
    badges = " ".join(f"[{badge}]" for badge in item.get("badges", []))
    print(f"{item['name']:<30} {item['source']:<8} {badges}")
    if item.get("summary"):
        print(f"  {item['summary']}")
    if item.get("installed") and item.get("desktop_available"):
        print(f"  open: {item['open_command']}")
    elif item.get("installed"):
        print("  installed: command-line/system component")
    else:
        print(f"  install: {item['install_command']}")
PY
  rm -f "$payload_file"
}

detail() {
  local app_id="${1:-}"
  local json_output="${2:-}"
  if [[ -z "$app_id" ]]; then
    log_error "Missing app or module id."
    return 1
  fi
  local payload payload_file
  payload="$(payload_json)"
  payload_file="$(mktemp)"
  printf '%s\n' "$payload" >"$payload_file"
  APP_ID="$app_id" python - "$payload_file" <<'PY'
import json
import os
import sys

app_id = os.environ["APP_ID"]
payload = json.load(open(sys.argv[1], encoding="utf-8"))
for section in ("modules", "apps", "actions"):
    for item in payload.get(section, []):
        keys = {str(item.get("key", "")), str(item.get("id", "")), str(item.get("name", ""))}
        if app_id in keys:
            print(json.dumps({"schema": "sevenos.store-detail.v1", "section": section, "item": item}, indent=2))
            raise SystemExit(0)
print(json.dumps({"schema": "sevenos.store-detail.v1", "state": "MISS", "id": app_id}, indent=2))
raise SystemExit(1)
PY
  rm -f "$payload_file"
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
    pacman) command=($(pacman_install_command "$app_id")) ;;
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
  if [[ "$source" == "pacman" ]] && command -v pacman >/dev/null 2>&1 && package_is_satisfied "$app_id"; then
    log_success "$app_id is already installed."
    refresh_desktop_catalogs "$app_id"
    [[ -n "$profile" ]] && record_profile_app "$profile" "$source" "$app_id"
    return 0
  fi
  log_info "Installing $app_id from $source..."
  set +e
  "${command[@]}"
  local status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    refresh_desktop_catalogs "$app_id"
    [[ -n "$profile" ]] && record_profile_app "$profile" "$source" "$app_id"
  elif [[ "$status" -ne 0 ]]; then
    explain_install_failure "$source" "$app_id" "$status" "${command[@]}"
  fi
  return "$status"
}

open_app() {
  local source="${1:-}"
  local app_id="${2:-}"
  if [[ -z "$source" || -z "$app_id" ]]; then
    log_error "Usage: seven store open-app <pacman|aur|flatpak> <id>"
    return 1
  fi

  local desktop_info desktop_id desktop_path
  desktop_info="$(APP_ID="$app_id" SOURCE="$source" python - <<'PY'
import os
import re
from pathlib import Path

app_id = os.environ["APP_ID"].strip()
source = os.environ["SOURCE"].strip()


def truthy(value):
    return str(value).strip().lower() in {"1", "true", "yes"}


def read_desktop(path):
    data = {}
    in_entry = False
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    for raw in content.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_entry = line == "[Desktop Entry]"
            continue
        if not in_entry or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data.setdefault(key.strip(), value.strip())
    if data.get("Type", "Application") != "Application":
        return None
    if truthy(data.get("Hidden", "false")):
        return None
    if truthy(data.get("NoDisplay", "false")) and os.environ.get("SEVENOS_APPS_SHOW_HIDDEN") != "1":
        return None
    if not data.get("Exec"):
        return None
    return data


def norm(value):
    return re.sub(r"[^a-z0-9]+", "", value.lower())


data_dirs = [
    Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")),
    Path.home() / ".local/share/flatpak/exports/share",
    Path("/var/lib/flatpak/exports/share"),
]
for raw in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
    if raw:
        data_dirs.append(Path(raw))

target = norm(app_id)
best = None
best_score = -1
seen = set()
for base in data_dirs:
    app_dir = base / "applications"
    if not app_dir.is_dir():
        continue
    for path in app_dir.glob("*.desktop"):
        resolved = str(path)
        if resolved in seen:
            continue
        seen.add(resolved)
        data = read_desktop(path)
        if not data:
            continue
        desktop_id = path.name
        fields = {
            "desktop": desktop_id,
            "stem": path.stem,
            "name": data.get("Name", ""),
            "icon": data.get("Icon", ""),
            "exec": data.get("Exec", ""),
        }
        haystack = " ".join(fields.values())
        score = 0
        if source == "flatpak" and app_id in {desktop_id, path.stem, data.get("Icon", "")}:
            score += 120
        if norm(fields["stem"]) == target or norm(fields["desktop"].removesuffix(".desktop")) == target:
            score += 100
        if norm(fields["icon"]) == target:
            score += 88
        if norm(fields["name"]) == target:
            score += 80
        if target and target in norm(haystack):
            score += 45
        if score > best_score:
            best_score = score
            best = (desktop_id, resolved)

if best and best_score > 0:
    print("\t".join(best))
PY
)"
  if [[ -z "$desktop_info" ]]; then
    log_error "No desktop launcher found for $app_id. Try Launchpad after refreshing the app cache."
    refresh_desktop_catalogs "$app_id"
    return 1
  fi
  desktop_id="${desktop_info%%$'\t'*}"
  desktop_path="${desktop_info#*$'\t'}"
  if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'open %q %q\n' "$desktop_id" "$desktop_path"
    return 0
  fi
  if command -v gtk-launch >/dev/null 2>&1; then
    gtk-launch "${desktop_id%.desktop}" >/dev/null 2>&1 && return 0
    gtk-launch "$desktop_id" >/dev/null 2>&1 && return 0
  fi
  if command -v gio >/dev/null 2>&1; then
    gio launch "$desktop_path" >/dev/null 2>&1 && return 0
  fi
  if command -v dex >/dev/null 2>&1; then
    dex "$desktop_path" >/dev/null 2>&1 && return 0
  fi
  log_error "Could not launch $desktop_id."
  return 1
}

remove_app() {
  local source="${1:-}"
  local app_id="${2:-}"
  if [[ -z "$source" || -z "$app_id" ]]; then
    log_error "Usage: seven store remove-app <pacman|aur|flatpak> <id>"
    return 1
  fi
  local command=()
  case "$source" in
    pacman|aur|desktop) command=($(pacman_remove_command "$app_id")) ;;
    flatpak) command=(flatpak uninstall "$app_id") ;;
    *) log_error "Unknown source: $source"; return 1 ;;
  esac
  if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
    printf 'remove command: %s\n' "${command[*]}"
    return 0
  fi
  log_info "Removing $app_id from $source..."
  set +e
  "${command[@]}"
  local status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    refresh_desktop_catalogs "$app_id"
  fi
  return "$status"
}

repair_app() {
  local source="${1:-}"
  local app_id="${2:-}"
  if [[ -z "$source" || -z "$app_id" ]]; then
    log_error "Usage: seven store repair-app <pacman|aur|flatpak> <id>"
    return 1
  fi
  case "$source" in
    pacman|aur) install_app "$source" "$app_id" ;;
    flatpak)
      if [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]; then
        printf 'repair command: flatpak repair --user\n'
        return 0
      fi
      flatpak repair --user && refresh_desktop_catalogs "$app_id"
      ;;
    *) log_error "Unknown source: $source"; return 1 ;;
  esac
}

add_profile_app() {
  local profile="${1:-}"
  local source="${2:-}"
  local app_id="${3:-}"
  if [[ -z "$profile" || -z "$source" || -z "$app_id" ]]; then
    log_error "Usage: seven store add-profile <profile> <source> <id>"
    return 1
  fi
  record_profile_app "$profile" "$source" "$app_id"
}

polkit_agent_running() {
  pgrep -u "$USER" -af 'polkit-gnome-authentication-agent|lxqt-policykit-agent|mate-polkit|polkit-kde-authentication-agent|pantheon-agent-polkit' >/dev/null 2>&1
}

pacman_install_command() {
  local package="$1"
  if [[ "$(id -u)" -eq 0 ]]; then
    printf '%s\n' pacman -S --needed "$package"
    return 0
  fi
  if command -v pkexec >/dev/null 2>&1 && polkit_agent_running; then
    printf '%s\n' pkexec pacman -S --needed "$package"
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    printf '%s\n' sudo pacman -S --needed "$package"
    return 0
  fi
  if command -v pkexec >/dev/null 2>&1; then
    printf '%s\n' pkexec pacman -S --needed "$package"
    return 0
  fi
  log_error "Cannot install $package: neither sudo nor pkexec is available."
  return 1
}

pacman_remove_command() {
  local package="$1"
  if [[ "$(id -u)" -eq 0 ]]; then
    printf '%s\n' pacman -Rns "$package"
    return 0
  fi
  if command -v pkexec >/dev/null 2>&1 && polkit_agent_running; then
    printf '%s\n' pkexec pacman -Rns "$package"
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    printf '%s\n' sudo pacman -Rns "$package"
    return 0
  fi
  if command -v pkexec >/dev/null 2>&1; then
    printf '%s\n' pkexec pacman -Rns "$package"
    return 0
  fi
  log_error "Cannot remove $package: neither sudo nor pkexec is available."
  return 1
}

explain_install_failure() {
  local source="$1"
  local app_id="$2"
  local status="$3"
  shift 3
  log_error "Could not install $app_id from $source. Exit code: $status."
  if [[ "$source" == "pacman" ]]; then
    if [[ "$*" == sudo* ]]; then
      log_warn "SevenStore used sudo because no graphical Polkit agent is active."
      log_warn "Make sure your user is allowed to use sudo/wheel and enter the correct password."
    elif [[ "$*" == pkexec* ]]; then
      log_warn "Polkit denied the installation. Start a Polkit authentication agent or retry with sudo."
    fi
    log_warn "Manual fallback: sudo pacman -S --needed $app_id"
  fi
}

refresh_desktop_catalogs() {
  local app_id="${1:-}"
  local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  rm -f "$cache_home/sevenos/apps.json" \
        "$cache_home/sevenos/launchpad-apps.json" \
        "$cache_home/sevenos/spotlight.json" 2>/dev/null || true
  mkdir -p "$state_home/sevenos" "$cache_home/sevenos"
  printf '%s %s\n' "$(date +%s)" "$app_id" > "$state_home/sevenos/apps-refresh.stamp"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
  fi
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "SevenStore" "$app_id est disponible dans Launchpad et Spotlight." >/dev/null 2>&1 || true
  fi
  log_success "Refreshed Launchpad and Spotlight indexes for $app_id."
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
  open-app) shift; open_app "$@" ;;
  remove-app) shift; remove_app "$@" ;;
  repair-app) shift; repair_app "$@" ;;
  add-profile) shift; add_profile_app "$@" ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown store action: $action"; usage; exit 1 ;;
esac
