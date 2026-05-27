#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
IDENTITY_ENV="$STATE_DIR/identity.env"
IDENTITY_JSON="$STATE_DIR/identity.json"

usage() {
  cat <<'EOF'
SevenOS Identity

Usage:
  seven identity
  seven identity --json
  seven identity packs
  seven identity packs --json
  seven identity current
  seven identity current --json
  seven identity design
  seven identity design --json
  seven identity theme
  seven identity theme --json
  seven identity theme-doctor
  seven identity icons
  seven identity icons --json
  seven identity visuals
  seven identity visuals install --yes
  seven identity experience
  seven identity experience --json
  seven identity open
  seven identity activate <pack>
  seven identity plan
  seven identity doctor
  seven identity doctor --json
  ./scripts/identity.sh [status|json|plan|doctor]

Shows the SevenOS futuristic product language used by profiles, onboarding,
Hub, shell surfaces and future contextual accent packs.
EOF
}

json_output() {
  SEVENOS_IDENTITY_ROOT="$ROOT_DIR" SEVENOS_IDENTITY_CURRENT="$(current_pack_key)" python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["SEVENOS_IDENTITY_ROOT"])
packs = json.loads((root / "identity" / "accent-packs.json").read_text(encoding="utf-8"))
current_key = os.environ.get("SEVENOS_IDENTITY_CURRENT") or packs.get("default_pack", "pan-african")
current_pack = next((item for item in packs["packs"] if item.get("key") == current_key), packs["packs"][0])

profiles = [
    {
        "key": "baobab",
        "title": "Baobab",
        "role": "Roots",
        "accent": "seven-blue",
        "symbol": "baobab-system-mark",
        "principle": "stability",
        "story": "The adaptive base: system health, identity, desktop and daily trust.",
    },
    {
        "key": "forge",
        "title": "Forge",
        "role": "Builder",
        "accent": "seven-cyan",
        "symbol": "forge-profile-mark",
        "principle": "creation through skill",
        "story": "The builder space: code, learning, containers and productive power.",
    },
    {
        "key": "shield",
        "title": "Shield",
        "role": "Guardian",
        "accent": "seven-green",
        "symbol": "shield-profile-mark",
        "principle": "visible protection",
        "story": "The guardian space: audit, sandbox, forensics and careful defense.",
    },
    {
        "key": "studio",
        "title": "Studio",
        "role": "Maker",
        "accent": "seven-violet",
        "symbol": "motif-diamond",
        "principle": "expressive production",
        "story": "The maker space: image, sound, motion, 3D and cultural output.",
    },
    {
        "key": "windows",
        "title": "Windows",
        "role": "Bridge",
        "accent": "seven-blue",
        "symbol": "motif-cross",
        "principle": "compatibility without surrender",
        "story": "The bridge space: Windows apps inside a Linux-first life.",
    },
    {
        "key": "griot",
        "title": "Griot",
        "role": "Memory",
        "accent": "seven-violet",
        "symbol": "griot-doc-mark",
        "principle": "transmission",
        "story": "The memory layer: docs, notes, logs, explanation and knowledge transfer.",
    },
]

print(json.dumps({
    "schema": "sevenos.identity.v2",
    "positioning": "Next generation intelligent Linux experience for creators, developers and cybersecurity.",
    "tagline": "Beyond the Desktop.",
    "question": "Does this make Linux more fluid, secure, immersive and context-aware?",
    "current_pack": current_pack,
    "principles": [
        {"key": "fluidity", "label": "Fluidity", "meaning": "Every shell surface should feel alive and continuous."},
        {"key": "transparency", "label": "Transparency", "meaning": "Glass, compositor blur and translucent layers carry the interface."},
        {"key": "minimalism", "label": "Intelligent minimalism", "meaning": "SevenOS exposes useful features without procedural clutter."},
        {"key": "depth", "label": "Depth", "meaning": "Luminous layers and subtle glow create cinematic hierarchy."},
        {"key": "contextuality", "label": "Contextuality", "meaning": "Profiles, AI and security state tune visible actions."},
        {"key": "security", "label": "Visible security", "meaning": "Cyber Mode and Shield make trust observable without noise."},
    ],
    "profiles": profiles,
    "regional_packs": packs["packs"],
    "components": [
        "kente-divider.svg",
        "adinkra-status-ok.svg",
        "baobab-system-mark.svg",
        "griot-doc-mark.svg",
        "forge-profile-mark.svg",
        "shield-profile-mark.svg",
    ],
}, indent=2))
PY
}

current_pack_key() {
  if [[ -f "$IDENTITY_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$IDENTITY_ENV"
    printf '%s' "${SEVENOS_IDENTITY_PACK:-pan-african}"
  else
    printf 'pan-african'
  fi
}

pack_exists() {
  local key="$1"
  python - "$ROOT_DIR/identity/accent-packs.json" "$key" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
key = sys.argv[2]
raise SystemExit(0 if any(item.get("key") == key for item in data.get("packs", [])) else 1)
PY
}

pack_json_by_key() {
  local key="$1"
  python - "$ROOT_DIR/identity/accent-packs.json" "$key" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
key = sys.argv[2]
pack = next((item for item in data.get("packs", []) if item.get("key") == key), None)
if not pack:
    raise SystemExit(1)
print(json.dumps(pack, indent=2))
PY
}

current_json() {
  local key
  key="$(current_pack_key)"
  pack_exists "$key" || key="pan-african"
  SEVENOS_IDENTITY_PACK_PAYLOAD="$(pack_json_by_key "$key")" python - <<'PY'
import json
import os

pack = json.loads(os.environ["SEVENOS_IDENTITY_PACK_PAYLOAD"])
print(json.dumps({
    "schema": "sevenos.identity-current.v1",
    "pack": pack,
    "config": {
        "env": "~/.config/sevenos/identity.env",
        "json": "~/.config/sevenos/identity.json",
    },
}, indent=2))
PY
}

current_status() {
  local key
  key="$(current_pack_key)"
  pack_exists "$key" || key="pan-african"
  python - "$ROOT_DIR/identity/accent-packs.json" "$key" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
key = sys.argv[2]
pack = next(item for item in data.get("packs", []) if item.get("key") == key)
print("SevenOS Active Identity Pack")
print("============================")
print()
print(f"Pack:        {pack.get('title')}")
print(f"Key:         {pack.get('key')}")
print(f"Accent:      {pack.get('accent')}")
print(f"Pattern:     {pack.get('pattern')}")
print(f"Signal:      {pack.get('signal')}")
print(f"State:       {pack.get('state')}")
print(f"Description: {pack.get('description')}")
PY
}

active_theme_mode() {
  local theme_pref="$STATE_DIR/theme.conf"
  if [[ -f "$theme_pref" ]]; then
    # shellcheck disable=SC1090
    source "$theme_pref" || true
  fi
  printf '%s' "${SEVENOS_THEME_MODE:-dark}"
}

design_json() {
  SEVENOS_IDENTITY_ROOT="$ROOT_DIR" SEVENOS_THEME_MODE_ACTIVE="$(active_theme_mode)" python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["SEVENOS_IDENTITY_ROOT"])
theme_mode = os.environ.get("SEVENOS_THEME_MODE_ACTIVE", "dark")
contract = json.loads((root / "identity" / "design-engine.json").read_text(encoding="utf-8"))
active_key = "seven-latte" if theme_mode == "light" else "seven-mocha"
active = contract["modes"][active_key]

icon_dirs = [
    Path.home() / ".local/share/icons",
    Path.home() / ".icons",
    Path("/usr/local/share/icons"),
    Path("/usr/share/icons"),
]
available = sorted({
    child.name
    for directory in icon_dirs
    if directory.is_dir()
    for child in directory.iterdir()
    if child.is_dir()
})

def resolve_icon(candidates):
    available_lower = {name.lower(): name for name in available}
    for candidate in candidates:
        found = available_lower.get(candidate.lower())
        if found:
            return found
    wanted = "latte" if active_key == "seven-latte" else "mocha"
    for name in available:
        lowered = name.lower()
        if "catppuccin" in lowered and wanted in lowered:
            return name
    for candidate in candidates:
        found = available_lower.get(candidate.lower())
        if found:
            return found
    return "hicolor"

print(json.dumps({
    "schema": "sevenos.design-engine.status.v1",
    "engine": contract["engine"],
    "active_mode": active_key,
    "system_mode": theme_mode,
    "mode": active,
    "preferred_icon_theme": resolve_icon(active.get("icon_candidates", [])),
    "available_icon_themes": available,
    "icon_strategy": contract["icon_strategy"],
    "folder_roles": contract["folder_roles"],
    "surfaces": contract["surfaces"],
}, indent=2))
PY
}

design_status() {
  SEVENOS_DESIGN_PAYLOAD="$(design_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SEVENOS_DESIGN_PAYLOAD"])
mode = data["mode"]
print("SevenOS Design Engine")
print("=====================")
print()
print(f"Engine:      {data['engine']}")
print(f"Mode:        {mode['label']} ({data['system_mode']})")
print(f"Icons:       {data['preferred_icon_theme']}")
print("Base:        Catppuccin-inspired SevenOS palettes")
print()
print("Surfaces:")
for surface in data["surfaces"]:
    print(f"  - {surface}")
print()
print("Folder roles:")
for key, role in data["folder_roles"].items():
    print(f"  - {role['label']:<8} {role['accent']}  {key}")
print()
print("Next:")
print("  ./install.sh theme dark")
print("  ./install.sh theme light")
PY
}

icons_json() {
  SEVENOS_IDENTITY_ROOT="$ROOT_DIR" python - <<'PY'
import json
from pathlib import Path
import os

root = Path(os.environ["SEVENOS_IDENTITY_ROOT"])
manifest = json.loads((root / "identity" / "icons" / "manifest.json").read_text(encoding="utf-8"))
icons = []
for item in manifest.get("icons", []):
    source = root / "identity" / "icons" / item["file"]
    icons.append({
        **item,
        "source": str(source),
        "present": source.is_file() and source.stat().st_size > 0,
        "install_name": item["name"] + ".svg",
    })
print(json.dumps({
    "schema": "sevenos.icons.status.v1",
    "style": manifest.get("style"),
    "install_target": manifest.get("install_target"),
    "icons": icons,
}, indent=2))
PY
}

icons_status() {
  SEVENOS_ICONS_PAYLOAD="$(icons_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SEVENOS_ICONS_PAYLOAD"])
print("SevenOS Native Icons")
print("====================")
print()
print(f"Style:   {data['style']}")
print(f"Target:  {data['install_target']}")
print()
for item in data["icons"]:
    state = "OK" if item["present"] else "MISS"
    print(f"{state:<5} {item['name']:<16} {item['label']} ({item['role']})")
PY
}

activate_pack() {
  local key="$1"
  if [[ -z "$key" ]]; then
    log_error "Missing accent pack key."
    log_info "Use: seven identity packs"
    exit 1
  fi
  if ! pack_exists "$key"; then
    log_error "Unknown accent pack: $key"
    log_info "Use: seven identity packs"
    exit 1
  fi

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$STATE_DIR"
    printf 'write %q\n' "$IDENTITY_ENV"
    printf 'write %q\n' "$IDENTITY_JSON"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  cat > "$IDENTITY_ENV" <<EOF
SEVENOS_IDENTITY_PACK="$key"
EOF
  current_json > "$IDENTITY_JSON"
  log_success "Active identity pack: $key"
}

packs_json() {
  python - "$ROOT_DIR/identity/accent-packs.json" <<'PY'
import json
import sys
from pathlib import Path

print(json.dumps(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")), indent=2))
PY
}

doctor_json() {
  SEVENOS_IDENTITY_ROOT="$ROOT_DIR" SEVENOS_IDENTITY_CURRENT="$(current_pack_key)" python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["SEVENOS_IDENTITY_ROOT"])
current_key = os.environ.get("SEVENOS_IDENTITY_CURRENT") or "pan-african"

required_files = [
    "identity/CHARTER.md",
    "identity/STYLE.md",
    "identity/design-engine.json",
    "identity/design-engine.css",
    "identity/icons/manifest.json",
    "identity/accent-packs.json",
    "identity/profile-themes.json",
    "identity/components/kente-divider.svg",
    "identity/components/adinkra-status-ok.svg",
    "identity/components/baobab-system-mark.svg",
    "identity/components/griot-doc-mark.svg",
    "identity/components/forge-profile-mark.svg",
    "identity/components/shield-profile-mark.svg",
]


def load_json(rel, fallback):
    try:
        data = json.loads((root / rel).read_text(encoding="utf-8"))
    except Exception:
        return fallback
    return data if isinstance(data, type(fallback)) else fallback


files = []
for rel in required_files:
    path = root / rel
    files.append({
        "path": rel,
        "state": "OK" if path.is_file() and path.stat().st_size > 0 else "MISS",
    })

icon_manifest = load_json("identity/icons/manifest.json", {})
icons = []
for item in icon_manifest.get("icons", []):
    rel = f"identity/icons/{item.get('file', '')}"
    path = root / rel
    icons.append({
        "name": item.get("name", ""),
        "file": item.get("file", ""),
        "state": "OK" if path.is_file() and path.stat().st_size > 0 else "MISS",
    })

accent_packs = load_json("identity/accent-packs.json", {})
packs = accent_packs.get("packs", [])
pack_keys = {item.get("key") for item in packs if isinstance(item, dict)}
profile_themes = load_json("identity/profile-themes.json", {})
profiles = profile_themes.get("profiles", {})
if isinstance(profiles, list):
    profile_count = len(profiles)
elif isinstance(profiles, dict):
    profile_count = len(profiles)
else:
    profile_count = 0

design = load_json("identity/design-engine.json", {})

checks = [
    {
        "key": "required-files",
        "state": "OK" if all(item["state"] == "OK" for item in files) else "MISS",
        "title": "Identity source files",
        "detail": f"{sum(1 for item in files if item['state'] == 'OK')}/{len(files)} files present.",
    },
    {
        "key": "native-icons",
        "state": "OK" if icons and all(item["state"] == "OK" for item in icons) else "MISS",
        "title": "Native SevenOS icons",
        "detail": f"{sum(1 for item in icons if item['state'] == 'OK')}/{len(icons)} icons present.",
    },
    {
        "key": "accent-packs",
        "state": "OK" if accent_packs.get("schema") == "sevenos.accent-packs.v1" and len(packs) >= 3 else "PART",
        "title": "Regional accent packs",
        "detail": f"{len(packs)} pack(s), default={accent_packs.get('default_pack', 'unknown')}.",
    },
    {
        "key": "current-pack",
        "state": "OK" if current_key in pack_keys else "PART",
        "title": "Active identity pack",
        "detail": current_key,
    },
    {
        "key": "design-engine",
        "state": "OK" if design.get("schema") == "sevenos.design-engine.v1" and design.get("modes") else "PART",
        "title": "Design engine",
        "detail": design.get("engine", "unknown"),
    },
    {
        "key": "profile-themes",
        "state": "OK" if profile_themes.get("schema") == "sevenos.profile-themes.v1" and profile_count >= 7 else "PART",
        "title": "Mini OS theme identities",
        "detail": f"{profile_count} profile theme(s).",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
part = sum(1 for item in checks if item["state"] == "PART")
score = round((ok + part * 0.5) / max(len(checks), 1) * 100)
state = "ready" if score >= 90 else "partial" if score >= 70 else "incomplete"

print(json.dumps({
    "schema": "sevenos.identity-doctor.v1",
    "state": state,
    "score": score,
    "current_pack": current_key,
    "checks": checks,
    "files": files,
    "icons": icons,
    "issues": [item for item in checks if item["state"] != "OK"],
    "commands": {
        "status": "seven identity",
        "plan": "seven identity plan",
        "doctor": "seven identity doctor",
        "packs": "seven identity packs",
        "design": "seven identity design",
    },
}, indent=2))
PY
}

doctor() {
  local payload
  payload="$(doctor_json)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '%s\n' "$payload"
  else
    IDENTITY_DOCTOR_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["IDENTITY_DOCTOR_JSON"])
print("SevenOS Identity Doctor")
print("=======================")
print(f"State: {data.get('state')}")
print(f"Score: {data.get('score')}%")
print(f"Pack:  {data.get('current_pack')}")
print()
for item in data.get("checks", []):
    print(f"{item.get('state', 'MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
PY
  fi
  IDENTITY_DOCTOR_JSON="$payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["IDENTITY_DOCTOR_JSON"])
sys.exit(0 if data.get("score", 0) >= 90 else 1)
PY
}

plan() {
  local payload
  payload="$(doctor_json)"
  IDENTITY_DOCTOR_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["IDENTITY_DOCTOR_JSON"])
print("SevenOS Identity Plan")
print("=====================")
print(f"State: {data.get('state')}")
print(f"Score: {data.get('score')}%")
print()
issues = data.get("issues", [])
if not issues:
    print("No identity blockers.")
else:
    for item in issues:
        print(f"- {item.get('title', item.get('key', 'Identity check'))}")
        print(f"  {item.get('detail', '')}")
        print(f"  command: {data.get('commands', {}).get(item.get('key', ''), 'seven identity doctor')}")
PY
}

packs_status() {
  python - "$ROOT_DIR/identity/accent-packs.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print("SevenOS Regional Accent Packs")
print("=============================")
print()
print(f"{'Pack':<18} {'Accent':<8} {'Pattern':<10} {'State'}")
print(f"{'----':<18} {'------':<8} {'-------':<10} {'-----'}")
for item in data.get("packs", []):
    print(f"{item.get('title',''):<18} {item.get('accent',''):<8} {item.get('pattern',''):<10} {item.get('state','')}")
PY
}

status() {
  local active_pack
  active_pack="$(current_pack_key)"
  printf 'SevenOS Visual Identity\n'
  printf '=======================\n\n'
  printf 'Positioning:\n'
  printf '  Next generation intelligent Linux experience for creators, developers and cybersecurity.\n'
  printf '  Tagline: Beyond the Desktop.\n\n'
  printf 'Principles:\n'
  printf '  Fluidity, Transparency, Intelligent minimalism, Depth, Contextuality, Visible security\n\n'
  printf 'Profile language:\n'
  printf '  Baobab  Roots      blue    adaptive base and health\n'
  printf '  Forge   Builder    cyan    code, services, deploy and construction\n'
  printf '  Shield  Guardian   green   audit, sandbox and cyber trust\n'
  printf '  Studio  Maker      violet  creative production\n'
  printf '  Windows Bridge     blue    compatibility without friction\n'
  printf '  Griot   Memory     violet  documentation and knowledge\n'
  printf '\nRegional accent packs:\n'
  printf '  seven identity packs\n'
  printf '  active: %s\n' "$active_pack"
  printf '\nDesign engine:\n'
  printf '  seven identity design\n'
  printf '  seven identity icons\n'
}

ACTION="${1:-status}"
PACK_KEY="${2:-}"
EXTRA_ARGS=()
if [[ "$#" -gt 1 ]]; then
  EXTRA_ARGS=("${@:2}")
fi
JSON_OUTPUT=0
if [[ "${2:-}" == "--json" || "${2:-}" == "json" || "${3:-}" == "--json" || "${3:-}" == "json" ]]; then
  JSON_OUTPUT=1
fi
case "$ACTION" in
  --json|json) json_output ;;
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      json_output
    else
      status
    fi
    ;;
  packs)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      packs_json
    else
      packs_status
    fi
    ;;
  current)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      current_json
    else
      current_status
    fi
    ;;
  design)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      design_json
    else
      design_status
    fi
    ;;
  theme)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      "$ROOT_DIR/scripts/theme-engine.sh" json
    else
      "$ROOT_DIR/scripts/theme-engine.sh" status
    fi
    ;;
  theme-doctor|theme_doctor)
    "$ROOT_DIR/scripts/theme-engine.sh" doctor
    ;;
  visuals)
    shift || true
    "$ROOT_DIR/scripts/visual-packages.sh" "${@:-status}"
    ;;
  icons)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      icons_json
    else
      icons_status
    fi
    ;;
  experience)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      "$ROOT_DIR/scripts/identity-experience.sh" json
    else
      "$ROOT_DIR/scripts/identity-experience.sh" status
    fi
    ;;
  open)
    "$ROOT_DIR/bin/seven-identity-native" "${EXTRA_ARGS[@]}"
    ;;
  activate)
    activate_pack "$PACK_KEY"
    ;;
  plan) plan ;;
  doctor) doctor ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown identity action: $ACTION"; usage; exit 1 ;;
esac
