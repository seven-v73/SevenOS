#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS differentiators

Usage:
  seven differentiators [status|doctor|plan|json] [--json]

Shows how SevenOS turns an Arch-compatible base into a public OS experience:
installer, snapshots, security, AI, Forge, Pulse, Cloud, UI, Store and original
experience concepts.
EOF
}

for arg in "$@"; do
  case "$arg" in
    status|doctor|plan|json) ACTION="$arg" ;;
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
  esac
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

payload_json() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import shutil
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])


def exists(path: str) -> bool:
    return (root / path).exists()


def contains(path: str, *needles: str) -> bool:
    try:
        text = (root / path).read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return False
    return all(needle in text for needle in needles)


def command(name: str) -> bool:
    return shutil.which(name) is not None or (root / "bin" / name).exists()


def run_json(args: list[str], fallback: dict, timeout: int = 20) -> dict:
    try:
        result = subprocess.run(
            args,
            cwd=root,
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
            env={**os.environ, "SEVENOS_ROOT": str(root)},
        )
        return json.loads(result.stdout) if result.stdout.strip() else fallback
    except Exception:
        return fallback


release = run_json([str(root / "scripts/installer-stack.sh"), "release", "--json"], {})
if os.environ.get("SEVENOS_DIFFERENTIATORS_FROM_PUBLIC") == "1":
    quality = {"score": 100, "public_quality_ready": True, "state": "delegated"}
else:
    quality = run_json([str(root / "scripts/public-experience.sh"), "doctor", "--json"], {})
store = run_json([str(root / "scripts/store.sh"), "json"], {})
cloud = run_json([str(root / "scripts/cloud.sh"), "json"], {})
box = run_json([str(root / "scripts/box.sh"), "json"], {})
ai = run_json([str(root / "scripts/seven_ai_agent.py"), "llm", "--json"], {})
bridge = run_json([str(root / "scripts/mini-os-relay.sh"), "graph", "--json"], {})

checks = []


def pillar(key, title, goal, signals, command_line, next_action="", severity="medium"):
    ready = sum(1 for item in signals if item.get("ok"))
    total = len(signals)
    score = round((ready / max(total, 1)) * 100)
    state = "OK" if score >= 80 else "PART" if score >= 45 else "MISS"
    item = {
        "key": key,
        "state": state,
        "score": score,
        "title": title,
        "goal": goal,
        "ready": ready,
        "total": total,
        "signals": signals,
        "command": command_line,
        "next": next_action,
        "severity": severity,
    }
    checks.append(item)


pillar(
    "simple-install",
    "Installation et configuration simplifiées",
    "Installer SevenOS comme un OS public, avec profils, post-install et matériel vérifiable.",
    [
        {"key": "graphical-installer", "ok": (release.get("installer") or {}).get("state") == "graphical-ready" or "graphical-ready" in json.dumps(release), "detail": "Calamares/ISO graphical route"},
        {"key": "first-run", "ok": exists("bin/seven-public-studio") and exists("scripts/new-device.sh") or exists("scripts/post-install.sh"), "detail": "first-run verifier and post-install route"},
        {"key": "profiles", "ok": exists("profiles/catalog.json") and contains("profiles/catalog.json", "forge", "pulse", "studio", "atlas", "baobab"), "detail": "predefined mini OS profiles"},
        {"key": "hardware", "ok": command("lspci") or command("inxi") or command("fastfetch"), "detail": "hardware detection tooling"},
    ],
    "seven first-run verify",
    "seven installer release",
    "high",
)

pillar(
    "advanced-system",
    "Gestion système avancée",
    "Remplacer les scripts opaques par des surfaces de diagnostic, service, rollback et santé.",
    [
        {"key": "health", "ok": exists("scripts/health.sh"), "detail": "health dashboard"},
        {"key": "experience-center", "ok": exists("bin/seven-experience-center") and contains("bin/seven-experience-center", "Time Machine", "Rescue"), "detail": "Rescue + Time Machine"},
        {"key": "events", "ok": exists("scripts/events.sh"), "detail": "activity timeline"},
        {"key": "core", "ok": exists("scripts/core.sh"), "detail": "Seven Core runtime state"},
    ],
    "seven experience-center --gui",
    "seven time-machine",
    "high",
)

pillar(
    "security",
    "Sécurité renforcée",
    "Rendre la sécurité visible: permissions, Shield, isolation, audits et actions explicites.",
    [
        {"key": "shield", "ok": exists("scripts/packages-cybersecurity.txt") and exists("bin/seven-shield") or exists("scripts/profile-isolation.sh"), "detail": "Shield and isolation"},
        {"key": "permissions", "ok": contains("bin/seven-experience-center", "permissions_state", "Privacy Report"), "detail": "permissions center"},
        {"key": "sandbox", "ok": int((box.get("summary") or {}).get("ready", 0) or 0) > 0 or command("bwrap"), "detail": "sandbox/runtime checks"},
        {"key": "privacy", "ok": exists("scripts/seven_ai_provider.py") and contains("bin/seven-settings-native", "local_ai_data"), "detail": "local AI/privacy route"},
    ],
    "seven permissions --gui",
    "seven shield audit",
    "high",
)

pillar(
    "ai-local",
    "Fonctionnalités IA intégrées",
    "Faire de SevenAI un assistant local-first, capable d’expliquer, diagnostiquer et planifier.",
    [
        {"key": "agent", "ok": exists("scripts/seven_ai_agent.py"), "detail": "local intent agent"},
        {"key": "missions", "ok": contains("scripts/seven_ai_agent.py", "PLAN_MISSION") and contains("bin/seven-experience-center", "Equinox Mission Planner"), "detail": "mission planning"},
        {"key": "diagnostics", "ok": contains("scripts/seven_ai_agent.py", "diagnostics", "failed_units"), "detail": "system diagnostics"},
        {"key": "provider", "ok": exists("scripts/seven_ai_provider.py"), "detail": "provider abstraction"},
    ],
    "seven ai ask \"mon wifi ne marche pas\"",
    "seven missions",
    "medium",
)

pillar(
    "developer",
    "Optimisations développeurs",
    "Forge doit fournir conteneurs, stacks, Git, services et déploiement sans bruit.",
    [
        {"key": "forge-packages", "ok": exists("scripts/packages-dev.txt") and contains("profiles/catalog.json", "Forge DevOps"), "detail": "Forge package base"},
        {"key": "containers", "ok": contains("scripts/packages-dev.txt", "docker") or contains("scripts/packages-dev.txt", "podman"), "detail": "Docker/Podman base"},
        {"key": "deploy", "ok": exists("server/seven-deploy.sh") and exists("server/seven-server.sh"), "detail": "Forge deploy/server"},
        {"key": "stacks", "ok": any(contains("scripts/packages-dev.txt", item) for item in ("nodejs", "python", "rust", "go")), "detail": "popular stacks"},
    ],
    "seven profile activate forge",
    "seven deploy panel",
    "high",
)

pillar(
    "gaming",
    "Fonctionnalités gamers",
    "Pulse doit activer performance, Proton, audio, capture et confort sans transformer l’OS en RGB.",
    [
        {"key": "pulse", "ok": contains("profiles/catalog.json", "Pulse Gaming"), "detail": "Pulse profile"},
        {"key": "performance-packages", "ok": exists("scripts/packages-performance.txt"), "detail": "performance package base"},
        {"key": "optional-launchers", "ok": exists("scripts/packages-performance-optional.txt") and contains("scripts/packages-performance-optional.txt", "lutris", "protontricks", "Steam"), "detail": "Steam/Lutris optional route"},
        {"key": "mode", "ok": exists("bin/seven-pulse") or exists("scripts/performance-gate.sh"), "detail": "Pulse doctor/performance gate"},
    ],
    "seven profile activate pulse",
    "seven pulse doctor",
    "medium",
)

pillar(
    "personal-cloud",
    "Cloud personnel local-first",
    "Sauvegarder, synchroniser et partager seulement quand l’utilisateur choisit de le faire.",
    [
        {"key": "cloud-contract", "ok": exists("scripts/cloud.sh"), "detail": "SevenCloud contract"},
        {"key": "backup-targets", "ok": int((cloud.get("summary") or {}).get("targets", 0) or 0) >= 4, "detail": "protected targets"},
        {"key": "device-continuity", "ok": contains("bin/seven-experience-center", "device_continuity_state"), "detail": "device continuity"},
        {"key": "server", "ok": exists("server/seven-server.sh"), "detail": "local server foundation"},
    ],
    "seven cloud plan",
    "seven device-continuity",
    "medium",
)

pillar(
    "ui",
    "Interface utilisateur innovante",
    "Une identité SevenOS cohérente: Prism, Settings, Files, Store, Control Center et recherche.",
    [
        {"key": "quality", "ok": quality.get("public_quality_ready") is True or int(quality.get("score", 0) or 0) >= 90 or (exists("scripts/public-experience.sh") and exists("bin/seven-public-studio")), "detail": "public quality aggregate"},
        {"key": "settings", "ok": exists("bin/seven-settings-native"), "detail": "native settings"},
        {"key": "files-store", "ok": exists("bin/seven-files-native") and exists("bin/seven-store-native"), "detail": "Files + Store"},
        {"key": "prism", "ok": contains("scripts/smart-window.sh", "controls") or contains("bin/seven-settings-native", "Prism"), "detail": "Prism controls"},
    ],
    "seven quality mode public --gui",
    "seven settings",
    "high",
)

pillar(
    "apps",
    "Gestion des applications améliorée",
    "Unifier Pacman, AUR, Flatpak, AppImage et les modules SevenOS sans perdre la confiance.",
    [
        {"key": "store", "ok": exists("bin/seven-store-native") and (int((store.get("summary") or {}).get("flatpak_apps", 0) or 0) >= 1 or int((store.get("summary") or {}).get("installed_apps", 0) or 0) >= 1 or len(store.get("apps", []) or []) >= 1), "detail": "SevenStore catalog"},
        {"key": "flatpak", "ok": exists("scripts/flatpak.sh"), "detail": "Flatpak route"},
        {"key": "aur", "ok": exists("scripts/aur-helpers.sh") or exists("scripts/packages-aur-helpers.txt"), "detail": "AUR helper route"},
        {"key": "package-sources", "ok": contains("identity/native/store.css", "source-flatpak", "source-aur", "source-pacman"), "detail": "source-aware UI"},
    ],
    "seven store",
    "seven flatpak status",
    "high",
)

pillar(
    "original-concepts",
    "Concepts originaux SevenOS",
    "Se distinguer par les mini OS, les missions Equinox, les modes public/expert et la continuité.",
    [
        {"key": "missions", "ok": contains("bin/seven-experience-center", "mission_flow_state", "mali-game"), "detail": "Equinox Mission Planner"},
        {"key": "bridge", "ok": bridge.get("state") == "ready" or contains("scripts/mini-os-relay.sh", "atlas", "baobab", "forge"), "detail": "mini OS bridge"},
        {"key": "quality-mode", "ok": contains("scripts/public-experience.sh", "mode", "public_quality_ready"), "detail": "public quality mode"},
        {"key": "beginner-expert", "ok": contains("identity/workflow-contract.json", "beginner") or contains("bin/seven-settings-native", "settings.advanced", "Avancé") or exists("scripts/mask.sh"), "detail": "public mask / advanced routes"},
    ],
    "seven missions",
    "seven bridge graph",
    "medium",
)

issues = [item for item in checks if item["state"] != "OK"]
ok = len(checks) - len(issues)
score = round(ok / max(len(checks), 1) * 100)
state = "differentiated" if score >= 90 else "needs-polish" if score >= 70 else "foundation"

print(json.dumps({
    "schema": "sevenos.differentiators.v1",
    "state": state,
    "score": score,
    "summary": {
        "pillars": len(checks),
        "ok": ok,
        "issues": len(issues),
        "high_issues": sum(1 for item in issues if item["severity"] == "high"),
    },
    "checks": checks,
    "issues": issues,
    "commands": {
        "status": "seven differentiators",
        "doctor": "seven differentiators doctor",
        "plan": "seven differentiators plan",
        "public_quality": "seven quality mode public",
        "missions": "seven missions",
        "first_run": "seven first-run verify",
    },
}, ensure_ascii=False, indent=2))
PY
}

print_status() {
  PAYLOAD="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PAYLOAD"])
print("SevenOS Differentiators")
print("=======================")
print(f"State: {data.get('state')} · Score: {data.get('score')}%")
print()
for item in data.get("checks", []):
    print(f"{item.get('state', 'PART'):<4} {item.get('title')}")
    print(f"     {item.get('goal')}")
    print(f"     {item.get('ready')}/{item.get('total')} · {item.get('command')}")
PY
}

print_plan() {
  PAYLOAD="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["PAYLOAD"])
if not data.get("issues"):
    print("SevenOS differentiator plan: no open action.")
else:
    print("SevenOS differentiator plan")
    print("===========================")
    for item in data.get("issues", []):
        print(f"- {item.get('title')}: {item.get('next') or item.get('command')}")
        for signal in item.get("signals", []):
            if not signal.get("ok"):
                print(f"  · {signal.get('key')}: {signal.get('detail')}")
PY
}

payload="$(payload_json)"
case "$ACTION" in
  status|json)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      print_status "$payload"
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
      print_status "$payload"
      echo
      print_plan "$payload"
    fi
    PAYLOAD="$payload" python - <<'PY'
import json
import os
import sys
data = json.loads(os.environ["PAYLOAD"])
sys.exit(0 if int(data.get("score", 0)) >= 80 else 1)
PY
    ;;
esac
