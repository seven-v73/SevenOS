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
  seven identity activate <pack>
  ./scripts/identity.sh [status|json|doctor]

Shows the African first product language used by profiles, onboarding, Hub and
future accent packs.
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
        "accent": "baobab",
        "symbol": "baobab-system-mark",
        "principle": "stability",
        "story": "The rooted base: system health, identity, desktop and daily trust.",
    },
    {
        "key": "forge",
        "title": "Forge",
        "role": "Builder",
        "accent": "gold",
        "symbol": "forge-profile-mark",
        "principle": "creation through skill",
        "story": "The builder space: code, learning, containers and productive power.",
    },
    {
        "key": "shield",
        "title": "Shield",
        "role": "Guardian",
        "accent": "indigo",
        "symbol": "shield-profile-mark",
        "principle": "visible protection",
        "story": "The guardian space: audit, sandbox, forensics and careful defense.",
    },
    {
        "key": "studio",
        "title": "Studio",
        "role": "Maker",
        "accent": "clay",
        "symbol": "motif-diamond",
        "principle": "expressive production",
        "story": "The maker space: image, sound, motion, 3D and cultural output.",
    },
    {
        "key": "windows",
        "title": "Windows",
        "role": "Bridge",
        "accent": "baobab",
        "symbol": "motif-cross",
        "principle": "compatibility without surrender",
        "story": "The bridge space: Windows apps inside a Linux-first life.",
    },
    {
        "key": "horizon",
        "title": "Horizon",
        "role": "Navigator",
        "accent": "indigo",
        "symbol": "motif-stripe",
        "principle": "deployment and reach",
        "story": "The navigator space: servers, networks, deployment and personal cloud.",
    },
    {
        "key": "griot",
        "title": "Griot",
        "role": "Memory",
        "accent": "gold",
        "symbol": "griot-doc-mark",
        "principle": "transmission",
        "story": "The memory layer: docs, notes, logs, explanation and knowledge transfer.",
    },
]

print(json.dumps({
    "schema": "sevenos.identity.v1",
    "positioning": "African first Linux ecosystem for sovereignty, creation, security and deployment.",
    "question": "Does this make Linux more sovereign, more fluid and more culturally coherent?",
    "current_pack": current_pack,
    "principles": [
        {"key": "sovereignty", "label": "Sovereignty", "meaning": "SevenOS explains, repairs and owns its system path."},
        {"key": "transmission", "label": "Transmission", "meaning": "Knowledge is surfaced through Griot-style documentation and onboarding."},
        {"key": "creation", "label": "Creation", "meaning": "Forge and Studio are first-class work modes."},
        {"key": "protection", "label": "Protection", "meaning": "Shield makes trust visible and guided."},
        {"key": "community", "label": "Community", "meaning": "Profiles and future accent packs invite shared extension."},
        {"key": "resilience", "label": "Resilience", "meaning": "State, repair, migration and backups are observable."},
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

doctor() {
  local missing=0
  local file

  for file in \
    "$ROOT_DIR/identity/AFRICAN_FIRST.md" \
    "$ROOT_DIR/identity/accent-packs.json" \
    "$ROOT_DIR/identity/components/kente-divider.svg" \
    "$ROOT_DIR/identity/components/adinkra-status-ok.svg" \
    "$ROOT_DIR/identity/components/baobab-system-mark.svg" \
    "$ROOT_DIR/identity/components/griot-doc-mark.svg" \
    "$ROOT_DIR/identity/components/forge-profile-mark.svg" \
    "$ROOT_DIR/identity/components/shield-profile-mark.svg"; do
    if [[ -s "$file" ]]; then
      printf '[OK] %s\n' "${file#"$ROOT_DIR/"}"
    else
      printf '[MISS] %s\n' "${file#"$ROOT_DIR/"}"
      missing=$((missing + 1))
    fi
  done

  if [[ "$missing" -gt 0 ]]; then
    log_error "African first identity layer is incomplete."
    exit 1
  fi

  log_success "African first identity layer is present."
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
  printf 'SevenOS African First Identity\n'
  printf '==============================\n\n'
  printf 'Positioning:\n'
  printf '  African first Linux ecosystem for sovereignty, creation, security and deployment.\n\n'
  printf 'Principles:\n'
  printf '  Sovereignty, Transmission, Creation, Protection, Community, Resilience\n\n'
  printf 'Profile language:\n'
  printf '  Baobab  Roots      baobab  stable base and health\n'
  printf '  Forge   Builder    gold    code, learning and construction\n'
  printf '  Shield  Guardian   indigo  audit, sandbox and trust\n'
  printf '  Studio  Maker      clay    creative production\n'
  printf '  Windows Bridge     baobab  compatibility without surrender\n'
  printf '  Horizon Navigator  indigo  deploy, network and cloud\n'
  printf '  Griot   Memory     gold    documentation and knowledge\n'
  printf '\nRegional accent packs:\n'
  printf '  seven identity packs\n'
  printf '  active: %s\n' "$active_pack"
}

ACTION="${1:-status}"
PACK_KEY="${2:-}"
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
  activate)
    activate_pack "$PACK_KEY"
    ;;
  doctor) doctor ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown identity action: $ACTION"; usage; exit 1 ;;
esac
