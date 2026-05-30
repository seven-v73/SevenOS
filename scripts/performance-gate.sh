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
SevenOS Performance UX Gate

Usage:
  seven performance-gate [--json]

Checks that public native surfaces expose quick feedback, bounded checks,
background workers and calm progress states.
EOF
    exit 0
    ;;
  *) echo "[SevenOS] Unknown performance gate action: $ACTION" >&2; exit 1 ;;
esac

payload() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import re
from pathlib import Path

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


contract = {}
if exists("identity/performance-contract.json"):
    try:
        contract = json.loads(read("identity/performance-contract.json"))
    except Exception:
        contract = {}

check(
    "contract",
    exists("identity/PERFORMANCE_CONTRACT.md") and contract.get("schema") == "sevenos.performance-contract.v1",
    "Contrat performance UX",
    "Performance UX contract",
    "Le contrat de réactivité publique est versionné.",
    "The public responsiveness contract is versioned.",
    "high",
    "cat identity/PERFORMANCE_CONTRACT.md",
)

surface_paths = {
    "settings": "bin/seven-settings-native",
    "files": "bin/seven-files-native",
    "store": "bin/seven-store-native",
    "experience_center": "bin/seven-experience-center",
    "public_studio": "bin/seven-public-studio",
}
surfaces = {key: read(path) for key, path in surface_paths.items()}
shell_experience = read("scripts/shell-experience.sh")

feedback_missing = []
for key, body in surfaces.items():
    has_feedback = any(token in body for token in ("show_feedback", "Gtk.ProgressBar", "Gtk.Spinner", "notify(", "timeout_add"))
    if not has_feedback:
        feedback_missing.append(surface_paths[key])
check(
    "feedback-primitives",
    not feedback_missing,
    "Feedback visible",
    "Visible feedback",
    f"Surfaces sans feedback détecté: {', '.join(feedback_missing) if feedback_missing else 'aucune'}.",
    f"Surfaces without feedback: {', '.join(feedback_missing) if feedback_missing else 'none'}.",
    "high",
    "seven performance-gate",
)

async_missing = []
for key in ("settings", "files", "store"):
    body = surfaces.get(key, "")
    if not any(token in body for token in ("threading.Thread", "subprocess.Popen", "GLib.timeout_add")):
        async_missing.append(surface_paths[key])
check(
    "async-long-actions",
    not async_missing,
    "Actions longues non bloquantes",
    "Non-blocking long actions",
    f"Surfaces sans pattern asynchrone: {', '.join(async_missing) if async_missing else 'aucune'}.",
    f"Surfaces without async pattern: {', '.join(async_missing) if async_missing else 'none'}.",
    "high",
    "seven workflow-gate",
)

bounded_files = ["scripts/public-experience.sh", "bin/seven-public-studio", "bin/seven-experience-center", "scripts/interaction-contract.sh"]
missing_timeout = [path for path in bounded_files if "timeout=" not in read(path) and "timeout" not in read(path)]
check(
    "bounded-public-checks",
    not missing_timeout,
    "Checks publics bornés",
    "Bounded public checks",
    f"Fichiers sans timeout: {', '.join(missing_timeout) if missing_timeout else 'aucun'}.",
    f"Files without timeout: {', '.join(missing_timeout) if missing_timeout else 'none'}.",
    "high",
    "seven quality mode public",
)

files = surfaces.get("files", "")
click_match = re.search(r"CLICK_FEEDBACK_MS\s*=\s*(\d+)", files)
hover_match = re.search(r"HOVER_PREVIEW_DELAY_MS\s*=\s*(\d+)", files)
spring_match = re.search(r"SPRING_OPEN_DELAY_MS\s*=\s*(\d+)", files)
click_ms = int(click_match.group(1)) if click_match else 999
hover_ms = int(hover_match.group(1)) if hover_match else 999
spring_ms = int(spring_match.group(1)) if spring_match else 0
check(
    "files-perceived-latency",
    click_ms <= 200 and hover_ms <= 180 and 450 <= spring_ms <= 900,
    "Seven Files réactif",
    "Responsive Seven Files",
    f"click={click_ms}ms, hover={hover_ms}ms, spring={spring_ms}ms.",
    f"click={click_ms}ms, hover={hover_ms}ms, spring={spring_ms}ms.",
    "medium",
    "seven-files",
)

motion = read("scripts/motion.sh") + read("identity/interaction-contract.json")
check(
    "reduced-motion",
    all(token in motion for token in ("premium", "balanced", "reduced", "latency", "off")),
    "Mouvement contrôlable",
    "Controllable motion",
    "Les modes premium, balanced, reduced, latency et off sont disponibles.",
    "The premium, balanced, reduced, latency and off modes are available.",
    "high",
    "seven motion ux-doctor",
)

sleep_risks = []
sleep_re = re.compile(r"time\.sleep\(\s*([0-9.]+)\s*\)")
for path, body in surfaces.items():
    for match in sleep_re.finditer(body):
        value = float(match.group(1))
        if value > float((contract.get("targets") or {}).get("sleep_max_seconds", 0.5)):
            sleep_risks.append(f"{surface_paths[path]}: time.sleep({value})")
check(
    "short-intentional-waits",
    not sleep_risks,
    "Attentes courtes",
    "Short waits",
    f"Attentes longues détectées: {', '.join(sleep_risks) if sleep_risks else 'aucune'}.",
    f"Long waits detected: {', '.join(sleep_risks) if sleep_risks else 'none'}.",
    "medium",
    "seven performance-gate",
)

progress_sources = sum(1 for body in surfaces.values() if "Gtk.ProgressBar" in body or "Gtk.Spinner" in body)
check(
    "progress-surfaces",
    progress_sources >= 3,
    "Progression visible",
    "Visible progress",
    f"{progress_sources}/5 surfaces exposent ProgressBar ou Spinner.",
    f"{progress_sources}/5 surfaces expose ProgressBar or Spinner.",
    "medium",
    "seven performance-gate",
)

warmup_targets = {
    "spotlight": "bin/seven-spotlight",
    "apps": "bin/seven-apps",
    "launchpad": "bin/seven-launchpad-native",
    "store": "bin/seven-store-native",
    "profiles": "profiles/profile-manager.sh",
    "home": "bin/seven-home-native",
    "motion": "scripts/motion.sh",
    "theme": "scripts/theme-session.sh",
    "state": "scripts/state.sh",
}
missing_warmup = [name for name, token in warmup_targets.items() if token not in shell_experience]
check(
    "session-warmup-coverage",
    not missing_warmup and "SEVENOS_EXPERIENCE_SILENT_WARMUP" in read("bin/seven-session") and "SEVENOS_EXPERIENCE_SILENT_WARMUP" in read("systemd/user/sevenos-shell-experience.service"),
    "Préchauffage de session complet",
    "Complete session warmup",
    f"Cibles manquantes: {', '.join(missing_warmup) if missing_warmup else 'aucune'}.",
    f"Missing targets: {', '.join(missing_warmup) if missing_warmup else 'none'}.",
    "high",
    "seven experience warmup",
)

issues = [item for item in checks if not item["ok"]]
ok_count = len(checks) - len(issues)
score = round(ok_count / max(len(checks), 1) * 100)
print(json.dumps({
    "schema": "sevenos.performance-gate.v1",
    "state": "ready" if not issues else "attention",
    "score": score,
    "summary": {"checks": len(checks), "ok": ok_count, "issues": len(issues)},
    "checks": checks,
    "issues": issues,
    "findings": {
        "feedback_missing": feedback_missing,
        "async_missing": async_missing,
        "missing_timeout": missing_timeout,
        "sleep_risks": sleep_risks,
    },
    "commands": {
        "performance": "seven performance-gate",
        "workflow": "seven workflow-gate",
        "layout": "seven layout-gate",
        "public_studio": "seven public-studio --gui"
    }
}, ensure_ascii=False, indent=2))
PY
}

data="$(payload)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$data"
else
  PERFORMANCE_JSON="$data" python - <<'PY'
import json
import os

data = json.loads(os.environ["PERFORMANCE_JSON"])
print("SevenOS Performance UX Gate")
print("===========================")
print(f"State: {data.get('state')} · Score: {data.get('score')}%")
for item in data.get("checks", []):
    label = "OK" if item.get("ok") else "MISS"
    print(f"  {label:<4} {item.get('title_fr')}")
    print(f"       {item.get('detail_fr')}")
PY
fi

PERFORMANCE_JSON="$data" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["PERFORMANCE_JSON"])
sys.exit(0 if data.get("state") == "ready" else 1)
PY
