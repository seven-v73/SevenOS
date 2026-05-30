#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
ACTION="${1:-status}"
JSON_OUTPUT=0
REFRESH_CACHE="${SEVENOS_INTERACTION_GATE_REFRESH:-0}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
INTERACTION_CACHE="$CACHE_DIR/interaction-${ACTION}.json"
INTERACTION_CACHE_TTL="${SEVENOS_INTERACTION_GATE_CACHE_TTL:-300}"

for arg in "$@"; do
  [[ "$arg" == "--json" || "$arg" == "json" ]] && JSON_OUTPUT=1
  [[ "$arg" == "--refresh" || "$arg" == "--no-cache" ]] && REFRESH_CACHE=1
done
[[ "$ACTION" == "--json" || "$ACTION" == "--refresh" || "$ACTION" == "--no-cache" ]] && ACTION="status"
INTERACTION_CACHE="$CACHE_DIR/interaction-${ACTION}.json"

usage() {
  cat <<'EOF'
SevenOS Interaction Contract

Usage:
  seven interaction-gate [--json]
  seven accessibility-gate [--json]
  scripts/interaction-contract.sh [status|accessibility|motion|public] [--json]

Validates the public interaction, accessibility and motion contract used by
SevenOS native surfaces.
EOF
}

case "$ACTION" in
  status|json|accessibility|motion|public|doctor) ;;
  -h|--help|help) usage; exit 0 ;;
  --json) ACTION="status"; JSON_OUTPUT=1 ;;
  *) echo "[SevenOS] Unknown interaction contract action: $ACTION" >&2; usage; exit 1 ;;
esac
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

payload() {
  SEVENOS_ROOT="$ROOT_DIR" SEVENOS_CONTRACT_ACTION="$ACTION" python - <<'PY'
import json
import os
import re
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
action = os.environ.get("SEVENOS_CONTRACT_ACTION", "status")


def exists(path: str) -> bool:
    return (root / path).exists()


def text(path: str) -> str:
    try:
        return (root / path).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def run_json(command, fallback=None, timeout=30):
    fallback = fallback or {}
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
            env={**os.environ, "SEVENOS_ROOT": str(root)},
        )
    except Exception:
        return fallback
    try:
        data = json.loads(result.stdout)
    except Exception:
        return fallback
    return data if isinstance(data, dict) else fallback


checks = []


def check(key, ok, title_fr, title_en, detail_fr, detail_en, severity="medium", command=""):
    state = "OK" if ok else "MISS"
    item = {
        "key": key,
        "state": state,
        "ok": bool(ok),
        "title_fr": title_fr,
        "title_en": title_en,
        "detail_fr": detail_fr,
        "detail_en": detail_en,
        "severity": severity,
        "command": command,
    }
    checks.append(item)


contract_ok = exists("identity/INTERACTION_CONTRACT.md") and exists("identity/interaction-contract.json")
contract_json = {}
if exists("identity/interaction-contract.json"):
    try:
        contract_json = json.loads(text("identity/interaction-contract.json"))
    except Exception:
        contract_json = {}
check(
    "contract-files",
    contract_ok and contract_json.get("schema") == "sevenos.interaction-contract.v1",
    "Contrat d'interaction",
    "Interaction contract",
    "Le contrat SevenOS public est versionné dans identity/.",
    "The public SevenOS contract is versioned under identity/.",
    "high",
    "cat identity/INTERACTION_CONTRACT.md",
)

required_surfaces = {
    "settings": "bin/seven-settings-native",
    "files": "bin/seven-files-native",
    "store": "bin/seven-store-native",
    "public_studio": "bin/seven-public-studio",
    "experience": "bin/seven-experience-center",
    "prism": "bin/seven-window-controls-native",
}
missing_surfaces = [name for name, path in required_surfaces.items() if not exists(path)]
check(
    "surface-coverage",
    not missing_surfaces,
    "Surfaces publiques couvertes",
    "Public surfaces covered",
    f"Surfaces manquantes: {', '.join(missing_surfaces) if missing_surfaces else 'aucune'}.",
    f"Missing surfaces: {', '.join(missing_surfaces) if missing_surfaces else 'none'}.",
    "high",
    "seven surfaces doctor",
)

theme_files = [path for path in required_surfaces.values() if exists(path)]
theme_hits = [path for path in theme_files if "seven_theme" in text(path) or "gtk_app_css" in text(path)]
check(
    "theme-tokens",
    len(theme_hits) >= 4,
    "Thèmes tokenisés",
    "Tokenized themes",
    f"{len(theme_hits)}/{len(theme_files)} surfaces référencent les tokens SevenOS.",
    f"{len(theme_hits)}/{len(theme_files)} surfaces reference SevenOS tokens.",
    "high",
    "seven theme doctor",
)

localized_hits = [path for path in theme_files if re.search(r"\b(tr|t|tx|tr_text)\(", text(path))]
check(
    "localized-copy",
    len(localized_hits) >= 5,
    "Textes publics localisés",
    "Localized public copy",
    f"{len(localized_hits)}/{len(theme_files)} surfaces exposent un helper FR/EN.",
    f"{len(localized_hits)}/{len(theme_files)} surfaces expose a FR/EN helper.",
    "high",
    "seven help language",
)

tooltip_hits = 0
button_hits = 0
for path in theme_files:
    body = text(path)
    button_hits += body.count("Gtk.Button")
    tooltip_hits += body.count("set_tooltip_text") + body.count("tooltip")
check(
    "control-feedback",
    button_hits == 0 or tooltip_hits >= max(8, button_hits // 5),
    "Contrôles compréhensibles",
    "Understandable controls",
    f"{tooltip_hits} indices tooltip/label pour {button_hits} boutons GTK détectés.",
    f"{tooltip_hits} tooltip/label signals for {button_hits} detected GTK buttons.",
    "medium",
    "seven accessibility-gate",
)

bad_color_hits = []
for path in theme_files:
    body = text(path)
    if re.search(r"#[0-9A-Fa-f]{6}", body) and "@seven_" not in body and "seven_theme" not in body:
        bad_color_hits.append(path)
check(
    "hardcoded-color-risk",
    not bad_color_hits,
    "Couleurs publiques contrôlées",
    "Controlled public colors",
    f"Surfaces à inspecter: {', '.join(bad_color_hits) if bad_color_hits else 'aucune'}.",
    f"Surfaces to inspect: {', '.join(bad_color_hits) if bad_color_hits else 'none'}.",
    "medium",
    "seven visual-gate",
)

motion_body = text("scripts/motion.sh") + "\n" + text("hyprland/conf/sevenos-motion.conf")
motion_ok = all(token in motion_body for token in ("premium", "balanced", "reduced", "latency", "off")) and "sevenMotion" in motion_body
check(
    "motion-system",
    motion_ok,
    "Système de mouvement",
    "Motion system",
    "Les presets premium/balanced/reduced/latency/off sont disponibles.",
    "The premium/balanced/reduced/latency/off presets are available.",
    "high",
    "seven motion ux-doctor",
)

focus_sources = {
    "shared": text("scripts/seven_theme.py"),
    "settings": text("identity/native/settings.css"),
    "files": text("identity/native/files.css"),
    "store": text("identity/native/store.css"),
}
focus_hits = []
for name, body in focus_sources.items():
    if ":focus" in body and ("box-shadow" in body or "border-color" in body) and "@seven_accent" in body:
        focus_hits.append(name)
check(
    "keyboard-focus-visible",
    "shared" in focus_hits and len(focus_hits) >= 2,
    "Focus clavier visible",
    "Visible keyboard focus",
    f"{len(focus_hits)}/{len(focus_sources)} sources exposent un état focus tokenisé.",
    f"{len(focus_hits)}/{len(focus_sources)} sources expose a tokenized focus state.",
    "high",
    "seven accessibility-gate",
)

public_studio = run_json([str(root / "bin/seven-public-studio"), "visual", "--json"], {"score": 0, "state": "unknown"}, timeout=70)
visual_score = int(public_studio.get("score", 0) or 0)
check(
    "visual-gate",
    visual_score >= 92,
    "Gate visuel public",
    "Public visual gate",
    f"{public_studio.get('state', 'unknown')} à {visual_score}%.",
    f"{public_studio.get('state', 'unknown')} at {visual_score}%.",
    "high",
    "seven visual-gate",
)

surfaces = run_json([str(root / "scripts/surfaces.sh"), "json"], {"score": 0, "summary": {}}, timeout=25)
summary = surfaces.get("summary") if isinstance(surfaces.get("summary"), dict) else {}
surface_score = int(surfaces.get("score", 0) or 0)
legacy = int(summary.get("legacy_blockers", 0) or 0)
check(
    "native-surfaces",
    surface_score >= 95 and legacy == 0,
    "Surfaces natives",
    "Native surfaces",
    f"{surface_score}% · anciens écrans bloquants: {legacy}.",
    f"{surface_score}% · legacy blockers: {legacy}.",
    "high",
    "seven surfaces doctor",
)

install_hooks = text("scripts/install-cli.sh") + "\n" + text("scripts/system-install.sh") + "\n" + text("scripts/new-device.sh")
check(
    "new-device-availability",
    "seven-public-studio" in install_hooks and "install_user_command" in install_hooks and exists("scripts/workflow-gate.sh"),
    "Disponible sur nouvelle machine",
    "Available on new machines",
    "Les commandes qualité publiques sont branchées dans l'installation CLI.",
    "Public quality commands are wired into CLI installation.",
    "high",
    "./install.sh cli",
)

scope = {"status": checks, "doctor": checks, "public": checks}
if action == "accessibility":
    scope = {"accessibility": [item for item in checks if item["key"] in {"localized-copy", "control-feedback", "hardcoded-color-risk", "keyboard-focus-visible", "visual-gate", "native-surfaces"}]}
elif action == "motion":
    scope = {"motion": [item for item in checks if item["key"] in {"motion-system", "visual-gate"}]}
selected = next(iter(scope.values()))
issues = [item for item in selected if not item["ok"]]
ok_count = len(selected) - len(issues)
score = round(ok_count / max(len(selected), 1) * 100)
state = "ready" if not issues else "attention"
print(json.dumps({
    "schema": "sevenos.interaction-gate.v1",
    "action": action,
    "state": state,
    "score": score,
    "summary": {"checks": len(selected), "ok": ok_count, "issues": len(issues)},
    "checks": selected,
    "issues": issues,
    "commands": {
        "public": "seven quality mode public",
        "accessibility": "seven accessibility-gate",
        "interaction": "seven interaction-gate",
        "motion": "seven motion ux-doctor",
        "visual": "seven visual-gate"
    }
}, ensure_ascii=False, indent=2))
PY
}

json_cache_valid() {
  python -m json.tool "$1" >/dev/null 2>&1
}

cache_is_fresh() {
  local path="$1" ttl="$2" now mtime
  [[ "$REFRESH_CACHE" == 1 ]] && return 1
  [[ -s "$path" ]] || return 1
  json_cache_valid "$path" || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || printf 0)"
  [[ $(( now - mtime )) -lt "$ttl" ]]
}

write_json_cache() {
  local path="$1" tmp
  mkdir -p "$(dirname "$path")"
  tmp="$path.tmp.$$"
  cat >"$tmp"
  if json_cache_valid "$tmp"; then
    mv -f "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
}

cached_payload() {
  local data
  if cache_is_fresh "$INTERACTION_CACHE" "$INTERACTION_CACHE_TTL"; then
    cat "$INTERACTION_CACHE"
    return 0
  fi
  data="$(payload)"
  printf '%s\n' "$data" | write_json_cache "$INTERACTION_CACHE" || true
  printf '%s\n' "$data"
}

data="$(cached_payload)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$data"
else
  CONTRACT_JSON="$data" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTRACT_JSON"])
print("SevenOS Interaction Gate")
print("========================")
print(f"State: {data.get('state')} · Score: {data.get('score')}%")
for item in data.get("checks", []):
    label = "OK" if item.get("ok") else "MISS"
    print(f"  {label:<4} {item.get('title_fr')}")
    print(f"       {item.get('detail_fr')}")
PY
fi

CONTRACT_JSON="$data" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["CONTRACT_JSON"])
sys.exit(0 if data.get("state") == "ready" else 1)
PY
