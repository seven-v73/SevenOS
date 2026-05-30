#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
JSON_OUTPUT=0
ACTION="${1:-status}"

for arg in "$@"; do
  [[ "$arg" == "--json" || "$arg" == "json" ]] && JSON_OUTPUT=1
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

case "$ACTION" in
  status|doctor|json|--json) ;;
  -h|--help|help)
    cat <<'EOF'
SevenOS Workflow Gate

Usage:
  seven workflow-gate [--json]

Validates that public SevenOS actions are exposed as guided workflows with
impact, progress, result, details and recovery instead of raw command jumps.
EOF
    exit 0
    ;;
  *) echo "[SevenOS] Unknown workflow gate action: $ACTION" >&2; exit 1 ;;
esac

payload() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import re
from pathlib import Path
import os

root = Path(os.environ["SEVENOS_ROOT"])


def read(path: str) -> str:
    try:
        return (root / path).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def exists(path: str) -> bool:
    return (root / path).exists()


checks = []


def check(key, ok, title_fr, title_en, detail_fr, detail_en, severity="medium", command=""):
    checks.append({
        "key": key,
        "ok": bool(ok),
        "state": "OK" if ok else "MISS",
        "title_fr": title_fr,
        "title_en": title_en,
        "detail_fr": detail_fr,
        "detail_en": detail_en,
        "severity": severity,
        "command": command,
    })


workflow_json = {}
if exists("identity/workflow-contract.json"):
    try:
        workflow_json = json.loads(read("identity/workflow-contract.json"))
    except Exception:
        workflow_json = {}
check(
    "contract",
    exists("identity/WORKFLOW_CONTRACT.md") and workflow_json.get("schema") == "sevenos.workflow-contract.v1",
    "Contrat de parcours",
    "Workflow contract",
    "Le contrat des parcours publics est versionné.",
    "The public workflow contract is versioned.",
    "high",
    "cat identity/WORKFLOW_CONTRACT.md",
)

settings = read("bin/seven-settings-native")
experience = read("bin/seven-experience-center")
store = read("bin/seven-store-native")
files = read("bin/seven-files-native")
actions = read("scripts/actions.sh")
update = read("scripts/update.sh")

workflow_card_count = settings.count("workflow_card(")
check(
    "settings-workflow-cards",
    workflow_card_count >= 12,
    "Réglages orientés parcours",
    "Workflow-oriented Settings",
    f"{workflow_card_count} cartes de parcours détectées dans Settings.",
    f"{workflow_card_count} workflow cards detected in Settings.",
    "high",
    "seven settings",
)

confirm_count = experience.count("confirm\": True") + experience.count("confirm=True") + experience.count("confirm: True")
check(
    "sensitive-confirmation",
    confirm_count >= 5 and "confirm_and_run" in experience,
    "Actions sensibles confirmées",
    "Sensitive actions confirmed",
    f"{confirm_count} actions confirmées et un runner de confirmation détectés.",
    f"{confirm_count} confirmed actions and a confirmation runner detected.",
    "high",
    "seven experience-center --gui",
)

check(
    "update-workflow",
    all(token in update for token in ("rollback", "last-report", "snapshot", "refresh")) or all(token in actions for token in ("update.rollback", "update.plan", "update.apply")),
    "Mise à jour réversible",
    "Reversible update",
    "La route update expose plan, application, rapport et rollback.",
    "The update route exposes plan, apply, report and rollback.",
    "high",
    "seven update",
)

installer_experience = read("scripts/installer-experience.sh")
installer_native = read("bin/seven-installer-native")
check(
    "installer-experience-flow",
    all(token in installer_experience for token in ("Modern graphical installer", "Automatic hardware detection", "GPU driver guidance", "Preset profiles", "Post-install assistant"))
    and all(token in installer_native for token in ("Start graphical installation", "Starting profiles", "Post-install assistant", "GPU guidance"))
    and all(token in actions for token in ("installer.gui", "installer.experience", "installer.experience_plan")),
    "Installation guidée complète",
    "Complete guided installation",
    "L’installation publique relie installateur graphique, matériel, pilotes GPU, profils et assistant post-install.",
    "The public installation connects graphical installer, hardware, GPU drivers, presets and post-install assistant.",
    "high",
    "seven installer experience",
)

check(
    "mini-os-switch-flow",
    all(token in read("scripts/profile-switch-workflow.sh") for token in ("seven-passage-overlay", "watch", "profile-manager.sh", "ready"))
    and "profile activate" in settings
    and "wait_ready" in json.dumps(workflow_json),
    "Changement Mini OS guidé",
    "Guided Mini OS switching",
    "Le changement passe par intention, overlay Prism et état prêt.",
    "Switching passes through intent, Prism overlay and ready state.",
    "high",
    "seven profile activate forge",
)

check(
    "backup-flow",
    all(token in settings for token in ("backup:wizard", "restore_plan", "Sauvegarde compréhensible")) and "seven recovery backup" in experience,
    "Sauvegarde compréhensible",
    "Understandable backup",
    "Settings et Experience Center exposent portée, sauvegarde et restauration.",
    "Settings and Experience Center expose scope, backup and restore.",
    "high",
    "seven time-machine --gui",
)

check(
    "permissions-flow",
    all(token in experience for token in ("permissions_state", "privacy_report_state", "seven permissions")) and "settings.privacy.workflow" in settings,
    "Permissions lisibles",
    "Readable permissions",
    "Confidentialité et permissions sont regroupées dans des parcours visibles.",
    "Privacy and permissions are grouped into visible journeys.",
    "high",
    "seven permissions --gui",
)

check(
    "equinox-mission-flow",
    all(token in experience for token in ("mission_flow_state", "Equinox Mission Planner", "ready_steps", "handoffs", "Sortie attendue"))
    and all(token in actions for token in ("experience.missions", "experience.mission.direct", "experience.mission.mali_game", "experience.mission.publish_web")),
    "Missions Equinox orchestrées",
    "Orchestrated Equinox missions",
    "Les intentions longues deviennent des parcours multi-mini-OS avec étapes, sorties attendues et préparation visible.",
    "Broad intents become multi-mini-OS routes with steps, expected outputs and visible readiness.",
    "high",
    "seven missions",
)

check(
    "differentiator-flow",
    all(token in experience for token in ("differentiators", "Les 10 piliers SevenOS", "seven differentiators plan"))
    and all(token in actions for token in ("quality.differentiators", "quality.differentiators_center", "quality.differentiators_plan")),
    "Différenciation visible",
    "Visible differentiation",
    "Les piliers produit SevenOS sont lisibles dans le terminal, l’aide et l’Experience Center.",
    "SevenOS product pillars are readable in terminal, help and Experience Center.",
    "high",
    "seven experience-center differentiators",
)

universes = read("scripts/universes.sh")
check(
    "universe-model",
    all(token in universes for token in ("SevenOS Core", "Equinox", "Forge", "Shield", "Baobab", "Pulse", "Studio", "Atlas", "Equinox AI"))
    and all(token in experience for token in ("universes", "Architecture vivante SevenOS", "seven universes", "seven missions"))
    and all(token in actions for token in ("architecture.universes", "architecture.universes_center", "architecture.universes_plan")),
    "Univers SevenOS lisibles",
    "Readable SevenOS universes",
    "Core, Equinox et les sept univers spécialisés sont exposés comme un modèle produit vérifiable.",
    "Core, Equinox and the seven specialized universes are exposed as a verifiable product model.",
    "high",
    "seven universes",
)

check(
    "store-install-flow",
    all(token in store for token in ("self.operation_progress", "show_operation_details", "workflow_panel")) and ("seven-store" in actions or "seven store" in actions),
    "Installation d'apps guidée",
    "Guided app installation",
    "SevenStore expose progression, détails et panneaux de parcours.",
    "SevenStore exposes progress, details and workflow panels.",
    "medium",
    "seven-store",
)

check(
    "files-operation-flow",
    all(token in files for token in ("operation_progress", "show_toast", "Windows", "wine")) or all(token in files for token in ("operation_progress", "toast_revealer")),
    "Fichiers avec feedback",
    "Files with feedback",
    "Seven Files affiche progression et messages calmes pour les opérations.",
    "Seven Files shows progress and calm messages for operations.",
    "medium",
    "seven-files",
)

check(
    "quality-public-flow",
    "quality.public_mode" in actions and "interaction-contract" in read("scripts/public-experience.sh"),
    "Qualité publique intégrée",
    "Integrated public quality",
    "Le mode qualité public agrège interaction, accessibilité et prochain geste.",
    "Public quality mode aggregates interaction, accessibility and next actions.",
    "high",
    "seven quality mode public",
)

raw_external = []
for path in ("bin/seven-settings-native", "bin/seven-experience-center"):
    body = read(path)
    matches = re.findall(r"xdg-open\s+~?/[^\"')]+|xdg-open\s+/[^\"')]+", body)
    raw_external.extend(f"{path}:{item}" for item in matches)
check(
    "raw-external-contained",
    len(raw_external) <= 4,
    "Sorties externes contenues",
    "Contained external escapes",
    f"{len(raw_external)} ouvertures directes de fichiers/dossiers détectées.",
    f"{len(raw_external)} direct file/folder opens detected.",
    "medium",
    "seven workflow-gate",
)

issues = [item for item in checks if not item["ok"]]
ok_count = len(checks) - len(issues)
score = round(ok_count / max(len(checks), 1) * 100)
print(json.dumps({
    "schema": "sevenos.workflow-gate.v1",
    "state": "ready" if not issues else "attention",
    "score": score,
    "summary": {"checks": len(checks), "ok": ok_count, "issues": len(issues)},
    "checks": checks,
    "issues": issues,
    "commands": {
        "workflow": "seven workflow-gate",
        "quality_public": "seven quality mode public",
        "experience": "seven experience-center --gui",
        "settings": "seven settings",
        "update": "seven update"
    }
}, ensure_ascii=False, indent=2))
PY
}

data="$(payload)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$data"
else
  WORKFLOW_JSON="$data" python - <<'PY'
import json
import os

data = json.loads(os.environ["WORKFLOW_JSON"])
print("SevenOS Workflow Gate")
print("=====================")
print(f"State: {data.get('state')} · Score: {data.get('score')}%")
for item in data.get("checks", []):
    label = "OK" if item.get("ok") else "MISS"
    print(f"  {label:<4} {item.get('title_fr')}")
    print(f"       {item.get('detail_fr')}")
PY
fi

WORKFLOW_JSON="$data" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["WORKFLOW_JSON"])
sys.exit(0 if data.get("state") == "ready" else 1)
PY
