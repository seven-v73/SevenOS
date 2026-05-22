#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS update

Usage:
  seven update [status|plan|doctor|apply|json] [--json] [--yes]
  ./scripts/update.sh [status|plan|doctor|apply|json] [--json] [--yes]

This is the SevenOS-first update route. It explains system, app and profile
updates before delegating to pacman, Flatpak or AUR helpers.
EOF
}

ACTION="status"
JSON_OUTPUT=0
YES=0
for arg in "$@"; do
  case "$arg" in
    status|plan|doctor|apply|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown update option: $arg"; usage; exit 1 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

update_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import shutil
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def run_lines(command, timeout=8):
    try:
        result = subprocess.run(
            command,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except Exception:
        return None
    if result.returncode not in (0, 1):
        return None
    output = result.stdout.strip()
    return [line for line in output.splitlines() if line.strip()]


def command_ok(command):
    return shutil.which(command) is not None


fast_mode = os.environ.get("SEVENOS_UPDATE_FAST") == "1"
pacman_updates = run_lines(["pacman", "-Qu"]) if command_ok("pacman") and not fast_mode else None
flatpak_updates = run_lines(["flatpak", "remote-ls", "--updates", "--columns=application,version", "flathub"]) if command_ok("flatpak") and not fast_mode else None
aur_helper = "paru" if command_ok("paru") else "yay" if command_ok("yay") else ""
aur_updates = run_lines([aur_helper, "-Qua"], timeout=10) if aur_helper and not fast_mode else None

sources = [
    {
        "key": "system",
        "public_name": "SevenOS System",
        "backend": "pacman",
        "available": command_ok("pacman"),
        "pending": len(pacman_updates) if isinstance(pacman_updates, list) else None,
        "state": "OK" if command_ok("pacman") else "MISS",
        "command": "seven update apply",
    },
    {
        "key": "apps",
        "public_name": "SevenOS Apps",
        "backend": "Flatpak",
        "available": command_ok("flatpak"),
        "pending": len(flatpak_updates) if isinstance(flatpak_updates, list) else None,
        "state": "OK" if command_ok("flatpak") else "PART",
        "command": "seven flatpak status",
    },
    {
        "key": "community",
        "public_name": "SevenOS Community Apps",
        "backend": aur_helper or "AUR helper",
        "available": bool(aur_helper),
        "pending": len(aur_updates) if isinstance(aur_updates, list) else None,
        "state": "OK" if aur_helper else "PART",
        "command": "./install.sh aur-helpers --yes",
    },
    {
        "key": "profiles",
        "public_name": "Mini OS Bundles",
        "backend": "sevenpkg",
        "available": (root / "bin/sevenpkg").is_file(),
        "pending": None,
        "state": "OK" if (root / "bin/sevenpkg").is_file() else "MISS",
        "command": "sevenpkg status",
    },
]

missing = [item for item in sources if item["state"] == "MISS"]
partial = [item for item in sources if item["state"] == "PART"]
known_pending = [
    item["pending"]
    for item in sources
    if isinstance(item.get("pending"), int)
]
pending_total = sum(known_pending)
state = "updates-available" if pending_total > 0 else "ready" if not missing else "partial"
if fast_mode and not missing:
    state = "ready"
score = round((sum(1 for item in sources if item["state"] == "OK") + len(partial) * 0.5) / len(sources) * 100)

print(json.dumps({
    "schema": "sevenos.update.v1",
    "state": state,
    "score": score,
    "pending_total": pending_total,
    "pending_known": len(known_pending) == 3,
    "fast_mode": fast_mode,
    "sources": sources,
    "policy": [
        "SevenOS explains updates before backend commands run.",
        "System packages use pacman through the SevenOS route.",
        "Flatpak and AUR are app sources, not the public product identity.",
        "Profile bundles remain visible through sevenpkg and SevenStore.",
    ],
    "plan": [
        {
            "title": "Review update state",
            "command": "seven update",
            "impact": "safe",
        },
        {
            "title": "Apply SevenOS update route",
            "command": "seven update apply",
            "impact": "packages",
        },
        {
            "title": "Refresh SevenOS health after updates",
            "command": "seven doctor",
            "impact": "safe",
        },
    ],
    "issues": missing + partial,
    "commands": {
        "status": "seven update",
        "json": "seven update --json",
        "apply": "seven update apply",
        "store": "seven store",
    },
}, indent=2))
PY
}

print_human() {
  UPDATE_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["UPDATE_JSON"])
print("SevenOS Update")
print("==============")
print(f"State:    {data.get('state')}")
print(f"Score:    {data.get('score')}%")
print(f"Pending:  {data.get('pending_total')} known update(s)")
print()
for item in data.get("sources", []):
    pending = item.get("pending")
    pending_text = "unknown" if pending is None else str(pending)
    print(f"{item.get('state','MISS'):<4} {item.get('public_name')} · {pending_text} pending")
    print(f"     Foundation: {item.get('backend')} · route: {item.get('command')}")
PY
}

print_plan() {
  UPDATE_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["UPDATE_JSON"])
print("SevenOS Update Plan")
print("===================")
for item in data.get("plan", []):
    print(f"- {item.get('title')}: {item.get('command')}")
PY
}

apply_updates() {
  log_info "Applying SevenOS update route"
  if is_dry_run; then
    printf '%q ' "$ROOT_DIR/bin/sevenpkg" update
    printf '\n'
    if command -v flatpak >/dev/null 2>&1; then
      printf 'flatpak update --assumeyes\n'
    fi
    return 0
  fi

  "$ROOT_DIR/bin/sevenpkg" update
  if command -v flatpak >/dev/null 2>&1; then
    if [[ "$YES" -eq 1 || "${SEVENOS_YES:-0}" == "1" ]]; then
      flatpak update --assumeyes || true
    else
      flatpak update || true
    fi
  fi
  log_success "SevenOS update route completed."
}

payload="$(update_json)"
case "$ACTION" in
  status|json)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    ;;
  plan)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_plan "$payload"
    fi
    ;;
  doctor)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_human "$payload"
    fi
    UPDATE_JSON="$payload" python - <<'PY'
import json, os, sys
data = json.loads(os.environ["UPDATE_JSON"])
sys.exit(0 if data.get("score", 0) >= 75 else 1)
PY
    ;;
  apply) apply_updates ;;
esac
