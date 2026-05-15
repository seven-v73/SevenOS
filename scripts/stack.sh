#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS Stack Strategy

Usage:
  seven stack [status|roadmap|doctor]
  seven stack --json
  ./scripts/stack.sh [status|roadmap|doctor|--json]

This command keeps SevenOS from becoming a pile of languages. It declares which
stack belongs to each phase and which technologies are allowed to enter next.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done

layers_tsv() {
  cat <<'EOF'
system-contracts	B2	active	Bash + Python	Stable JSON contracts, installer scripts, Seven Hub Native bridge	Keep until B3 is measurable.
native-hub	B2	active	GTK4 + libadwaita + Python	Control Center foundation, profiles, actions, phase gate	Polish before replacing shell surfaces.
seven-server	B2-B3	preview	Python now, Rust later	Local API, monitoring, orchestration and deployment state	Do not expose remote control before auth model.
seven-shell	B3	next	AGS + TypeScript + GJS	Hyprland panels, dock, launcher, notifications, widgets	Replace Rofi panels gradually, keep Rofi fallback.
seven-daemon	B3	next	Rust	System events, IPC, profile/session orchestration	Introduce after JSON contracts stabilize.
seven-ai	Phase 4	planned	Python	Local assistant, explain errors, optimize workflows	Keep outside critical security path.
native-apps	Phase 4	planned	Flutter or Qt	Seven Store, Settings, Notes, Cloud and media apps	Choose per app; avoid duplicating Hub.
ecosystem	Phase 5	planned	Rust + Python + Flutter/Qt	Store, Cloud, Sync, extensions, marketplace	Only after B3 services are stable.
EOF
}

rules_tsv() {
  cat <<'EOF'
one-shell-stack	Seven Shell uses AGS/TypeScript first; no parallel Qt/QML shell until AGS is proven.
native-before-web	Control surfaces should prefer GTK/libadwaita or AGS; Tauri remains prototype/fallback.
rust-for-daemons	Rust enters for long-running daemons, IPC and security-sensitive orchestration.
python-for-ai	Python handles AI, recommendations and analysis, not boot-critical session control.
flutter-for-products	Flutter is reserved for larger apps like Store, Cloud, Notes or mobile companion.
rofi-as-fallback	Rofi stays a fast fallback launcher, not the main OS control plane.
json-first	No UI parses human text; missing data must become a JSON contract.
phase-gated	No new major stack enters without being visible in phase gate, checks and docs.
EOF
}

package_state() {
  local package="$1"
  command -v pacman >/dev/null 2>&1 && pacman -Q "$package" >/dev/null 2>&1 && printf OK || printf MISS
}

json_output() {
  LAYERS_TSV="$(layers_tsv)" RULES_TSV="$(rules_tsv)" ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
import shutil
import subprocess

ROOT = os.environ["ROOT_DIR"]


def command_exists(name):
    return shutil.which(name) is not None


def pacman_installed(name):
    return subprocess.run(["pacman", "-Q", name], text=True, capture_output=True).returncode == 0


layers = []
for raw in os.environ["LAYERS_TSV"].splitlines():
    key, phase, state, stack, purpose, constraint = raw.split("\t", 5)
    layers.append({
        "key": key,
        "phase": phase,
        "state": state,
        "stack": stack,
        "purpose": purpose,
        "constraint": constraint,
    })

rules = []
for raw in os.environ["RULES_TSV"].splitlines():
    key, rule = raw.split("\t", 1)
    rules.append({"key": key, "rule": rule})

checks = [
    {"key": "gtk4", "label": "GTK4", "state": "OK" if pacman_installed("gtk4") else "MISS", "command": "./install.sh hub-gui-stack"},
    {"key": "libadwaita", "label": "libadwaita", "state": "OK" if pacman_installed("libadwaita") else "MISS", "command": "./install.sh hub-gui-stack"},
    {"key": "gjs", "label": "GJS", "state": "OK" if pacman_installed("gjs") else "MISS", "command": "./install.sh shell-ags"},
    {"key": "typescript", "label": "TypeScript", "state": "OK" if pacman_installed("typescript") else "MISS", "command": "./install.sh shell-ags"},
    {"key": "nodejs", "label": "Node.js", "state": "OK" if command_exists("node") else "MISS", "command": "./install.sh hub-gui-stack"},
    {"key": "rust", "label": "Rust", "state": "OK" if command_exists("rustc") or pacman_installed("rust") else "MISS", "command": "./install.sh hub-gui-stack"},
    {"key": "python", "label": "Python", "state": "OK" if command_exists("python") else "MISS", "command": "./install.sh base"},
    {"key": "ags-runtime", "label": "AGS runtime", "state": "OK" if command_exists("ags") else "AUR", "command": "Install AGS from the chosen Arch/AUR workflow before replacing panels"},
]

summary = {
    "active": sum(1 for item in layers if item["state"] == "active"),
    "next": sum(1 for item in layers if item["state"] == "next"),
    "planned": sum(1 for item in layers if item["state"] == "planned"),
    "checks_ok": sum(1 for item in checks if item["state"] == "OK"),
    "checks_total": len(checks),
}

print(json.dumps({
    "schema": "sevenos.stack.v1",
    "phase": "B2-B3",
    "principle": "Introduce one major stack at a time: JSON contracts, native Hub, AGS shell, Rust daemon, AI, apps, ecosystem.",
    "current_focus": ["JSON contracts", "Seven Hub Native", "Seven Server preparation"],
    "next_focus": ["Seven Shell AGS", "seven-daemon Rust"],
    "layers": layers,
    "rules": rules,
    "checks": checks,
    "summary": summary,
}, indent=2))
PY
}

status() {
  printf 'SevenOS Stack Strategy\n'
  printf '======================\n'
  printf 'Focus now: JSON contracts, Seven Hub Native, Seven Server preparation\n'
  printf 'Next: Seven Shell AGS, then seven-daemon Rust\n\n'
  printf '%-18s %-9s %-8s %-24s %s\n' "Layer" "Phase" "State" "Stack" "Purpose"
  printf '%-18s %-9s %-8s %-24s %s\n' "-----" "-----" "-----" "-----" "-------"
  while IFS=$'\t' read -r key phase state stack purpose _constraint; do
    printf '%-18s %-9s %-8s %-24s %s\n' "$key" "$phase" "$state" "$stack" "$purpose"
  done < <(layers_tsv)
}

roadmap() {
  printf 'SevenOS Stack Roadmap\n'
  printf '=====================\n\n'
  printf 'B2-B3\n'
  printf '  - Keep Bash/Python scripts while JSON contracts stabilize.\n'
  printf '  - Polish Seven Hub Native GTK/libadwaita.\n'
  printf '  - Prepare Seven Server as local backend.\n\n'
  printf 'B3\n'
  printf '  - Introduce Seven Shell with AGS + TypeScript.\n'
  printf '  - Keep Rofi as fallback, not primary shell surface.\n'
  printf '  - Start seven-daemon in Rust after contracts are stable.\n\n'
  printf 'Phase 4\n'
  printf '  - Add SevenAI in Python outside critical security paths.\n'
  printf '  - Build Store/Cloud/Notes with Flutter, Qt or GTK per product need.\n\n'
  printf 'Phase 5\n'
  printf '  - Connect Store, Cloud, AI, Sync and extensions into the ecosystem.\n'
}

doctor() {
  local failures=0

  printf 'SevenOS Stack Doctor\n'
  printf '====================\n'

  for file in \
    "docs/STACK_STRATEGY.md" \
    "scripts/packages-shell-ags.txt" \
    "scripts/stack.sh" \
    "bin/seven" \
    "seven-hub/native/README.md"; do
    if [[ -s "$ROOT_DIR/$file" ]]; then
      printf '[OK] %s\n' "$file"
    else
      printf '[MISS] %s\n' "$file"
      failures=$((failures + 1))
    fi
  done

  printf '[%s] GTK4\n' "$(package_state gtk4)"
  printf '[%s] GJS\n' "$(package_state gjs)"
  printf '[%s] TypeScript\n' "$(package_state typescript)"
  if command -v ags >/dev/null 2>&1; then
    printf '[OK] AGS runtime\n'
  else
    printf '[AUR] AGS runtime is not in the core SevenOS pacman foundation yet\n'
  fi

  if [[ "$failures" -gt 0 ]]; then
    log_error "Stack strategy has $failures missing foundation file(s)."
    return 1
  fi

  log_success "Stack strategy foundation is coherent."
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  json_output
  exit 0
fi

case "$ACTION" in
  status) status ;;
  roadmap) roadmap ;;
  doctor) doctor ;;
  json|--json) json_output ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown stack action: $ACTION"; usage; exit 1 ;;
esac
