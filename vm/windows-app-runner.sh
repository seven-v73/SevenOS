#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
VM_NAME="${SEVENOS_WINDOWS_VM:-sevenos-windows}"
ACTION="${1:-catalog}"
shift || true
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/windows"
PREFIX_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/sevenos/windows/prefixes"

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

network_state() {
  if command -v curl >/dev/null 2>&1; then
    curl -L --connect-timeout 3 --max-time 5 -I https://www.microsoft.com >/dev/null 2>&1 && printf 'OK' || printf 'WARN'
    return 0
  fi
  ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && printf 'OK' || printf 'WARN'
}

disk_state() {
  local available_kb
  available_kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  [[ "${available_kb:-0}" -ge 10485760 ]] && printf 'OK' || printf 'WARN'
}

safe_id() {
  printf '%s' "${1:-generic-exe}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+|-+$//g'
}

prefix_for_app() {
  printf '%s/%s' "$PREFIX_ROOT" "$(safe_id "$1")"
}

log_for_app() {
  mkdir -p "$STATE_DIR/logs"
  printf '%s/%s-%s.log' "$STATE_DIR/logs" "$(safe_id "$1")" "$(date +%Y%m%d-%H%M%S)"
}

prepare_log_for_app() {
  mkdir -p "$STATE_DIR/logs"
  printf '%s/prepare-%s-%s.log' "$STATE_DIR/logs" "$(safe_id "$1")" "$(date +%Y%m%d-%H%M%S)"
}

latest_log_for_app() {
  local app_id
  app_id="$(safe_id "$1")"
  find "$STATE_DIR/logs" -maxdepth 1 -type f -name "$app_id-*.log" 2>/dev/null | sort | tail -n 1
}

prepared_marker() {
  local app_id="$1"
  printf '%s/.sevenos-prepared-%s' "$(prefix_for_app "$app_id")" "$app_id"
}

prefix_has_office_components() {
  local prefix="$1"
  local log="$prefix/winetricks.log"
  [[ -f "$log" ]] || return 1
  grep -qx 'win10' "$log" &&
    grep -qx 'corefonts' "$log" &&
    grep -qx 'msxml6' "$log" &&
    grep -qx 'vcrun2019' "$log" &&
    grep -qx 'riched20' "$log"
}

prefix_prepared() {
  local app_id="$1"
  local prefix
  prefix="$(prefix_for_app "$app_id")"
  [[ -f "$(prepared_marker "$app_id")" ]] && return 0
  if [[ "$app_id" == "office" ]] && prefix_has_office_components "$prefix"; then
    return 0
  fi
  [[ -d "$prefix/drive_c/windows" ]]
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
  seven windows prepare office
  seven windows diagnose OfficeSetup.exe

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
    "$(command_state winetricks)" \
    "$(command_state wineboot)" \
    "$(network_state)" \
    "$(disk_state)" \
    "$(command_state firejail)" \
    "$(command_state distrobox)" \
    "$(vm_state)" \
    "$VM_NAME" <<'PY'
import json
import os
import sys

target, wine, lutris, flatpak, bottles, proton, winetricks, wineboot, network, disk, firejail, distrobox, vm, vm_name = sys.argv[1:15]

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
    "winetricks": winetricks,
    "wineboot": wineboot,
    "network": network,
    "disk": disk,
    "firejail": firejail,
    "distrobox": distrobox,
    "vm": vm,
}

target_path = os.path.expanduser(target)
ext = os.path.splitext(target_path)[1].lower()
is_windows_binary = ext in {".exe", ".msi", ".bat", ".cmd"}
exists = os.path.exists(target_path)
basename = os.path.basename(target).lower()
key = os.path.splitext(basename)[0] if is_windows_binary else basename
if any(token in basename for token in ("officesetup", "microsoft365", "office365", "office_setup", "setup.office")):
    key = "office"
elif key in {"winword", "word"}:
    key = "word"
elif key in {"excel"}:
    key = "excel"
name, preferred, profile, requirement = catalog.get(
    key,
    ("Windows executable" if is_windows_binary else target, ["wine", "bottles", "vm"], "Windows", "Path to .exe/.msi or configured bottle/app"),
)

available = []
for engine in preferred:
    state = states.get(engine, "MISS")
    if state in {"OK", "RUN"}:
        available.append(engine)

if is_windows_binary and states.get("wine") == "OK":
    engine = "wine"
elif available:
    engine = available[0]
else:
    engine = preferred[0]
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
if key in {"office", "word", "excel"}:
    if states.get("network") != "OK":
        blockers.append({"key": "network", "state": states["network"], "action": "Check internet access before running the Microsoft 365 online installer"})
    if states.get("disk") != "OK":
        blockers.append({"key": "disk", "state": states["disk"], "action": "Free at least 10 GB before installing Microsoft Office"})
    if states.get("winetricks") != "OK":
        blockers.append({"key": "winetricks", "state": states["winetricks"], "action": "seven profile install windows"})
    if states.get("wineboot") != "OK":
        blockers.append({"key": "wineboot", "state": states["wineboot"], "action": "seven profile install windows"})
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
        "prefix": "office" if key in {"office", "word", "excel"} else key if key in catalog else "generic",
        "daily_use": key in {"office", "word", "excel", "photoshop", "illustrator", "flstudio", "ableton"},
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
    "prepare_command": "seven windows prepare office" if key in {"office", "word", "excel"} else "seven windows prepare " + (key if key in catalog else "generic"),
    "diagnose_command": "seven windows diagnose " + target,
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
if data.get("prepare_command"):
    print(f"Prepare: {data.get('prepare_command')}")
if data.get("diagnose_command"):
    print(f"Diagnose: {data.get('diagnose_command')}")
blockers = data.get("blockers", [])
if blockers:
    print()
    print("Next actions:")
    for item in blockers:
        print(f"  - {item.get('action')}")
PY
}

json_field() {
  local field="$1"
  python -c "import json,sys; data=json.load(sys.stdin); cur=data$field; print(cur if cur is not None else '')"
}

prepare_app() {
  local app_id="${1:-generic}"
  app_id="$(safe_id "$app_id")"
  [[ "$app_id" == "word" || "$app_id" == "excel" ]] && app_id="office"
  local force="${SEVENOS_WINDOWS_FORCE_PREPARE:-0}"
  local prefix marker prep_log
  prefix="$(prefix_for_app "$app_id")"
  marker="$(prepared_marker "$app_id")"

  if dry_run; then
    dry_line "Prepare Windows prefix $app_id"
    printf 'WINEPREFIX=%q WINEARCH=win64 wineboot -u\n' "$prefix"
    if [[ "$app_id" == "office" ]]; then
      printf 'WINEPREFIX=%q winetricks -q settings win10 corefonts msxml6 vcrun2019 riched20 > prepare log\n' "$prefix"
    fi
    return 0
  fi

  if ! command -v wine >/dev/null 2>&1; then
    printf 'Wine is not installed yet.\nRun: seven profile install windows\n' >&2
    return 1
  fi

  mkdir -p "$prefix"
  if [[ "$force" != "1" ]] && prefix_prepared "$app_id"; then
    touch "$marker" 2>/dev/null || true
    printf 'SevenOS Windows: %s prefix already ready.\n' "$app_id"
    printf 'Prefix: %s\n' "$prefix"
    return 0
  fi

  prep_log="$(prepare_log_for_app "$app_id")"
  printf 'SevenOS Windows: preparing %s prefix\n' "$app_id"
  printf 'Prefix: %s\n' "$prefix"
  printf 'Log: %s\n' "$prep_log"
  WINEPREFIX="$prefix" WINEARCH=win64 wineboot -u >>"$prep_log" 2>&1 || true

  if [[ "$app_id" == "office" ]]; then
    if command -v winetricks >/dev/null 2>&1; then
      printf 'SevenOS Windows: installing Office runtime components. This can take a few minutes.\n'
      WINEPREFIX="$prefix" winetricks -q settings win10 corefonts msxml6 vcrun2019 riched20 >>"$prep_log" 2>&1 || true
    else
      printf 'Winetricks is missing. Run: seven profile install windows\n' >&2
      return 1
    fi
  fi

  touch "$marker" 2>/dev/null || true
  printf 'SevenOS Windows: prefix ready.\n'
}

diagnose_app() {
  local target="${1:-office}"
  local resolved app_id app_name prefix latest net disk prep_state process_state
  resolved="$(resolve_json "$target")"
  app_id="$(json_field "['app']['id']" <<<"$resolved")"
  app_name="$(json_field "['app']['name']" <<<"$resolved")"
  [[ "$app_id" == "word" || "$app_id" == "excel" ]] && app_id="office"
  prefix="$(prefix_for_app "$app_id")"
  latest="$(latest_log_for_app "$app_id")"
  net="$(network_state)"
  disk="$(disk_state)"
  prefix_prepared "$app_id" && prep_state="OK" || prep_state="MISS"
  if pgrep -af "OfficeSetup|ClickToRun|OfficeC2R|${target}" 2>/dev/null |
    grep -vE 'seven-windows-assistant|windows-app-runner|sed -n|pgrep -af' >/dev/null; then
    process_state="RUN"
  elif pgrep -af "WINEPREFIX=$prefix|$prefix" 2>/dev/null |
    grep -vE 'seven-windows-assistant|windows-app-runner|sed -n|pgrep -af' >/dev/null; then
    process_state="RUN"
  else
    process_state="STOP"
  fi

  printf 'SevenOS Windows Diagnostic\n'
  printf '==========================\n'
  printf 'App:      %s\n' "$app_name"
  printf 'Target:   %s\n' "$target"
  printf 'Prefix:   %s\n' "$prefix"
  printf 'Prepared: %s\n' "$prep_state"
  printf 'Process:  %s\n' "$process_state"
  printf 'Network:  %s\n' "$net"
  printf 'Disk:     %s\n' "$disk"
  printf 'Wine:     %s\n' "$(command_state wine)"
  printf 'Bottles:  %s\n' "$(flatpak_app_state com.usebottles.bottles)"
  printf 'VM:       %s\n' "$(vm_state)"
  printf '\n'

  if [[ -n "$latest" && -f "$latest" ]]; then
    printf 'Latest log: %s\n' "$latest"
    if grep -qiE 'FileNotFoundException|Windows, Version=255\.255\.255\.255|wine-mono|Unhandled Exception|page fault|C2R|Click-to-Run|InspectorOfficeGadget' "$latest"; then
      cat <<'EOF'

Conclusion:
  The Microsoft 365 Click-to-Run installer is crashing inside Wine/Mono.
  This is different from a simple network or disk-space problem: the online
  installer starts, then fails on Windows-specific .NET/Click-to-Run pieces.

Detected clues:
EOF
      grep -iE 'FileNotFoundException|Windows, Version=255\.255\.255\.255|wine-mono|Unhandled Exception|page fault|C2R|Click-to-Run|InspectorOfficeGadget' "$latest" | tail -n 10 | sed 's/^/  - /'
    elif grep -qiE '0-2031|17004|network|download|connection|space|disk|msi|error' "$latest"; then
      printf '\nDetected clues:\n'
      grep -iE '0-2031|17004|network|download|connection|space|disk|msi|error' "$latest" | tail -n 10 | sed 's/^/  - /'
    else
      printf '\nLast log lines:\n'
      tail -n 12 "$latest" | sed 's/^/  - /'
    fi
  else
    printf 'Latest log: none yet\n'
  fi

  if [[ "$app_id" == "office" ]]; then
    cat <<'EOF'

Office guidance:
  - SevenOS has prepared a dedicated Office prefix and common runtime components.
  - Microsoft 365 online installers remain fragile under plain Wine.
  - For daily Office use, the reliable SevenOS path is Bottles first, then
    Windows VM mode when Click-to-Run keeps crashing.

Recommended next commands:
  seven windows apps
  seven windows vm
  seven windows guide
EOF
  else
    cat <<'EOF'

Recommended next commands:
  seven windows resolve APP
  seven windows prepare APP
  seven windows run APP
  seven windows apps
EOF
  fi
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

  local resolved engine ready target_path app_id prefix log_file
  resolved="$(resolve_json "$target")"
  engine="$(python -c 'import json,sys; print(json.load(sys.stdin).get("engine","missing"))' <<<"$resolved")"
  ready="$(python -c 'import json,sys; print(str(json.load(sys.stdin).get("ready", False)).lower())' <<<"$resolved")"
  app_id="$(json_field "['app']['id']" <<<"$resolved")"
  [[ "$app_id" == "word" || "$app_id" == "excel" ]] && app_id="office"

  if [[ "$ready" != "true" ]] && ! dry_run; then
    WINDOWS_APP_RESOLVE="$resolved" python - <<'PY' >&2
import json
import os

data = json.loads(os.environ["WINDOWS_APP_RESOLVE"])
app = data.get("app", {})
print("SevenOS could not launch this Windows app yet.")
print(f"App: {app.get('name', data.get('target'))}")
print(f"Reason: {len(data.get('blockers', []))} setup item(s) need attention.")
for item in data.get("blockers", []):
    print(f"  - {item.get('action')}")
print()
print(f"Prepare: {data.get('prepare_command')}")
print(f"Diagnose: {data.get('diagnose_command')}")
PY
    return 1
  fi

  target_path="${target/#\~/$HOME}"

  case "$engine" in
    wine)
      prefix="$(prefix_for_app "$app_id")"
      log_file="$(log_for_app "$app_id")"
      if [[ "${SEVENOS_WINDOWS_AUTO_PREPARE:-1}" == "1" ]] && ! prefix_prepared "$app_id"; then
        prepare_app "$app_id"
      fi
      local wine_command=(env WINEPREFIX="$prefix" WINEARCH=win64 WINEDEBUG="${SEVENOS_WINEDEBUG:--all}" wine "$target_path" "$@")
      if [[ "${SEVENOS_WINDOWS_SANDBOX:-0}" == "1" ]] && command -v firejail >/dev/null 2>&1; then
        wine_command=(firejail --quiet "${wine_command[@]}")
      fi
      if dry_run; then
        dry_line "Launch $target through Wine"
        printf 'WINEPREFIX=%q wine %q\n' "$prefix" "$target_path"
      else
        printf 'SevenOS Windows: launching %s\n' "$target"
        printf 'Engine: Wine · Prefix: %s\n' "$prefix"
        printf 'Log: %s\n' "$log_file"
        printf 'If it fails, run: seven windows diagnose %q\n' "$target"
        nohup "${wine_command[@]}" >"$log_file" 2>&1 &
      fi
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
  prepare)
    prepare_app "${1:-generic}"
    ;;
  diagnose|doctor)
    diagnose_app "${1:-office}"
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
