#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS installer stack

Usage:
  ./scripts/installer-stack.sh [status|install|doctor|plan|guide|release|graphical] [--json]

Actions:
  status   Show installer tooling state
  status --json
           Show machine-readable installer tooling state
  install  Install official installer foundation packages
  doctor   Validate SevenOS installer foundation
  plan     Explain Calamares + Archinstall next steps
  plan --json
           Show prioritized installer/ISO productization actions
  guide    Show the normal-user install path SevenOS exposes today
  release  Show public-ISO release readiness checks
  graphical
           Show graphical installer route readiness
EOF
}

JSON_OUTPUT=0

state() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 && printf OK || printf MISS
}

file_state() {
  local path="$1"
  [[ -s "$ROOT_DIR/$path" ]] && printf OK || printf MISS
}

dir_state() {
  local path="$1"
  [[ -d "$ROOT_DIR/$path" ]] && printf OK || printf MISS
}

contains_state() {
  local path="$1"
  local pattern="$2"
  [[ -s "$ROOT_DIR/$path" ]] && grep -Fq "$pattern" "$ROOT_DIR/$path" && printf OK || printf MISS
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

release_json() {
  local archinstall_state calamares_state planner_state calamares_settings_state calamares_module_state calamares_postinstall_state
  local archiso_state build_state packages_state repo_injection_state live_cli_state graphical_launcher_state live_desktop_state calamares_branding_state

  archinstall_state="$(state archinstall)"
  calamares_state="$(state calamares)"
  planner_state="$([[ -x "$ROOT_DIR/installer/plan.sh" ]] && printf OK || printf MISS)"
  calamares_settings_state="$(file_state installer/calamares/settings.conf)"
  calamares_module_state="$(file_state installer/calamares/modules/sevenos.conf)"
  calamares_postinstall_state="$(contains_state installer/calamares/modules/sevenos.conf "/opt/SevenOS/install.sh base")"
  graphical_launcher_state="$([[ -x "$ROOT_DIR/bin/seven-installer" ]] && printf OK || printf MISS)"
  live_desktop_state="$(contains_state archiso/profile/airootfs/usr/share/applications/seven-installer.desktop "Exec=seven-installer")"
  calamares_branding_state="$(file_state installer/calamares/branding/sevenos/branding.desc)"
  archiso_state="$(dir_state archiso/profile)"
  build_state="$([[ -x "$ROOT_DIR/scripts/build-iso.sh" ]] && printf OK || printf MISS)"
  packages_state="$(file_state archiso/profile/packages.x86_64)"
  repo_injection_state="$(contains_state scripts/build-iso.sh "/opt/SevenOS")"
  live_cli_state="$(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "/opt/SevenOS/bin/seven")"

  ARCHINSTALL_STATE="$archinstall_state" \
  CALAMARES_STATE="$calamares_state" \
  PLANNER_STATE="$planner_state" \
  CALAMARES_SETTINGS_STATE="$calamares_settings_state" \
  CALAMARES_MODULE_STATE="$calamares_module_state" \
  CALAMARES_POSTINSTALL_STATE="$calamares_postinstall_state" \
  GRAPHICAL_LAUNCHER_STATE="$graphical_launcher_state" \
  LIVE_DESKTOP_STATE="$live_desktop_state" \
  CALAMARES_BRANDING_STATE="$calamares_branding_state" \
  ARCHISO_STATE="$archiso_state" \
  BUILD_STATE="$build_state" \
  PACKAGES_STATE="$packages_state" \
  REPO_INJECTION_STATE="$repo_injection_state" \
  LIVE_CLI_STATE="$live_cli_state" \
  python - <<'PY'
import json
import os

checks = [
    {
        "key": "archinstall-runtime",
        "state": os.environ["ARCHINSTALL_STATE"],
        "required": True,
        "title": "Guided TUI backend",
        "command": "seven installer install",
    },
    {
        "key": "calamares-runtime",
        "state": os.environ["CALAMARES_STATE"],
        "required": False,
        "title": "Graphical installer runtime",
        "command": "seven installer plan",
    },
    {
        "key": "installer-planner",
        "state": os.environ["PLANNER_STATE"],
        "required": True,
        "title": "Non-destructive install planner",
        "command": "seven installer doctor",
    },
    {
        "key": "calamares-settings",
        "state": os.environ["CALAMARES_SETTINGS_STATE"],
        "required": True,
        "title": "Calamares module sequence",
        "command": "seven installer doctor",
    },
    {
        "key": "calamares-sevenos-module",
        "state": os.environ["CALAMARES_MODULE_STATE"],
        "required": True,
        "title": "SevenOS Calamares post-install module",
        "command": "seven installer doctor",
    },
    {
        "key": "calamares-postinstall",
        "state": os.environ["CALAMARES_POSTINSTALL_STATE"],
        "required": True,
        "title": "SevenOS base install hook",
        "command": "seven installer doctor",
    },
    {
        "key": "graphical-launcher",
        "state": os.environ["GRAPHICAL_LAUNCHER_STATE"],
        "required": True,
        "title": "SevenOS graphical installer launcher",
        "command": "seven installer graphical",
    },
    {
        "key": "live-desktop-entry",
        "state": os.environ["LIVE_DESKTOP_STATE"],
        "required": True,
        "title": "Live ISO installer desktop entry",
        "command": "seven installer graphical",
    },
    {
        "key": "calamares-branding",
        "state": os.environ["CALAMARES_BRANDING_STATE"],
        "required": True,
        "title": "SevenOS Calamares branding",
        "command": "seven installer graphical",
    },
    {
        "key": "archiso-profile",
        "state": os.environ["ARCHISO_STATE"],
        "required": True,
        "title": "Archiso live profile",
        "command": "seven installer doctor",
    },
    {
        "key": "iso-builder",
        "state": os.environ["BUILD_STATE"],
        "required": True,
        "title": "ISO build script",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "iso-packages",
        "state": os.environ["PACKAGES_STATE"],
        "required": True,
        "title": "Live ISO package list",
        "command": "seven installer doctor",
    },
    {
        "key": "repo-injection",
        "state": os.environ["REPO_INJECTION_STATE"],
        "required": True,
        "title": "SevenOS repository injection",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-cli",
        "state": os.environ["LIVE_CLI_STATE"],
        "required": True,
        "title": "Live CLI bootstrap",
        "command": "seven installer doctor",
    },
]

required = [item for item in checks if item["required"]]
required_ok = sum(1 for item in required if item["state"] == "OK")
optional_ok = sum(1 for item in checks if not item["required"] and item["state"] == "OK")
score = round(((required_ok / max(len(required), 1)) * 85) + (optional_ok * 15))
if score >= 95:
    state = "graphical-ready"
elif required_ok == len(required):
    state = "tui-release-ready"
elif score >= 70:
    state = "iso-foundation"
else:
    state = "foundation"

print(json.dumps({
    "schema": "sevenos.installer-release.v1",
    "state": state,
    "score": min(score, 100),
    "required_ready": required_ok,
    "required_total": len(required),
    "optional_ready": optional_ok,
    "optional_total": len(checks) - len(required),
    "checks": checks,
}, indent=2))
PY
}

status() {
  if [[ "$JSON_OUTPUT" -eq 1 && -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    exec "$ROOT_DIR/bin/seven-daemon" installer --json
  fi

  local archinstall_state calamares_state planner_state profile_state archiso_state build_state packages_state
  archinstall_state="$(state archinstall)"
  calamares_state="$(state calamares)"
  planner_state="$([[ -x "$ROOT_DIR/installer/plan.sh" ]] && printf OK || printf MISS)"
  profile_state="$(dir_state installer/calamares)"
  archiso_state="$(dir_state archiso/profile)"
  build_state="$([[ -x "$ROOT_DIR/scripts/build-iso.sh" ]] && printf OK || printf MISS)"
  packages_state="$(file_state archiso/profile/packages.x86_64)"

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    local release_payload
    release_payload="$(release_json)"
    printf '{'
    printf '"schema":"sevenos.installer.v1",'
    printf '"tooling":['
    printf '{"key":"archinstall","state":%s},' "$(printf '%s' "$archinstall_state" | json_string)"
    printf '{"key":"calamares","state":%s}' "$(printf '%s' "$calamares_state" | json_string)"
    printf '],'
    printf '"foundation":['
    printf '{"key":"planner","state":%s},' "$(printf '%s' "$planner_state" | json_string)"
    printf '{"key":"calamares-profile","state":%s},' "$(printf '%s' "$profile_state" | json_string)"
    printf '{"key":"archiso-profile","state":%s},' "$(printf '%s' "$archiso_state" | json_string)"
    printf '{"key":"iso-builder","state":%s},' "$(printf '%s' "$build_state" | json_string)"
    printf '{"key":"iso-packages","state":%s}' "$(printf '%s' "$packages_state" | json_string)"
    printf '],'
    printf '"ready":%s,' "$([[ "$archinstall_state" == OK && "$planner_state" == OK && "$archiso_state" == OK && "$build_state" == OK ]] && printf true || printf false)"
    printf '"mode":%s,' "$(if [[ "$calamares_state" == OK ]]; then printf graphical | json_string; elif [[ "$archinstall_state" == OK ]]; then printf tui-ready | json_string; else printf foundation | json_string; fi)"
    printf '"consumer_path":%s,' "$(if [[ "$calamares_state" == OK ]]; then printf graphical-calamares | json_string; elif [[ "$archinstall_state" == OK ]]; then printf guided-tui | json_string; else printf planned | json_string; fi)"
    printf '"release":%s,' "$release_payload"
    printf '"commands":{"status":"seven installer status","plan":"seven installer plan","guide":"seven installer guide","doctor":"seven installer doctor"}'
    printf '}\n'
    return 0
  fi

  printf 'SevenOS Installer Stack\n'
  printf '=======================\n'
  printf 'archinstall: %s\n' "$archinstall_state"
  printf 'calamares:   %s\n' "$calamares_state"
  printf 'planner:     %s\n' "$planner_state"
  printf 'profile:     %s\n' "$profile_state"
  printf 'archiso:     %s\n' "$archiso_state"
  printf 'iso builder: %s\n' "$build_state"
  printf 'consumer:    %s\n' "$(if [[ "$calamares_state" == OK ]]; then printf graphical-calamares; elif [[ "$archinstall_state" == OK ]]; then printf guided-tui; else printf planned; fi)"
  printf 'release:     %s\n' "$(release_json | python -c 'import json,sys; print(json.load(sys.stdin)["state"])')"
}

release_status() {
  local release_payload
  release_payload="$(release_json)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '%s\n' "$release_payload"
    return 0
  fi
  RELEASE_JSON="$release_payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["RELEASE_JSON"])
print("SevenOS Installer Release Readiness")
print("====================================")
print(f"State:    {data.get('state')}")
print(f"Score:    {data.get('score')}%")
print(f"Required: {data.get('required_ready')}/{data.get('required_total')}")
print(f"Optional: {data.get('optional_ready')}/{data.get('optional_total')}")
print()
print(f"{'Check':<26} {'State':<5} {'Required'}")
print(f"{'-----':<26} {'-----':<5} {'--------'}")
for item in data.get("checks", []):
    print(f"{item.get('key',''):<26} {item.get('state',''):<5} {'yes' if item.get('required') else 'no'}")
    if item.get("state") != "OK":
        print(f"{'':<26} {'':<5} {item.get('command', '')}")
PY
}

install_stack() {
  install_package_file "$ROOT_DIR/scripts/packages-installer.txt"
}

graphical() {
  local release_payload
  release_payload="$(release_json)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    RELEASE_JSON="$release_payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["RELEASE_JSON"])
keys = {
    "calamares-runtime",
    "calamares-settings",
    "calamares-sevenos-module",
    "calamares-postinstall",
    "graphical-launcher",
    "live-desktop-entry",
    "calamares-branding",
}
checks = [item for item in data.get("checks", []) if item.get("key") in keys]
print(json.dumps({
    "schema": "sevenos.installer-graphical.v1",
    "state": "graphical-ready" if all(item.get("state") == "OK" for item in checks) else "graphical-profile-ready",
    "runtime": next((item.get("state") for item in checks if item.get("key") == "calamares-runtime"), "MISS"),
    "checks": checks,
    "command": "seven-installer",
}, indent=2))
PY
    return 0
  fi

  RELEASE_JSON="$release_payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["RELEASE_JSON"])
keys = (
    "calamares-runtime",
    "calamares-settings",
    "calamares-sevenos-module",
    "calamares-postinstall",
    "graphical-launcher",
    "live-desktop-entry",
    "calamares-branding",
)
checks = [item for item in data.get("checks", []) if item.get("key") in keys]
runtime = next((item for item in checks if item.get("key") == "calamares-runtime"), {})
profile_ok = all(item.get("state") == "OK" for item in checks if item.get("key") != "calamares-runtime")
print("SevenOS Graphical Installer Route")
print("=================================")
print(f"State: {'graphical-ready' if profile_ok and runtime.get('state') == 'OK' else 'graphical-profile-ready'}")
print(f"Calamares runtime: {runtime.get('state', 'MISS')}")
print()
for item in checks:
    print(f"{item.get('state', 'MISS'):<5} {item.get('key', ''):<24} {item.get('title', '')}")
PY
}

guide() {
  cat <<'EOF'
SevenOS install guide
=====================

Current user path:
  1. Start from the SevenOS live or test environment.
  2. Run `seven installer plan` to preview disk, user, locale, boot and profile choices.
  3. Run `seven installer doctor` before any destructive install step.
  4. Use Archinstall as the guided TUI backend today.
  5. Keep Calamares as the graphical installer target for public ISO builds.

Design rule:
  SevenOS must keep destructive disk operations behind explicit confirmation.
  Settings and Hub may show installer status, but they should not silently format
  disks or rewrite bootloaders.
EOF
}

doctor() {
  local failures=0
  local path

  status
  printf '\nFoundation files:\n'
  for path in \
    "installer/README.md" \
    "installer/plan.sh" \
    "installer/validate-plan.sh" \
    "installer/generate-script.sh" \
    "installer/calamares/settings.conf" \
    "installer/calamares/modules/sevenos.conf" \
    "scripts/packages-installer.txt"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  for path in \
    "bin/seven-installer" \
    "archiso/profile/airootfs/usr/share/applications/seven-installer.desktop" \
    "installer/calamares/branding/sevenos/branding.desc"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  if [[ "$failures" -gt 0 ]]; then
    log_error "Installer stack has $failures issue(s)."
    return 1
  fi

  log_success "Installer stack foundation is coherent."
}

plan() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
      exec "$ROOT_DIR/bin/seven-daemon" installer-plan --json
    fi
    INSTALLER_STATUS="$(JSON_OUTPUT=1 status)" python - <<'PY'
import json
import os

status = json.loads(os.environ["INSTALLER_STATUS"])
states = {item["key"]: item["state"] for item in status.get("tooling", []) + status.get("foundation", [])}
release = status.get("release", {})

metadata = {
    "archinstall": {
        "title": "Install Archinstall automation",
        "severity": "high",
        "impact": "packages",
        "phase": "automation",
        "command": "seven installer install",
        "reason": "Archinstall gives SevenOS an official automation backend before destructive disk flows are enabled.",
    },
    "calamares": {
        "title": "Package Calamares installer",
        "severity": "medium",
        "impact": "packages",
        "phase": "gui",
        "command": "seven installer plan",
        "reason": "Calamares is the graphical path for public ISO installation, but packaging remains a downstream step.",
    },
    "planner": {
        "title": "Restore installer planner",
        "severity": "critical",
        "impact": "changes",
        "phase": "planner",
        "command": "seven installer doctor",
        "reason": "SevenOS needs a non-destructive install plan before generating disk steps.",
    },
    "calamares-profile": {
        "title": "Restore Calamares profile",
        "severity": "high",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer doctor",
        "reason": "The graphical installer profile must travel with the ISO.",
    },
    "archiso-profile": {
        "title": "Restore Archiso profile",
        "severity": "critical",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "SevenOS cannot produce a live ISO without an Archiso profile.",
    },
    "iso-builder": {
        "title": "Restore ISO build script",
        "severity": "critical",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "The ISO builder is the bridge from repository to bootable SevenOS media.",
    },
    "iso-packages": {
        "title": "Restore ISO package list",
        "severity": "high",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "The live image needs an explicit package set for repeatable builds.",
    },
    "graphical-launcher": {
        "title": "Restore graphical installer launcher",
        "severity": "high",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer graphical",
        "reason": "The live ISO needs a user-facing Install SevenOS entrypoint.",
    },
    "live-desktop-entry": {
        "title": "Restore live installer desktop entry",
        "severity": "high",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer graphical",
        "reason": "Normal users need a visible graphical installer launcher in the live session.",
    },
    "calamares-branding": {
        "title": "Restore SevenOS installer branding",
        "severity": "medium",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer graphical",
        "reason": "The graphical installer should identify itself as SevenOS instead of a generic Calamares flow.",
    },
}

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions = []
for key, state in states.items():
    if state == "OK":
        continue
    item = metadata[key]
    actions.append({
        "key": key,
        "state": state,
        "title": item["title"],
        "severity": item["severity"],
        "impact": item["impact"],
        "phase": item["phase"],
        "reason": item["reason"],
        "command": item["command"],
    })

actions.append({
    "key": "dry-run-iso",
    "state": "READY",
    "title": "Validate ISO dry-run",
    "severity": "medium",
    "impact": "safe",
    "phase": "iso",
    "reason": "Before moving to a public ISO, SevenOS should prove the build path without touching the host.",
    "command": "./install.sh iso --dry-run",
})

for check in release.get("checks", []):
    if check.get("state") == "OK":
        continue
    if check.get("key") in states:
        continue
    if check.get("key") == "calamares-runtime" and "calamares" in states:
        continue
    actions.append({
        "key": check.get("key", "release-check"),
        "state": check.get("state", "MISS"),
        "title": check.get("title", "Resolve installer release check"),
        "severity": "high" if check.get("required") else "medium",
        "impact": "safe" if check.get("command", "").endswith("--dry-run") else "changes",
        "phase": "release",
        "reason": "Public ISO readiness requires this installer release check to pass.",
        "command": check.get("command", "seven installer release"),
    })

actions.sort(key=lambda item: (rank.get(item["severity"], 9), item["phase"], item["key"]))

print(json.dumps({
    "schema": "sevenos.installer-plan.v1",
    "mode": status.get("mode", "foundation"),
    "ready": bool(status.get("ready")),
    "release": release,
    "summary": {
        "total": len(actions),
        "critical": sum(1 for item in actions if item["severity"] == "critical"),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
    },
    "next": actions,
}, indent=2))
PY
    return 0
  fi

  cat <<'EOF'
SevenOS installer direction
===========================

Primary path:
  1. Use Calamares for the graphical installer experience.
  2. Use the existing SevenOS install plan as the source of truth.
  3. Use Archinstall only as a secondary/automation backend where useful.

Why:
  - Calamares unlocks non-technical users.
  - Archinstall gives an official Arch automation path.
  - SevenOS keeps destructive disk steps behind explicit confirmation.

Next engineering steps:
  - package or source Calamares for the live ISO
  - map installer/plan.sh fields to Calamares modules
  - add a SevenOS post-install module that runs /opt/SevenOS/install.sh base
  - keep a dry-run installer script for development safety
EOF
}

action="${1:-status}"
shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown installer option: $arg"; usage; exit 1 ;;
  esac
done
case "$action" in
  status) status ;;
  install) install_stack ;;
  doctor) doctor ;;
  plan) plan ;;
  guide) guide ;;
  release) release_status ;;
  graphical) graphical ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown installer stack action: $action"; usage; exit 1 ;;
esac
