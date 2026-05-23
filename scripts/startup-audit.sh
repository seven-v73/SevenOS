#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
JSON_OUTPUT=0

usage() {
  cat <<'EOF'
SevenOS startup audit

Usage:
  ./scripts/startup-audit.sh [--json]

Public UI contract:
- display immediately from cache or local files;
- refresh live state in the background;
- keep full audits explicit;
- never block app launch on state, health, readiness, pacman, flatpak or virsh.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) printf 'startup-audit: unknown option: %s\n' "$arg" >&2; usage; exit 1 ;;
  esac
done

SEVENOS_ROOT="$ROOT_DIR" JSON_OUTPUT="$JSON_OUTPUT" python - <<'PY'
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(os.environ["SEVENOS_ROOT"])
JSON_OUTPUT = os.environ.get("JSON_OUTPUT") == "1"

PUBLIC_SURFACES = [
    ("home-state", "SevenOS Home state", ["bin/seven-home-native", "--json"], 3.0, "Use fast health, short timeouts and cached profile state."),
    ("settings-probe", "Settings native availability", ["bin/seven-settings-native", "--probe"], 1.0, "Do not build heavy pages or call seven state during probe."),
    ("hub-status", "Hub native status", ["bin/seven-hub-native", "status"], 1.0, "Read persistent state cache; refresh full state in background."),
    ("actions-probe", "Actions native availability", ["bin/seven-actions-native", "--probe"], 1.5, "Load the local action registry only."),
    ("spotlight-probe", "Spotlight native availability", ["bin/seven-spotlight-native", "--probe"], 1.5, "Probe GTK only; build the catalog from cache or after opening."),
    ("spotlight-catalog", "Spotlight catalog", ["bin/seven-spotlight", "catalog"], 2.0, "Keep catalog sources local and cache desktop, action, file and clipboard rows."),
    ("store-state", "SevenStore state", ["bin/seven-store-native", "--json"], 2.0, "Keep catalog local and search/install checks explicit."),
    ("launchpad-probe", "Launchpad availability", ["bin/seven-launchpad-native", "--probe"], 1.5, "Avoid scanning every desktop source before the window appears."),
    ("launchpad-doctor", "Launchpad catalog diagnostics", ["bin/seven-launchpad-native", "--doctor", "--json"], 2.0, "Use cached app rows immediately and refresh/dedupe in the background."),
    ("profile-current", "Active profile", ["profiles/profile-manager.sh", "current", "--json"], 1.0, "Read profile.env/profile-ui first; defer package counts."),
    ("profile-list", "Profile list", ["profiles/profile-manager.sh", "list", "--json"], 3.0, "Cache package readiness and refresh per profile after display."),
    ("baobab-probe", "Baobab native availability", ["bin/seven-baobab-native", "--probe"], 1.5, "Probe GTK only; load cultural data after the shell appears."),
]

DEEP_AUDITS = [
    ("state-full", "Full SevenOS state", ["scripts/state.sh", "--json"], 15.0, "Use only for refresh/doctor/export, not app startup."),
    ("health-full", "Full SevenOS health", ["scripts/health.sh", "status", "--json"], 25.0, "Use SEVENOS_HEALTH_FAST=1 for UI, full health for Doctor."),
    ("readiness-full", "Full readiness", ["scripts/readiness.sh", "--json"], 6.0, "Cache readiness score and expose manual refresh."),
]


def run_case(row, critical: bool) -> dict:
    key, label, command, threshold, solution = row
    full_command = [str(ROOT / command[0]), *command[1:]]
    start = time.perf_counter()
    returncode = 0
    try:
        result = subprocess.run(
            full_command,
            cwd=ROOT,
            env={**os.environ, "SEVENOS_ROOT": str(ROOT), "SEVENOS_DRY_RUN": "0"},
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=max(threshold + (20.0 if not critical else 8.0), 10.0),
            check=False,
        )
        returncode = result.returncode
        state = "OK" if result.returncode == 0 else "ERROR"
    except subprocess.TimeoutExpired:
        returncode = 124
        state = "TIMEOUT"
    seconds = round(time.perf_counter() - start, 3)
    if state == "OK" and seconds > threshold:
        state = "SLOW"
    return {
        "key": key,
        "label": label,
        "seconds": seconds,
        "threshold": threshold,
        "state": state,
        "critical": critical,
        "command": " ".join(command),
        "solution": solution,
        "returncode": returncode,
    }


public = [run_case(row, True) for row in PUBLIC_SURFACES]
deep = [run_case(row, False) for row in DEEP_AUDITS]
failures = [item for item in public if item["state"] != "OK"]
warnings = [item for item in deep if item["state"] != "OK"]
payload = {
    "schema": "sevenos.startup-audit.v1",
    "state": "ready" if not failures else "needs-optimization",
    "summary": {
        "public": len(public),
        "public_ok": sum(1 for item in public if item["state"] == "OK"),
        "public_slow": sum(1 for item in public if item["state"] == "SLOW"),
        "deep": len(deep),
        "deep_slow": len(warnings),
    },
    "public_surfaces": public,
    "deep_audits": deep,
    "failures": failures,
    "warnings": warnings,
    "rule": [
        "display from cache or local contracts first",
        "refresh live data in background",
        "keep full audits behind explicit refresh/doctor actions",
        "never block startup on state, health, readiness, pacman, flatpak or virsh",
    ],
}

if JSON_OUTPUT:
    print(json.dumps(payload, indent=2))
else:
    print("SevenOS startup audit")
    print("======================")
    print(f"State: {payload['state']}")
    print("")
    print("Public surfaces:")
    for item in public:
        print(f"- {item['state']:<7} {item['seconds']:>5.2f}s / {item['threshold']:>4.1f}s  {item['label']}")
        if item["state"] != "OK":
            print(f"  Solution: {item['solution']}")
    print("")
    print("Deep audits:")
    for item in deep:
        print(f"- {item['state']:<7} {item['seconds']:>5.2f}s / {item['threshold']:>4.1f}s  {item['label']}")
        if item["state"] != "OK":
            print(f"  Note: {item['solution']}")

sys.exit(1 if failures else 0)
PY
