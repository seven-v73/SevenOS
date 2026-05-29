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
  status|doctor|plan|json|--json) ;;
  -h|--help|help)
    cat <<'EOF'
SevenOS readiness decisions

Usage:
  seven public-readiness [--json]

Explains the difference between daily-driver readiness and public-release
readiness, then points to the next safe action.
EOF
    exit 0
    ;;
  *) echo "[SevenOS] Unknown readiness action: $ACTION" >&2; exit 1 ;;
esac

payload() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
installed_tree = str(root.resolve()) == "/opt/SevenOS"


def run_json(command, fallback=None, timeout=35):
    fallback = fallback or {}
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
            env={**os.environ, "SEVENOS_ROOT": str(root)},
        )
    except Exception:
        return fallback
    try:
        value = json.loads(result.stdout or "{}")
    except Exception:
        return fallback
    return value if isinstance(value, dict) else fallback


quality = run_json([str(root / "scripts/public-experience.sh"), "mode", "public", "--json"], {"daily_quality_ready": False, "public_quality_ready": False, "issues": []}, timeout=90)
release = run_json([str(root / "scripts/release.sh"), "status", "--json"], {"worktree": {}}, timeout=60)
shell = run_json([str(root / "scripts/shell-ags-runtime.sh"), "status", "--json"], {"state": "unknown", "ready": False}, timeout=12)

worktree = release.get("worktree") if isinstance(release.get("worktree"), dict) else {}
dirty_count = int(worktree.get("dirty_count", 0) or 0)
shell_ready = bool(shell.get("ready"))
daily_ready = bool(quality.get("daily_quality_ready"))
public_ready = bool(quality.get("public_quality_ready"))

if installed_tree:
    release_state = "info"
    release_detail_fr = "Cette machine utilise l’arbre système /opt/SevenOS. Le gel Git se vérifie dans le dépôt de construction avant publication, pas dans cette installation."
    release_detail_en = "This machine uses the /opt/SevenOS system tree. Git freeze is checked in the build repository before publishing, not in this installation."
    release_command = "seven update check"
else:
    release_state = "ready" if dirty_count == 0 else "todo"
    release_detail_fr = "Le dépôt est propre." if dirty_count == 0 else f"{dirty_count} chemin(s) modifiés/non suivis. Revoir, grouper, puis committer avant release publique."
    release_detail_en = "The repository is clean." if dirty_count == 0 else f"{dirty_count} modified/untracked path(s). Review, group and commit before public release."
    release_command = "seven release open"

decisions = [
    {
        "key": "daily-driver",
        "state": "ready" if daily_ready else "attention",
        "title_fr": "Usage quotidien",
        "title_en": "Daily use",
        "detail_fr": "SevenOS est prêt pour l’usage quotidien." if daily_ready else "Un gate bloquant empêche encore l’usage quotidien serein.",
        "detail_en": "SevenOS is ready for daily use." if daily_ready else "A blocking gate still prevents comfortable daily use.",
        "command": "seven quality mode public",
        "priority": 1,
    },
    {
        "key": "release-freeze",
        "state": release_state,
        "title_fr": "Gel release Git",
        "title_en": "Git release freeze",
        "detail_fr": release_detail_fr,
        "detail_en": release_detail_en,
        "command": release_command,
        "priority": 2,
    },
    {
        "key": "shell-runtime",
        "state": "ready" if shell_ready else "optional-finalization",
        "title_fr": "Runtime Seven Shell AGS",
        "title_en": "Seven Shell AGS runtime",
        "detail_fr": "AGS est installé." if shell_ready else "Fallback natif prêt. AGS reste l’étape pour remplacer progressivement les surfaces fallback par le Shell final.",
        "detail_en": "AGS is installed." if shell_ready else "Native fallback is ready. AGS is the next step for the final Shell surfaces.",
        "command": "scripts/shell-ags-runtime.sh open",
        "priority": 3,
    },
]

resolved_states = {"ready", "info"}
next_actions = [item for item in decisions if item["state"] not in resolved_states]
print(json.dumps({
    "schema": "sevenos.readiness-decisions.v1",
    "state": "public-ready" if public_ready else "daily-ready" if daily_ready else "attention",
    "daily_ready": daily_ready,
    "public_ready": public_ready,
    "summary": {
        "decisions": len(decisions),
        "ready": sum(1 for item in decisions if item["state"] in resolved_states),
        "todo": len(next_actions),
        "dirty_count": dirty_count,
        "installed_tree": installed_tree,
        "shell_ags": shell.get("state", "unknown"),
    },
    "decisions": decisions,
    "next": next_actions,
    "commands": {
        "quality": "seven quality mode public",
        "release_review": "seven release open",
        "shell_runtime": "scripts/shell-ags-runtime.sh open",
        "public_studio": "seven public-studio --gui",
    }
}, ensure_ascii=False, indent=2))
PY
}

data="$(payload)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$data"
else
  READINESS_JSON="$data" python - <<'PY'
import json
import os

data = json.loads(os.environ["READINESS_JSON"])
lang = (os.environ.get("SEVENOS_LANGUAGE") or os.environ.get("LANG") or "").lower()
fr = lang.startswith("fr")
print("SevenOS Readiness")
print("=================")
print(f"State: {data.get('state')}")
for item in data.get("decisions", []):
    title = item.get("title_fr" if fr else "title_en")
    detail = item.get("detail_fr" if fr else "detail_en")
    print(f"  {item.get('state'):<20} {title}")
    print(f"       {detail}")
    if item.get("command"):
        print(f"       {item.get('command')}")
PY
fi
