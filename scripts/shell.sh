#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS Shell

Usage:
  seven shell [status|plan|doctor|preview]
  seven shell status --json
  seven shell plan --json
  ./scripts/shell.sh [status|plan|doctor|preview] [--json]

Seven Shell is the B3 AGS/TypeScript shell foundation. It will replace Rofi
panels gradually while keeping the current Hyprland/Waybar/Rofi fallback safe.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

package_state() {
  command -v pacman >/dev/null 2>&1 && pacman -Q "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

file_state() {
  [[ -s "$ROOT_DIR/$1" ]] && printf OK || printf MISS
}

runtime_state() {
  if command -v ags >/dev/null 2>&1; then
    printf READY
  elif [[ "$(package_state gjs)" == OK && "$(package_state typescript)" == OK ]]; then
    printf FOUNDATION
  else
    printf PLANNED
  fi
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

status_json() {
  local runtime
  runtime="$(runtime_state)"
  printf '{'
  printf '"schema":"sevenos.shell.v1",'
  printf '"phase":"B3",'
  printf '"state":%s,' "$(printf '%s' "$runtime" | json_string)"
  printf '"strategy":"AGS + TypeScript shell with Rofi fallback",'
  printf '"fallback":"Waybar, Rofi and GTK shell panels remain active until AGS surfaces are ready",'
  printf '"surfaces":['
  printf '{"key":"quick-settings","state":%s,"current":"GTK/Rofi","target":"AGS"},' "$(printf '%s' "$(file_state bin/seven-shell-panel)" | json_string)"
  printf '{"key":"notifications","state":%s,"current":"GTK/Rofi","target":"AGS"},' "$(printf '%s' "$(file_state bin/seven-waybar-notifications)" | json_string)"
  printf '{"key":"launcher","state":%s,"current":"Rofi Launchpad","target":"AGS"},' "$(printf '%s' "$(file_state bin/seven-apps)" | json_string)"
  printf '{"key":"dock","state":%s,"current":"planned","target":"AGS"}' "$(printf '%s' "$(file_state seven-shell/ags/src/dock.ts)" | json_string)"
  printf '],'
  printf '"dependencies":['
  printf '{"key":"gjs","state":%s},' "$(printf '%s' "$(package_state gjs)" | json_string)"
  printf '{"key":"typescript","state":%s},' "$(printf '%s' "$(package_state typescript)" | json_string)"
  printf '{"key":"gtk4","state":%s},' "$(printf '%s' "$(package_state gtk4)" | json_string)"
  printf '{"key":"libadwaita","state":%s},' "$(printf '%s' "$(package_state libadwaita)" | json_string)"
  printf '{"key":"nodejs","state":%s},' "$(printf '%s' "$(command_state node)" | json_string)"
  printf '{"key":"ags","state":%s}' "$(printf '%s' "$(command_state ags)" | json_string)"
  printf '],'
  printf '"contracts":["seven state --json","seven actions --json","seven profile current --json","seven shell status --json"],'
  printf '"commands":{"install":"./install.sh shell-ags","plan":"seven shell plan","preview":"seven shell preview"}'
  printf '}\n'
}

plan_json() {
  SHELL_STATUS="$(status_json)" python - <<'PY'
import json
import os

status = json.loads(os.environ["SHELL_STATUS"])

meta = {
    "gjs": ("Install GJS runtime", "high", "packages", "AGS depends on GNOME JavaScript bindings."),
    "typescript": ("Install TypeScript", "medium", "packages", "Seven Shell source should be typed from the beginning."),
    "gtk4": ("Install GTK4", "medium", "packages", "AGS shell surfaces need GTK4 widgets."),
    "libadwaita": ("Install libadwaita", "medium", "packages", "Seven Shell should stay visually native with GNOME-like components."),
    "nodejs": ("Install Node.js", "medium", "packages", "TypeScript tooling needs Node.js."),
    "ags": ("Choose AGS runtime workflow", "high", "manual", "AGS is not in the core Arch repo here; keep installation explicit until the AUR policy is settled."),
}

actions = []
for dep in status.get("dependencies", []):
    if dep.get("state") == "OK":
        continue
    key = dep.get("key")
    title, severity, impact, reason = meta.get(key, (f"Prepare {key}", "medium", "packages", f"Prepare {key}."))
    command = "./install.sh shell-ags" if key != "ags" else "seven stack roadmap"
    actions.append({
        "key": key,
        "title": title,
        "severity": severity,
        "impact": impact,
        "reason": reason,
        "command": command,
    })

for surface in status.get("surfaces", []):
    if surface.get("state") != "OK":
        actions.append({
            "key": surface.get("key"),
            "title": f"Scaffold {surface.get('key')} surface",
            "severity": "medium",
            "impact": "safe",
            "reason": f"Seven Shell needs a planned {surface.get('target')} version of {surface.get('key')}.",
            "command": "seven shell preview",
        })

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions.sort(key=lambda item: (rank.get(item["severity"], 9), item["key"]))

print(json.dumps({
    "schema": "sevenos.shell-plan.v1",
    "summary": {
        "total": len(actions),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
    },
    "next": actions,
}, indent=2))
PY
}

status() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    status_json
    return 0
  fi

  printf 'SevenOS Shell Status\n'
  printf '====================\n'
  printf 'state:       %s\n' "$(runtime_state)"
  printf 'strategy:    AGS + TypeScript shell with Rofi fallback\n'
  printf 'fallback:    Waybar, Rofi and GTK shell panels stay active\n'
  printf 'install:     ./install.sh shell-ags\n'
  printf 'next:        seven shell plan\n'
}

plan() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    plan_json
    return 0
  fi

  SHELL_PLAN="$(plan_json)" python - <<'PY'
import json
import os

plan = json.loads(os.environ["SHELL_PLAN"])
summary = plan.get("summary", {})
print("SevenOS Shell Plan")
print("==================")
print(f"Open actions: {summary.get('total', 0)}")
print()
for item in plan.get("next", []):
    print(f"{item.get('severity', 'medium'):<8} {item.get('command', 'seven shell plan')}")
    print(f"         {item.get('reason', '')}")
PY
}

doctor() {
  local failures=0
  printf 'SevenOS Shell Doctor\n'
  printf '====================\n'
  for file in \
    "seven-shell/README.md" \
    "seven-shell/ags/README.md" \
    "seven-shell/ags/package.json" \
    "seven-shell/ags/tsconfig.json" \
    "seven-shell/ags/src/config.ts" \
    "scripts/packages-shell-ags.txt"; do
    if [[ -s "$ROOT_DIR/$file" ]]; then
      printf '[OK] %s\n' "$file"
    else
      printf '[MISS] %s\n' "$file"
      failures=$((failures + 1))
    fi
  done

  printf '[%s] gjs\n' "$(package_state gjs)"
  printf '[%s] typescript\n' "$(package_state typescript)"
  printf '[%s] gtk4\n' "$(package_state gtk4)"
  command -v ags >/dev/null 2>&1 && printf '[OK] ags\n' || printf '[AUR] ags runtime pending explicit workflow\n'

  if [[ "$failures" -gt 0 ]]; then
    log_error "Seven Shell foundation has $failures missing file(s)."
    return 1
  fi

  log_success "Seven Shell foundation is coherent."
}

preview() {
  printf 'SevenOS Shell Preview\n'
  printf '=====================\n'
  printf 'B3 target: AGS + TypeScript shell\n'
  printf 'Current fallback: Waybar + GTK shell panel + Rofi\n\n'
  printf 'Surfaces:\n'
  printf '  - Quick Settings: GTK/Rofi now -> AGS panel next\n'
  printf '  - Notifications: GTK/Rofi now -> AGS center next\n'
  printf '  - Launcher: Rofi Launchpad now -> AGS launcher next\n'
  printf '  - Dock: planned -> AGS dock\n\n'
  printf 'Contracts consumed:\n'
  printf '  - seven state --json\n'
  printf '  - seven actions --json\n'
  printf '  - seven profile current --json\n'
  printf '  - seven shell status --json\n'
}

case "$ACTION" in
  status) status ;;
  plan) plan ;;
  doctor) doctor ;;
  preview) preview ;;
  json|--json) JSON_OUTPUT=1; status ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown shell action: $ACTION"; usage; exit 1 ;;
esac
