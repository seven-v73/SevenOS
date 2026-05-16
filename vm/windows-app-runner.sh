#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
VM_NAME="${SEVENOS_WINDOWS_VM:-sevenos-windows}"
ACTION="${1:-catalog}"
shift || true

dry_run() {
  [[ "${SEVENOS_DRY_RUN:-0}" == "1" ]]
}

dry_line() {
  printf 'DRY-RUN > Windows App > %s\n' "$*"
}

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf 'OK' || printf 'MISS'
}

flatpak_app_state() {
  command -v flatpak >/dev/null 2>&1 && flatpak info "$1" >/dev/null 2>&1 && printf 'OK' || printf 'MISS'
}

vm_state() {
  if ! command -v virsh >/dev/null 2>&1; then
    printf 'MISS'
    return 0
  fi
  if ! virsh -c qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1; then
    printf 'MISS'
    return 0
  fi
  local state
  state="$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null || true)"
  case "$state" in
    running) printf 'RUN' ;;
    *) printf 'OK' ;;
  esac
}

proton_state() {
  if command -v proton >/dev/null 2>&1 || command -v protontricks-launch >/dev/null 2>&1 || command -v protontricks >/dev/null 2>&1; then
    printf 'OK'
    return 0
  fi
  compgen -G "$HOME/.steam/steam/steamapps/common/Proton*" >/dev/null 2>&1 && printf 'OK' || printf 'MISS'
}

app_catalog_tsv() {
  cat <<'EOF'
photoshop	Adobe Photoshop	Studio	bottles,wine,vm	Installer or existing bottle required	Heavy creative app; VM is optional fallback only.
illustrator	Adobe Illustrator	Studio	bottles,wine,vm	Installer or existing bottle required	Vector workflow; prefer Bottles before VM.
office	Microsoft Office	Forge	bottles,wine,vm	Installer or existing bottle required	Office suite; VM fallback for enterprise plugins.
word	Microsoft Word	Forge	bottles,wine,vm	Installer or existing bottle required	Office document workflow.
excel	Microsoft Excel	Forge	bottles,wine,vm	Installer or existing bottle required	Spreadsheet workflow.
flstudio	FL Studio	Studio	bottles,wine,vm	Installer or existing bottle required	Creative audio workflow.
ableton	Ableton Live	Studio	bottles,wine,vm	Installer or existing bottle required	Low-latency audio workflow; VM only if drivers require Windows.
steam	Steam Games	Gaming	proton,lutris,wine	Steam or Lutris required	Prefer Proton/Lutris for game compatibility.
epic	Epic Games	Gaming	lutris,wine,vm	Lutris required	Game launcher; prefer Lutris before VM.
generic-exe	Windows executable	Windows	wine,bottles,vm	Path to .exe or .msi	SevenOS can run a local installer/app without creating a VM.
EOF
}

usage() {
  cat <<'EOF'
SevenOS Windows App Layer

Usage:
  seven run <app-or-path> [args...]
  seven windows run <app-or-path> [args...]
  seven windows resolve <app-or-path> [--json]
  seven windows catalog [--json]

Goal:
  Launch Windows applications as SevenOS app workflows first, without making a
  Windows ISO mandatory. Wine, Bottles, Proton and Lutris are preferred before
  the optional Windows VM path.
EOF
}

catalog_json() {
  WINDOWS_APP_CATALOG="$(app_catalog_tsv)" python - <<'PY'
import json
import os
import sys

apps = []
for raw in os.environ.get("WINDOWS_APP_CATALOG", "").splitlines():
    raw = raw.rstrip("\n")
    if not raw:
        continue
    app_id, name, profiles, engines, requirement, note = raw.split("\t", 5)
    apps.append({
        "id": app_id,
        "name": name,
        "profiles": [item for item in profiles.split(",") if item],
        "preferred_engines": [item for item in engines.split(",") if item],
        "requirement": requirement,
        "note": note,
    })

print(json.dumps({
    "schema": "sevenos.windows-app-catalog.v1",
    "philosophy": "app-first, VM-optional",
    "apps": apps,
}, indent=2))
PY
}

catalog_human() {
  printf 'SevenOS Windows App Catalog\n'
  printf '===========================\n'
  printf 'VM policy: optional fallback, not the default path.\n\n'
  printf '%-14s %-22s %-12s %s\n' "App" "Name" "Profile" "Engines"
  printf '%-14s %-22s %-12s %s\n' "---" "----" "-------" "-------"
  app_catalog_tsv | while IFS=$'\t' read -r app_id name profiles engines _requirement _note; do
    printf '%-14s %-22s %-12s %s\n' "$app_id" "$name" "$profiles" "$engines"
  done
}

resolve_json() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    printf '{"schema":"sevenos.windows-app-resolve.v1","ready":false,"error":"missing target"}\n'
    return 1
  fi

  python - "$target" \
    "$(command_state wine)" \
    "$(command_state lutris)" \
    "$(command_state flatpak)" \
    "$(flatpak_app_state com.usebottles.bottles)" \
    "$(proton_state)" \
    "$(command_state firejail)" \
    "$(command_state distrobox)" \
    "$(vm_state)" \
    "$VM_NAME" <<'PY'
import json
import os
import sys

target, wine, lutris, flatpak, bottles, proton, firejail, distrobox, vm, vm_name = sys.argv[1:11]

catalog = {
    "photoshop": ("Adobe Photoshop", ["bottles", "wine", "vm"], "Studio", "Installer or existing bottle required"),
    "illustrator": ("Adobe Illustrator", ["bottles", "wine", "vm"], "Studio", "Installer or existing bottle required"),
    "office": ("Microsoft Office", ["bottles", "wine", "vm"], "Forge", "Installer or existing bottle required"),
    "word": ("Microsoft Word", ["bottles", "wine", "vm"], "Forge", "Installer or existing bottle required"),
    "excel": ("Microsoft Excel", ["bottles", "wine", "vm"], "Forge", "Installer or existing bottle required"),
    "flstudio": ("FL Studio", ["bottles", "wine", "vm"], "Studio", "Installer or existing bottle required"),
    "ableton": ("Ableton Live", ["bottles", "wine", "vm"], "Studio", "Installer or existing bottle required"),
    "steam": ("Steam Games", ["proton", "lutris", "wine"], "Gaming", "Steam, Proton or Lutris required"),
    "epic": ("Epic Games", ["lutris", "wine", "vm"], "Gaming", "Lutris required"),
}

states = {
    "wine": wine,
    "lutris": lutris,
    "flatpak": flatpak,
    "bottles": bottles,
    "proton": proton,
    "firejail": firejail,
    "distrobox": distrobox,
    "vm": vm,
}

target_path = os.path.expanduser(target)
ext = os.path.splitext(target_path)[1].lower()
is_windows_binary = ext in {".exe", ".msi", ".bat", ".cmd"}
exists = os.path.exists(target_path)
key = os.path.basename(target).lower()
key = os.path.splitext(key)[0] if is_windows_binary else key
name, preferred, profile, requirement = catalog.get(
    key,
    ("Windows executable" if is_windows_binary else target, ["wine", "bottles", "vm"], "Windows", "Path to .exe/.msi or configured bottle/app"),
)

available = []
for engine in preferred:
    state = states.get(engine, "MISS")
    if state in {"OK", "RUN"}:
        available.append(engine)

engine = available[0] if available else preferred[0]
ready = bool(available) and (not is_windows_binary or exists)

if engine == "wine":
    command = ["wine", target_path if is_windows_binary else target]
elif engine == "bottles":
    command = ["flatpak", "run", "com.usebottles.bottles"] if bottles == "OK" else ["bottles"]
elif engine == "proton":
    command = ["steam"] if os.system("command -v steam >/dev/null 2>&1") == 0 else ["lutris" if lutris == "OK" else "protontricks"]
elif engine == "lutris":
    command = ["lutris"]
else:
    command = ["virt-manager", "--connect", "qemu:///system", "--show-domain-console", vm_name]

blockers = []
if is_windows_binary and not exists:
    blockers.append({"key": "target_path", "state": "MISS", "action": "Provide a valid local .exe/.msi path"})
for candidate in preferred:
    if states.get(candidate, "MISS") not in {"OK", "RUN"}:
        if candidate == "bottles":
            blockers.append({"key": "bottles", "state": states[candidate], "action": "seven flatpak install"})
        elif candidate == "wine":
            blockers.append({"key": "wine", "state": states[candidate], "action": "seven profile install windows"})
        elif candidate == "proton":
            blockers.append({"key": "proton", "state": states[candidate], "action": "Install Steam/Proton or protontricks"})
        elif candidate == "lutris":
            blockers.append({"key": "lutris", "state": states[candidate], "action": "seven profile install windows"})
        elif candidate == "vm":
            blockers.append({"key": "windows_vm", "state": states[candidate], "action": "seven windows create --iso /path/windows.iso --virtio-iso /path/virtio-win.iso"})

print(json.dumps({
    "schema": "sevenos.windows-app-resolve.v1",
    "target": target,
    "app": {
        "id": key if key in catalog else "generic-exe" if is_windows_binary else key,
        "name": name,
        "profile": profile,
        "requirement": requirement,
    },
    "philosophy": "app-first, VM-optional",
    "ready": ready,
    "engine": engine,
    "available_engines": available,
    "preferred_engines": preferred,
    "native_window": engine in {"wine", "bottles", "proton", "lutris"},
    "iso_required": engine == "vm",
    "vm_optional": True,
    "sandbox": {
        "firejail": firejail,
        "distrobox": distrobox,
        "recommended": "firejail" if firejail == "OK" and engine == "wine" else "bottles" if engine == "bottles" else "none",
    },
    "states": states,
    "command": command,
    "blockers": blockers[:4],
}, indent=2))
PY
}

resolve_human() {
  local target="${1:-}"
  WINDOWS_APP_RESOLVE="$(resolve_json "$target")" python - <<'PY'
import json
import os

data = json.loads(os.environ["WINDOWS_APP_RESOLVE"])
app = data.get("app", {})
print("SevenOS Windows App Resolver")
print("===========================")
print(f"Target: {data.get('target')}")
print(f"App: {app.get('name')} · profile: {app.get('profile')}")
print(f"Engine: {data.get('engine')} · ready: {str(data.get('ready')).lower()}")
print(f"Native window: {str(data.get('native_window')).lower()} · VM optional: {str(data.get('vm_optional')).lower()}")
print(f"Command: {' '.join(data.get('command', []))}")
blockers = data.get("blockers", [])
if blockers:
    print()
    print("Next actions:")
    for item in blockers:
        print(f"  - {item.get('action')}")
PY
}

run_detached() {
  local label="$1"
  shift
  if dry_run; then
    dry_line "$label"
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  nohup "$@" >/dev/null 2>&1 &
}

run_app() {
  local target="${1:-}"
  shift || true
  if [[ -z "$target" ]]; then
    usage >&2
    return 1
  fi

  local resolved engine ready target_path
  resolved="$(resolve_json "$target")"
  engine="$(python -c 'import json,sys; print(json.load(sys.stdin).get("engine","missing"))' <<<"$resolved")"
  ready="$(python -c 'import json,sys; print(str(json.load(sys.stdin).get("ready", False)).lower())' <<<"$resolved")"

  if [[ "$ready" != "true" && ! dry_run ]]; then
    printf '%s\n' "$resolved" | python -m json.tool >&2
    return 1
  fi

  target_path="${target/#\~/$HOME}"

  case "$engine" in
    wine)
      local wine_command=(wine "$target_path" "$@")
      if command -v firejail >/dev/null 2>&1; then
        wine_command=(firejail --quiet --private-tmp "${wine_command[@]}")
      fi
      run_detached "Launch $target through Wine" "${wine_command[@]}"
      ;;
    bottles)
      if command -v flatpak >/dev/null 2>&1 && flatpak info com.usebottles.bottles >/dev/null 2>&1; then
        run_detached "Open Bottles for $target" flatpak run com.usebottles.bottles
      else
        run_detached "Open Bottles for $target" bottles
      fi
      ;;
    proton|lutris)
      if command -v lutris >/dev/null 2>&1; then
        run_detached "Open game compatibility surface for $target" lutris
      elif command -v steam >/dev/null 2>&1; then
        run_detached "Open game compatibility surface for $target" steam
      else
        run_detached "Open game compatibility surface for $target" protontricks
      fi
      ;;
    vm)
      run_detached "Open optional Windows VM for $target" virt-manager --connect qemu:///system --show-domain-console "$VM_NAME"
      ;;
    *)
      printf '%s\n' "$resolved" | python -m json.tool >&2
      return 1
      ;;
  esac
}

json_requested() {
  for item in "$@"; do
    [[ "$item" == "--json" ]] && return 0
  done
  return 1
}

strip_json_flag() {
  local item
  for item in "$@"; do
    [[ "$item" != "--json" ]] && printf '%s\n' "$item"
  done
}

case "$ACTION" in
  catalog|apps)
    if json_requested "$@"; then
      catalog_json
    else
      catalog_human
    fi
    ;;
  resolve)
    mapfile -t args < <(strip_json_flag "$@")
    if json_requested "$@"; then
      resolve_json "${args[0]:-}"
    else
      resolve_human "${args[0]:-}"
    fi
    ;;
  run|open)
    run_app "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    printf 'windows-app-runner: unknown action: %s\n\n' "$ACTION" >&2
    usage >&2
    exit 1
    ;;
esac
