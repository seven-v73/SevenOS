#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"

ACTION="${1:-status}"
JSON_OUTPUT=0
case "${2:-}" in
  --json|json) JSON_OUTPUT=1 ;;
esac
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

file_has() {
  local path="$1" pattern="$2"
  [[ -s "$ROOT_DIR/$path" ]] && grep -Eq "$pattern" "$ROOT_DIR/$path"
}

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/identity"
REPORT_JSON="$STATE_DIR/identity-experience.json"

command_json() {
  local fallback="$1"
  shift
  "$@" 2>/dev/null || printf '%s\n' "$fallback"
}

experience_json() {
  local surfaces_json
  surfaces_json="$(command_json '{"score":0,"summary":{}}' "$ROOT_DIR/scripts/surfaces.sh" json)"
  SURFACES_JSON="$surfaces_json" ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
lang = os.environ.get("LANG", "").lower()
is_fr = lang.startswith("fr")


def tr(fr, en):
    return fr if is_fr else en

try:
    surfaces = json.loads(os.environ.get("SURFACES_JSON", "{}"))
except json.JSONDecodeError:
    surfaces = {}


def has(path, *needles):
    target = root / path
    if not target.exists():
        return False
    text = target.read_text(encoding="utf-8", errors="ignore")
    return all(needle in text for needle in needles)


def exists(path):
    return (root / path).exists()


surface_summary = surfaces.get("summary") if isinstance(surfaces.get("summary"), dict) else {}
surface_score = int(surfaces.get("score", 0) or 0)
legacy_blockers = int(surface_summary.get("legacy_blockers", 0) or 0)

checks = [
    {
        "key": "prism-symbol",
        "title": tr("Le Prism Seven est la marque système", "Seven Prism is the system mark"),
        "state": "OK" if exists("identity/assets/symbol-seven-prism.svg") else "MISS",
        "detail": tr("L'asset Prism existe et peut ancrer les surfaces du shell.", "The Prism asset exists and can anchor shell surfaces."),
        "command": "ls identity/assets/symbol-seven-prism.svg",
    },
    {
        "key": "welcome-identity",
        "title": tr("L'accueil porte l'identité SevenOS", "Welcome surface carries identity"),
        "state": "OK" if has("bin/seven-welcome-popup", "prism_logo_path", "status-strip", "Mise à jour") else "MISS",
        "detail": tr("Le premier démarrage expose Prism, langue, thème, profil, update et aide.", "First boot shows Prism, language/theme/profile/update and help."),
        "command": "seven-welcome-popup",
    },
    {
        "key": "profile-prism",
        "title": tr("Les mini OS sont reliés dans un même Prism", "Mini OS are explained as one Prism"),
        "state": "OK" if has("bin/seven-profile-center-native", "prism", "Equinox", "profile") else "MISS",
        "detail": tr("Le centre des espaces présente Equinox et les mini OS comme une identité connectée.", "Profile Center presents Equinox and mini OS as one connected identity."),
        "command": "seven-profile-center-native",
    },
    {
        "key": "native-surfaces",
        "title": tr("Les surfaces publiques sont natives et finalisées", "Public surfaces are native and productized"),
        "state": "OK" if surface_score >= 95 and legacy_blockers == 0 else "PART",
        "detail": tr(f"Score surfaces {surface_score}%; {legacy_blockers} ancien(s) écran(s) bloquant(s).", f"{surface_score}% surfaces score; {legacy_blockers} legacy blocker(s)."),
        "command": "seven surfaces doctor",
    },
    {
        "key": "language-layer",
        "title": tr("La langue système atteint les surfaces du shell", "System language reaches shell surfaces"),
        "state": "OK" if has("scripts/seven_i18n.py", "fr", "en") and has("bin/seven-quick-settings-native", "tr_text") else "MISS",
        "detail": tr("Les surfaces principales utilisent les helpers de langue SevenOS.", "Core surfaces use SevenOS language helpers instead of fixed strings."),
        "command": "seven language status",
    },
    {
        "key": "theme-engine",
        "title": tr("Les thèmes clair et sombre partagent le même moteur", "Dark and light modes share one design engine"),
        "state": "OK" if has("scripts/seven_theme.py", "current_theme_mode") and exists("identity/tokens-light.css") else "MISS",
        "detail": tr("L'OS utilise des tokens partagés pour le clair doux et le sombre premium.", "The OS has shared tokens for soft light and premium dark mode."),
        "command": "seven theme doctor",
    },
    {
        "key": "control-center",
        "title": tr("Les contrôles quotidiens ressemblent à des surfaces OS", "Daily controls feel like OS surfaces"),
        "state": "OK" if has("bin/seven-quick-settings-native", "control_center_css", "clear_notifications") else "MISS",
        "detail": tr("Wi-Fi, notifications, audio et énergie vivent dans une surface native unique.", "Wi-Fi, notifications, audio and power sit inside one native control surface."),
        "command": "seven-quick-settings",
    },
    {
        "key": "update-release-guidance",
        "title": tr("La maintenance est guidée façon SevenOS", "Maintenance is SevenOS-branded"),
        "state": "OK" if has("scripts/update.sh", "sevenos.update-report.v1") and has("bin/seven-release-review-native", "SevenOS Release Review") else "MISS",
        "detail": tr("Update et release freeze produisent rapports et guidage natif.", "Update and release freeze have reports and native guidance."),
        "command": "seven update check && seven release open",
    },
    {
        "key": "fallback-discipline",
        "title": tr("Les fallbacks ne dominent pas l'expérience publique", "Fallbacks do not dominate the public experience"),
        "state": "OK" if legacy_blockers == 0 else "PART",
        "detail": tr("Les fallbacks rofi/terminal restent derrière les surfaces natives publiques.", "Rofi/terminal fallbacks remain behind native public surfaces."),
        "command": "seven surfaces doctor",
    },
]

ok = sum(1 for item in checks if item["state"] == "OK")
partial = sum(1 for item in checks if item["state"] == "PART")
score = round(((ok + partial * 0.5) / max(len(checks), 1)) * 100)
issues = [item for item in checks if item["state"] != "OK"]

print(json.dumps({
    "schema": "sevenos.identity-experience.v1",
    "state": "signature-ready" if score >= 92 and not issues else "identity-needs-polish" if score >= 75 else "identity-fragmented",
    "score": score,
    "signature_ready": score >= 92 and not issues,
    "positioning": tr("SevenOS doit se ressentir comme une identité OS cohérente, pas comme un ensemble de scripts.", "SevenOS should feel like a coherent OS identity, not a bundle of scripts."),
    "principles": [
        tr("Prism d'abord", "Prism first"),
        tr("surfaces natives avant sortie terminal", "native surfaces before terminal output"),
        tr("langue système partout", "language-aware everywhere"),
        tr("parité clair doux et sombre premium", "soft light and premium dark parity"),
        tr("contexte profil visible mais calme", "profile context visible but calm"),
        tr("maintenance avec rapports et rollback", "maintenance flows with reports and rollback"),
    ],
    "checks": checks,
    "issues": issues,
    "commands": {
        "status": "seven identity experience",
        "json": "seven identity experience --json",
        "surfaces": "seven surfaces doctor",
        "design": "scripts/design-check.sh",
        "quality": "seven quality doctor",
    },
}, indent=2, ensure_ascii=False))
PY
}

print_human() {
  IDENTITY_EXPERIENCE_JSON="$1" REPORT_JSON="$REPORT_JSON" python - <<'PY'
import json
import os

data = json.loads(os.environ["IDENTITY_EXPERIENCE_JSON"])
is_fr = os.environ.get("LANG", "").lower().startswith("fr")
title = "Expérience d'identité SevenOS" if is_fr else "SevenOS Identity Experience"
state_label = "État" if is_fr else "State"
score_label = "Score"
report_label = "Rapport" if is_fr else "Report"
print(title)
print("=" * len(title))
print(f"{state_label}: {data.get('state')}")
print(f"{score_label}: {data.get('score')}%")
print()
for item in data.get("checks", []):
    print(f"{item.get('state', 'MISS'):<4} {item.get('title')}")
    print(f"     {item.get('detail')}")
print()
print(f"{report_label}: {os.environ.get('REPORT_JSON')}")
PY
}

payload="$(experience_json)"
mkdir -p "$STATE_DIR"
printf '%s\n' "$payload" >"$REPORT_JSON"
case "$ACTION" in
  status|doctor|json|experience)
    if [[ "$JSON_OUTPUT" -eq 1 || "$ACTION" == "json" ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  *)
    printf 'Usage: seven identity experience [--json]\n' >&2
    exit 1
    ;;
esac
