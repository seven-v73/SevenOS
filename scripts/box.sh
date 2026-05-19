#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenBox Preview

Usage:
  seven box [status|profiles|launch|doctor|json]

SevenBox is the local sandbox and container contract for SevenOS. It reports
what can run safely today without starting containers or changing the system.
EOF
}

state_for_command() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

payload_json() {
  ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import shutil
from pathlib import Path
import os

root = Path(os.environ["ROOT_DIR"])

checks = [
    {
        "key": "podman",
        "label": "Podman rootless containers",
        "state": "OK" if shutil.which("podman") else "MISS",
        "command": "seven improve deployment --apply --yes",
    },
    {
        "key": "bubblewrap",
        "label": "Bubblewrap namespace sandbox",
        "state": "OK" if shutil.which("bwrap") else "MISS",
        "command": "seven shield enable",
    },
    {
        "key": "firejail",
        "label": "Firejail app sandbox",
        "state": "OK" if shutil.which("firejail") else "MISS",
        "command": "seven shield enable",
    },
    {
        "key": "flatpak",
        "label": "Flatpak app isolation",
        "state": "OK" if shutil.which("flatpak") else "MISS",
        "command": "seven flatpak setup",
    },
]

profiles = [
    {
        "key": "app-sandbox",
        "title": "App Sandbox",
        "state": "ready" if shutil.which("bwrap") or shutil.which("firejail") else "setup-needed",
        "command": "seven shield status",
        "description": "Launch untrusted desktop apps through namespace or Firejail isolation.",
    },
    {
        "key": "dev-container",
        "title": "Dev Container",
        "state": "ready" if shutil.which("podman") else "setup-needed",
        "command": "podman info",
        "description": "Run project dependencies in a rootless container workflow.",
    },
    {
        "key": "flatpak-runtime",
        "title": "Flatpak Runtime",
        "state": "ready" if shutil.which("flatpak") else "setup-needed",
        "command": "seven flatpak status",
        "description": "Install mainstream apps through a sandboxed runtime.",
    },
]

payload = {
    "schema": "sevenos.box.v1",
    "state": "product-preview",
    "writer": "scripts/box.sh",
    "summary": {
        "ready": sum(1 for item in checks if item["state"] == "OK"),
        "total": len(checks),
        "profiles_ready": sum(1 for item in profiles if item["state"] == "ready"),
        "profiles_total": len(profiles),
    },
    "checks": checks,
    "profiles": profiles,
    "launch_contract": {
        "default": "preview command first",
        "app-sandbox": "bwrap/firejail wrapper for selected apps",
        "dev-container": "rootless podman shell in a project directory",
        "flatpak-runtime": "open sandboxed app catalog",
    },
    "workspace": str(Path.home() / "SevenOS" / "Boxes"),
    "docs": str(root / "docs" / "ECOSYSTEM.md"),
}
print(json.dumps(payload, indent=2))
PY
}

status() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
data = json.loads(os.environ["PAYLOAD"])
summary = data["summary"]
print("SevenBox Preview")
print("================")
print(f"Runtime checks: {summary['ready']}/{summary['total']}")
print(f"Profiles:       {summary['profiles_ready']}/{summary['profiles_total']}")
print(f"Workspace:      {data['workspace']}")
print()
for item in data["checks"]:
    print(f"  - {item['key']:<10} {item['state']:<5} {item['label']}")
PY
}

profiles() {
  payload_json | python -c 'import json,sys; d=json.load(sys.stdin); print("SevenBox Profiles\n================="); [print(f"{i[\"key\"]:<16} {i[\"state\"]:<13} {i[\"description\"]}\n{'':<16} command: {i[\"command\"]}") for i in d["profiles"]]'
}

launch() {
  local profile="${1:-app-sandbox}"
  case "$profile" in
    app-sandbox)
      printf 'SevenBox App Sandbox\n'
      printf '====================\n'
      printf 'Use Firejail or Bubblewrap for an explicit app launch.\n'
      printf 'Examples:\n'
      printf '  firejail --private <app>\n'
      printf '  bwrap --ro-bind /usr /usr --dev /dev --proc /proc --tmpfs /tmp <command>\n'
      ;;
    dev-container)
      printf 'SevenBox Dev Container\n'
      printf '======================\n'
      printf 'Preview command:\n'
      printf '  podman run --rm -it -v "$PWD:/workspace:Z" -w /workspace archlinux:latest bash\n'
      ;;
    flatpak-runtime)
      printf 'SevenBox Flatpak Runtime\n'
      printf '========================\n'
      printf 'Open app delivery with: seven store apps\n'
      ;;
    *)
      log_error "Unknown SevenBox profile: $profile"
      printf 'Available: app-sandbox, dev-container, flatpak-runtime\n'
      return 1
      ;;
  esac
}

doctor() {
  local payload
  payload="$(payload_json)"
  PAYLOAD="$payload" python - <<'PY'
import json, os
d = json.loads(os.environ["PAYLOAD"])
print("SevenBox Doctor")
print("===============")
for item in d["checks"]:
    print(f"[{item['state']}] {item['key']}")
if d["summary"]["ready"] == 0:
    raise SystemExit(1)
PY
}

action="${1:-status}"
case "$action" in
  status) status ;;
  profiles) profiles ;;
  launch) launch "${2:-app-sandbox}" ;;
  doctor) doctor ;;
  json|--json) payload_json ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown box action: $action"; usage; exit 1 ;;
esac
