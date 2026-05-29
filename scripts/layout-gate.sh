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
SevenOS Layout Gate

Usage:
  seven layout-gate [--json]

Scans public native surfaces for oversized windows, missing scroll regions and
layout risks that would make SevenOS feel less polished on laptop displays.
EOF
    exit 0
    ;;
  *) echo "[SevenOS] Unknown layout gate action: $ACTION" >&2; exit 1 ;;
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


contract = {}
if exists("identity/layout-contract.json"):
    try:
        contract = json.loads(read("identity/layout-contract.json"))
    except Exception:
        contract = {}
check(
    "contract",
    exists("identity/LAYOUT_CONTRACT.md") and contract.get("schema") == "sevenos.layout-contract.v1",
    "Contrat layout",
    "Layout contract",
    "Le contrat de tailles et scroll est versionné.",
    "The sizing and scrolling contract is versioned.",
    "high",
    "cat identity/LAYOUT_CONTRACT.md",
)

surface_paths = {
    "settings": "bin/seven-settings-native",
    "files": "bin/seven-files-native",
    "store": "bin/seven-store-native",
    "public_studio": "bin/seven-public-studio",
    "experience_center": "bin/seven-experience-center",
}

default_size_re = re.compile(r"set_default_size\(\s*(\d+)\s*,\s*(\d+)\s*\)")
min_size_re = re.compile(r"set_size_request\(\s*(\d+)\s*,\s*(\d+|-1)\s*\)|min-width\s*:\s*(\d+)px|min-height\s*:\s*(\d+)px", re.I)
oversized = []
missing_scroll = []
dialog_risks = []

targets = contract.get("public_targets", {}) if isinstance(contract.get("public_targets"), dict) else {}
for key, path in surface_paths.items():
    body = read(path)
    target = targets.get(key, {}) if isinstance(targets.get(key), dict) else {}
    max_w = int(target.get("max_default_width", 1180))
    max_h = int(target.get("max_default_height", 760))
    for match in default_size_re.finditer(body):
        width = int(match.group(1))
        height = int(match.group(2))
        if width > max_w or height > max_h:
            oversized.append(f"{path}: set_default_size({width}, {height}) > {max_w}x{max_h}")
    for match in min_size_re.finditer(body):
        values = [item for item in match.groups() if item and item != "-1"]
        for raw in values:
            value = int(raw)
            if value > 1180:
                oversized.append(f"{path}: fixed size {value}px")
    if target.get("requires_scroll") and "Gtk.ScrolledWindow" not in body and "ScrolledWindow" not in body:
        missing_scroll.append(path)
    for match in re.finditer(r"Gtk\.Dialog|set_default_size\(\s*(\d+)\s*,\s*(\d+)\s*\)", body):
        pass

dialog_re = re.compile(r"dialog\.set_default_size\(\s*(\d+)\s*,\s*(\d+)\s*\)|Gtk\.Dialog")
for key, path in surface_paths.items():
    body = read(path)
    for match in re.finditer(r"dialog\.set_default_size\(\s*(\d+)\s*,\s*(\d+)\s*\)", body):
        width = int(match.group(1))
        height = int(match.group(2))
        if width > 760 or height > 540:
            dialog_risks.append(f"{path}: dialog {width}x{height}")

check(
    "default-window-size",
    not oversized,
    "Tailles de fenêtres contrôlées",
    "Controlled window sizes",
    f"{len(oversized)} risque(s) de fenêtre trop large.",
    f"{len(oversized)} oversized window risk(s).",
    "high",
    "seven layout-gate",
)
check(
    "scrollable-dense-surfaces",
    not missing_scroll,
    "Surfaces denses scrollables",
    "Scrollable dense surfaces",
    f"Sans scroll détecté: {', '.join(missing_scroll) if missing_scroll else 'aucune'}.",
    f"Missing scroll: {', '.join(missing_scroll) if missing_scroll else 'none'}.",
    "high",
    "seven layout-gate",
)
check(
    "compact-dialogs",
    len(dialog_risks) <= 2,
    "Dialogues compacts",
    "Compact dialogs",
    f"{len(dialog_risks)} dialogue(s) au-dessus de la cible 760x540.",
    f"{len(dialog_risks)} dialog(s) above the 760x540 target.",
    "medium",
    "seven layout-gate",
)

files = read("bin/seven-files-native")
files_default = re.search(r"DEFAULT_WINDOW_SIZE\s*=\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)", files)
files_comfort = re.search(r"COMFORT_WINDOW_SIZE\s*=\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)", files)
files_default_ok = False
if files_default:
    files_default_ok = int(files_default.group(1)) <= 760 and int(files_default.group(2)) <= 560
files_comfort_ok = False
if files_comfort:
    files_comfort_ok = int(files_comfort.group(1)) <= 980 and int(files_comfort.group(2)) <= 640
check(
    "files-compact-target",
    (
        (
            "set_default_size(900, 560)" in files
            or "set_default_size(920, 560)" in files
            or "set_default_size(960, 600)" in files
            or ("set_default_size(*screen_window_size())" in files and files_default_ok and files_comfort_ok)
        )
        and "Gtk.ScrolledWindow" in files
    ),
    "Seven Files compact",
    "Compact Seven Files",
    "Seven Files garde une taille Finder-like avec contenu scrollable.",
    "Seven Files keeps a Finder-like size with scrollable content.",
    "high",
    "seven-files",
)

issues = [item for item in checks if not item["ok"]]
ok_count = len(checks) - len(issues)
score = round(ok_count / max(len(checks), 1) * 100)
print(json.dumps({
    "schema": "sevenos.layout-gate.v1",
    "state": "ready" if not issues else "attention",
    "score": score,
    "summary": {"checks": len(checks), "ok": ok_count, "issues": len(issues)},
    "checks": checks,
    "issues": issues,
    "findings": {
        "oversized": oversized[:12],
        "missing_scroll": missing_scroll,
        "dialog_risks": dialog_risks[:12],
    },
    "commands": {
        "layout": "seven layout-gate",
        "visual": "seven visual-gate",
        "public_studio": "seven public-studio --gui"
    }
}, ensure_ascii=False, indent=2))
PY
}

data="$(payload)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$data"
else
  LAYOUT_JSON="$data" python - <<'PY'
import json
import os

data = json.loads(os.environ["LAYOUT_JSON"])
print("SevenOS Layout Gate")
print("===================")
print(f"State: {data.get('state')} · Score: {data.get('score')}%")
for item in data.get("checks", []):
    label = "OK" if item.get("ok") else "MISS"
    print(f"  {label:<4} {item.get('title_fr')}")
    print(f"       {item.get('detail_fr')}")
PY
fi

LAYOUT_JSON="$data" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["LAYOUT_JSON"])
sys.exit(0 if data.get("state") == "ready" else 1)
PY
