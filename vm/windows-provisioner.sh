#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
ACTION="${1:-status}"
shift || true

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sevenos/vm/windows"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos/vm/windows"
STATE_FILE="$CONFIG_DIR/windows-provision.json"
LOCK_DIR="$CACHE_DIR/provision.lock"
VM_NAME="${SEVENOS_WINDOWS_VM:-sevenos-windows}"
DISK_SIZE="${SEVENOS_WINDOWS_DISK_SIZE:-80G}"
DISK_PATH="$DATA_DIR/${VM_NAME}.qcow2"
VIRTIO_URL="${SEVENOS_VIRTIO_WIN_URL:-https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.285-1/virtio-win-0.1.285.iso}"
VIRTIO_SHA256="${SEVENOS_VIRTIO_WIN_SHA256:-}"
VIRTIO_ISO="$DATA_DIR/virtio-win.iso"
VIRTIO_PART="$DATA_DIR/virtio-win.iso.part"
QUICKGET_DIR="$CACHE_DIR/quickget"
DRY_RUN="${SEVENOS_DRY_RUN:-0}"
ASSUME_YES=0
LOCK_HELD=0

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --yes|-y) ASSUME_YES=1; shift ;;
    --disk-size) DISK_SIZE="${2:-80G}"; shift 2 ;;
    --disk) DISK_PATH="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --dry-run) DRY_RUN=1; export SEVENOS_DRY_RUN=1; shift ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf 'OK' || printf 'MISS'
}

file_state() {
  [[ -s "$1" ]] && printf 'OK' || printf 'MISS'
}

partial_state() {
  [[ -s "$VIRTIO_PART" ]] && printf 'PARTIAL' || printf 'MISS'
}

iso_state() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    printf 'MISS'
    return 0
  fi
  if command -v file >/dev/null 2>&1 && file -b "$path" 2>/dev/null | grep -qi 'ISO 9660'; then
    printf 'OK'
    return 0
  fi
  printf 'INVALID'
}

first_valid_iso() {
  local path
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ "$(iso_state "$path")" == "OK" ]] && {
      printf '%s\n' "$path"
      return 0
    }
  done
  return 1
}

find_windows_iso() {
  find "$DATA_DIR" "$QUICKGET_DIR" -maxdepth 2 -type f \( -iname '*windows*.iso' -o -iname '*win11*.iso' -o -iname '*win10*.iso' \) 2>/dev/null | first_valid_iso
}

find_virtio_iso() {
  if [[ "$(iso_state "$VIRTIO_ISO")" == "OK" ]]; then
    printf '%s\n' "$VIRTIO_ISO"
    return 0
  fi
  find "$DATA_DIR" "$QUICKGET_DIR" -maxdepth 3 -type f -iname 'virtio-win*.iso' 2>/dev/null | first_valid_iso
}

find_quickget_conf() {
  find "$QUICKGET_DIR" -maxdepth 1 -type f -name 'windows-*.conf' 2>/dev/null | head -n 1
}

lock_provision() {
  [[ "$LOCK_HELD" == "1" ]] && return 0
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    printf 'Windows provisioning is already running.\n' >&2
    exit 2
  fi
  LOCK_HELD=1
  trap 'rm -rf "$LOCK_DIR"' EXIT
}

write_state() {
  local state="$1"
  local detail="${2:-}"
  local windows_iso virtio_iso quickget_conf
  windows_iso="$(find_windows_iso || true)"
  virtio_iso="$(find_virtio_iso || true)"
  quickget_conf="$(find_quickget_conf || true)"
  python - "$STATE_FILE" "$state" "$detail" "$VM_NAME" "$DATA_DIR" "$CACHE_DIR" "$DISK_PATH" "$DISK_SIZE" "${virtio_iso:-$VIRTIO_ISO}" "$windows_iso" "$quickget_conf" <<'PY'
import json
import sys
from pathlib import Path

path, state, detail, vm_name, data_dir, cache_dir, disk_path, disk_size, virtio_iso, windows_iso, quickget_conf = sys.argv[1:]
payload = {
    "schema": "sevenos.windows-provision.v1",
    "state": state,
    "detail": detail,
    "vm_name": vm_name,
    "storage": {
        "data_dir": data_dir,
        "cache_dir": cache_dir,
        "disk": disk_path,
        "disk_size": disk_size,
        "virtio_iso": virtio_iso,
        "windows_iso": windows_iso or None,
        "quickget_conf": quickget_conf or None,
    },
    "legal": {
        "redistributed_windows_image": False,
        "source_policy": "SevenOS prepares Windows locally from user-authorized official Microsoft media or a helper such as quickget.",
        "activation_policy": "SevenOS does not bypass Windows licensing or activation.",
    },
}
Path(path).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
print(path)
PY
}

status_json() {
  local windows_iso virtio_iso quickget_conf
  windows_iso="$(find_windows_iso || true)"
  virtio_iso="$(find_virtio_iso || true)"
  quickget_conf="$(find_quickget_conf || true)"
  python - "$VM_NAME" "$DATA_DIR" "$CACHE_DIR" "$STATE_FILE" "$DISK_PATH" "$DISK_SIZE" "${virtio_iso:-$VIRTIO_ISO}" "$windows_iso" "$quickget_conf" \
    "$(command_state quickget)" \
    "$(command_state quickemu)" \
    "$(command_state qemu-img)" \
    "$(command_state curl)" \
    "$(command_state zstd)" \
    "$(command_state xz)" \
    "$(file_state "$DISK_PATH")" \
    "$(iso_state "${virtio_iso:-$VIRTIO_ISO}")" <<'PY'
import json
import sys
from pathlib import Path

(
    vm_name, data_dir, cache_dir, state_file, disk_path, disk_size, virtio_iso, windows_iso, quickget_conf,
    quickget, quickemu, qemu_img, curl, zstd, xz, disk_state, virtio_state
) = sys.argv[1:]
state = {}
if Path(state_file).exists():
    try:
        state = json.loads(Path(state_file).read_text(encoding="utf-8"))
    except Exception:
        state = {"state": "corrupt-state"}
payload = {
    "schema": "sevenos.windows-provision.v1",
    "vm_name": vm_name,
    "mode": "official-media-local-build",
    "state": state.get("state", "not-started"),
    "data_dir": data_dir,
    "cache_dir": cache_dir,
    "commands": {
        "quickget": quickget,
        "quickemu": quickemu,
        "qemu_img": qemu_img,
        "curl": curl,
        "zstd": zstd,
        "xz": xz,
    },
    "artifacts": {
        "windows_iso": "OK" if windows_iso else "MISS",
        "windows_iso_path": windows_iso or None,
        "quickget_conf": "OK" if quickget_conf else "MISS",
        "quickget_conf_path": quickget_conf or None,
        "virtio_iso": virtio_state,
        "virtio_iso_path": virtio_iso if virtio_state == "OK" else None,
        "virtio_partial": "OK" if Path(virtio_iso + ".part").exists() and Path(virtio_iso + ".part").stat().st_size > 0 else "MISS",
        "virtio_partial_path": virtio_iso + ".part" if Path(virtio_iso + ".part").exists() and Path(virtio_iso + ".part").stat().st_size > 0 else None,
        "qcow2_disk": disk_state,
        "qcow2_disk_path": disk_path if disk_state == "OK" else None,
        "disk_size": disk_size,
    },
    "legal": {
        "redistributed_windows_image": False,
        "official_source_required": True,
        "activation_bypass": False,
    },
}
if quickget_conf and not windows_iso:
    payload["state"] = "manual-iso-required"
payload["ready_to_create_vm"] = (
    payload["artifacts"]["windows_iso"] == "OK"
    and payload["artifacts"]["virtio_iso"] == "OK"
    and payload["commands"]["qemu_img"] == "OK"
)
payload["recommended_next"] = (
    "seven windows create --iso " + windows_iso + " --virtio-iso " + virtio_iso + " --disk-path " + disk_path
    if payload["ready_to_create_vm"] and virtio_state == "OK"
    else "seven windows virtio --yes"
    if payload["artifacts"]["windows_iso"] == "OK" and virtio_state != "OK"
    else "download Windows 11 ISO manually from Microsoft into " + str(Path(cache_dir) / "quickget" / "windows-11" / "windows-11.iso")
    if quickget_conf and not windows_iso
    else "seven windows provision --yes"
)
print(json.dumps(payload, indent=2))
PY
}

sources_json() {
  python - "$VIRTIO_URL" <<'PY'
import json
import sys
virtio_url = sys.argv[1]
print(json.dumps({
    "schema": "sevenos.windows-sources.v1",
    "policy": "SevenOS never redistributes a prebuilt Windows image.",
    "recommended": [
        {
            "id": "quickget-windows-11",
            "kind": "official-microsoft-helper",
            "command": "quickget windows 11",
            "reason": "Fetches Microsoft media through a maintained VM helper, then SevenOS can build the local VM disk.",
        },
        {
            "id": "user-official-iso",
            "kind": "user-provided-official-iso",
            "command": "seven windows create --iso /path/to/windows.iso --virtio-iso ~/.local/share/sevenos/vm/windows/virtio-win.iso --disk-path ~/.local/share/sevenos/vm/windows/sevenos-windows.qcow2",
            "reason": "Best fallback when Microsoft download flows change or the user already has a legal ISO.",
        },
        {
            "id": "virtio-win",
            "kind": "driver-media",
            "url": virtio_url,
            "command": "seven windows virtio --yes",
            "reason": "Provides storage/network/display drivers for Windows guests on QEMU/KVM.",
        },
    ],
}, indent=2))
PY
}

status_human() {
  local windows_iso virtio_iso quickget_conf
  windows_iso="$(find_windows_iso || true)"
  virtio_iso="$(find_virtio_iso || true)"
  quickget_conf="$(find_quickget_conf || true)"
  printf 'SevenOS Windows Provisioning\n\n'
  printf '  %-18s %s\n' "Mode" "official media -> local qcow2"
  printf '  %-18s %s\n' "quickget" "$(command_state quickget)"
  printf '  %-18s %s\n' "quickemu" "$(command_state quickemu)"
  printf '  %-18s %s\n' "qemu-img" "$(command_state qemu-img)"
  printf '  %-18s %s\n' "curl" "$(command_state curl)"
  printf '  %-18s %s\n' "Windows ISO" "$([[ -n "$windows_iso" ]] && printf OK || printf MISS)"
  printf '  %-18s %s\n' "Quickget conf" "$([[ -n "$quickget_conf" ]] && printf OK || printf MISS)"
  printf '  %-18s %s\n' "VirtIO ISO" "$(iso_state "${virtio_iso:-$VIRTIO_ISO}")"
  if [[ "$(partial_state)" == "PARTIAL" ]]; then
    printf '  %-18s %s (%s)\n' "VirtIO download" "PARTIAL" "$VIRTIO_PART"
  fi
  printf '  %-18s %s\n' "Local qcow2" "$(file_state "$DISK_PATH")"
  printf '\n'
  printf 'Next actions:\n'
  if [[ -n "$quickget_conf" && -z "$windows_iso" ]]; then
    printf '  Download Windows 11 manually from Microsoft and save it as:\n'
    printf '    %s/windows-11/windows-11.iso\n' "$QUICKGET_DIR"
    printf '  Then run:\n'
    printf '    seven windows provision --yes\n'
  elif [[ -n "$windows_iso" && -z "$virtio_iso" ]]; then
    printf '  Windows ISO is ready, but VirtIO driver media is missing or invalid.\n'
    if [[ "$(partial_state)" == "PARTIAL" ]]; then
      printf '  A partial VirtIO download exists and will be resumed automatically.\n'
    fi
    printf '  Run:\n'
    printf '    seven windows virtio --yes\n'
    printf '  Then create the VM with:\n'
    printf '    seven windows create --iso %s --virtio-iso %s --disk-path %s\n' "$windows_iso" "$VIRTIO_ISO" "$DISK_PATH"
  elif [[ -n "$windows_iso" && -n "$virtio_iso" && "$(file_state "$DISK_PATH")" == "OK" ]]; then
    printf '  Provisioning is prepared. Create/register the Windows VM with:\n'
    printf '    seven windows create --iso %s --virtio-iso %s --disk-path %s\n' "$windows_iso" "$virtio_iso" "$DISK_PATH"
  else
    printf '  seven windows sources          Show legal source strategy\n'
    printf '  seven windows provision --yes  Prepare official media/cache plan\n'
    printf '  seven windows virtio --yes     Download VirtIO driver media\n'
    printf '  seven windows autounattend     Generate an unattended template\n'
  fi
}

fetch_virtio() {
  if [[ "$ASSUME_YES" != "1" ]]; then
    printf 'This downloads VirtIO driver media for QEMU/KVM Windows guests.\n'
    printf 'Run again with --yes to continue:\n'
    printf '  seven windows virtio --yes\n'
    return 0
  fi
  lock_provision
  if [[ "$(iso_state "$VIRTIO_ISO")" == "OK" ]]; then
    printf 'VirtIO ISO already exists: %s\n' "$VIRTIO_ISO"
    write_state "virtio-ready" "VirtIO ISO already present" >/dev/null
    return 0
  fi
  if [[ "$(iso_state "$VIRTIO_ISO")" == "INVALID" ]]; then
    printf 'Removing invalid VirtIO media cache: %s\n' "$VIRTIO_ISO"
    rm -f "$VIRTIO_ISO"
  fi
  if [[ "$(command_state curl)" != "OK" ]]; then
    printf 'curl is required to download VirtIO media.\n' >&2
    exit 1
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'curl --fail --retry 5 --retry-delay 2 -C - -L -o %q %q\n' "$VIRTIO_PART" "$VIRTIO_URL"
    printf 'mv %q %q\n' "$VIRTIO_PART" "$VIRTIO_ISO"
    return 0
  fi
  printf 'Downloading VirtIO ISO. This is a large driver image and can take several minutes.\n'
  if [[ -s "$VIRTIO_PART" ]]; then
    printf 'Resuming partial download: %s\n' "$VIRTIO_PART"
  fi
  if ! curl --fail --retry 5 --retry-delay 2 -C - -L --progress-bar -o "$VIRTIO_PART" "$VIRTIO_URL"; then
    printf '\nVirtIO download was interrupted. Resume with:\n  seven windows virtio --yes\n' >&2
    exit 143
  fi
  mv -f "$VIRTIO_PART" "$VIRTIO_ISO"
  if [[ "$(iso_state "$VIRTIO_ISO")" != "OK" ]]; then
    rm -f "$VIRTIO_ISO"
    printf 'Downloaded VirtIO media is not a valid ISO. Please retry later or provide a local VirtIO ISO.\n' >&2
    exit 1
  fi
  if [[ -n "$VIRTIO_SHA256" ]]; then
    printf '%s  %s\n' "$VIRTIO_SHA256" "$VIRTIO_ISO" | sha256sum -c -
  else
    printf 'Warning: SEVENOS_VIRTIO_WIN_SHA256 is not set; integrity is transport-verified only.\n' >&2
  fi
  write_state "virtio-ready" "VirtIO driver ISO available" >/dev/null
  printf 'VirtIO ISO ready: %s\n' "$VIRTIO_ISO"
}

create_disk() {
  if [[ "$(file_state "$DISK_PATH")" == "OK" ]]; then
    printf 'Windows qcow2 disk already exists: %s\n' "$DISK_PATH"
    return 0
  fi
  if [[ "$(command_state qemu-img)" != "OK" ]]; then
    printf 'qemu-img is required. Run: seven profile install windows\n' >&2
    exit 1
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'qemu-img create -f qcow2 %q %q\n' "$DISK_PATH" "$DISK_SIZE"
    return 0
  fi
  qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
  write_state "disk-ready" "Local qcow2 disk created" >/dev/null
  printf 'Windows qcow2 disk ready: %s\n' "$DISK_PATH"
}

run_quickget() {
  if [[ "$(command_state quickget)" != "OK" ]]; then
    printf 'quickget is not installed.\n'
    printf 'Install quickemu/quickget from your chosen repo/AUR, or provide an official Windows ISO manually.\n'
    printf 'Manual path:\n'
    printf '  seven windows create --iso /path/to/windows.iso --virtio-iso %s\n' "$VIRTIO_ISO"
    return 0
  fi
  if [[ "$ASSUME_YES" != "1" ]]; then
    printf 'SevenOS can ask quickget to fetch official Windows media.\n'
    printf 'Run with confirmation:\n'
    printf '  seven windows provision --yes\n'
    return 0
  fi
  lock_provision
  mkdir -p "$QUICKGET_DIR"
  if [[ -n "$(find_windows_iso || true)" ]]; then
    printf 'Windows ISO already available: %s\n' "$(find_windows_iso)"
    write_state "windows-media-ready" "Windows ISO already available" >/dev/null
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '(cd %q && quickget windows 11)\n' "$QUICKGET_DIR"
    return 0
  fi
  printf 'Fetching official Windows media through quickget...\n'
  (cd "$QUICKGET_DIR" && quickget windows 11)
  if [[ -n "$(find_windows_iso || true)" ]]; then
    write_state "windows-media-ready" "Windows media fetched through quickget" >/dev/null
    printf 'Windows media state updated.\n'
  else
    write_state "manual-iso-required" "Microsoft blocked automated ISO download; place the ISO at $QUICKGET_DIR/windows-11/windows-11.iso" >/dev/null
    printf 'Microsoft did not provide the ISO automatically. Download it manually and save it here:\n'
    printf '  %s/windows-11/windows-11.iso\n' "$QUICKGET_DIR"
  fi
}

write_autounattend_template() {
  local path="$DATA_DIR/autounattend.xml.template"
  cat >"$path" <<'EOF'
<!--
SevenOS Windows Bridge unattended template.

This file is intentionally a template. SevenOS does not inject a Windows
product key and does not bypass activation. Review and complete locale,
username, disk and license choices before using it in a VM install.
-->
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
  </settings>
</unattend>
EOF
  write_state "autounattend-template-ready" "Unattended template generated" >/dev/null
  printf 'Autounattend template ready:\n  %s\n' "$path"
}

prepare_action() {
  local windows_iso virtio_iso
  write_state "prepared" "Provisioning directories and source policy initialized" >/dev/null
  create_disk
  run_quickget
  windows_iso="$(find_windows_iso || true)"
  virtio_iso="$(find_virtio_iso || true)"
  if [[ -n "$windows_iso" && -z "$virtio_iso" ]]; then
    printf '\nWindows ISO is ready. Preparing VirtIO driver media for KVM/QEMU...\n'
    fetch_virtio
  fi
  printf '\nProvisioning status:\n'
  status_human
}

case "$ACTION" in
  status)
    if [[ "${JSON:-0}" == "1" || "${1:-}" == "--json" ]]; then
      status_json
    else
      status_human
    fi
    ;;
  sources)
    if [[ "${JSON:-0}" == "1" || "${1:-}" == "--json" ]]; then
      sources_json
    else
      printf 'SevenOS Windows source policy\n\n'
      printf '  - SevenOS does not redistribute Windows qcow2 images.\n'
      printf '  - SevenOS builds a local qcow2 disk from official/user-authorized media.\n'
      printf '  - Recommended helper: quickget windows 11, when available.\n'
      printf '  - Manual fallback: provide a legal Windows ISO.\n'
      printf '\nRun: seven windows sources --json\n'
    fi
    ;;
  provision|prepare)
    prepare_action
    ;;
  virtio)
    fetch_virtio
    ;;
  disk)
    create_disk
    ;;
  quickget)
    run_quickget
    ;;
  autounattend)
    write_autounattend_template
    ;;
  --json)
    status_json
    ;;
  -h|--help|help)
    status_human
    ;;
  *)
    printf 'windows-provisioner: unknown action: %s\n' "$ACTION" >&2
    status_human >&2
    exit 1
    ;;
esac
