#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="${1:-status}"
JSON=0

if [[ "${2:-}" == "--json" || "$ACTION" == "json" ]]; then
  JSON=1
fi

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

file_state() {
  [[ -s "$ROOT_DIR/$1" ]] && printf OK || printf MISS
}

bool_json() {
  [[ "$1" == 1 ]] && printf true || printf false
}

latest_iso() {
  find "$ROOT_DIR/out/iso" -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | awk 'NR==1 {sub(/^[^ ]+ /,""); print}'
}

collect_json() {
  local iso iso_state iso_size boot_entries wifi_state bluetooth_state disk_state suspend_state gpu_state calamares_state repo_state
  iso="$(latest_iso || true)"
  iso_state="MISS"
  iso_size=0
  if [[ -n "$iso" && -s "$iso" ]]; then
    iso_state="OK"
    iso_size="$(stat -c '%s' "$iso" 2>/dev/null || printf 0)"
  fi

  boot_entries="MISS"
  if [[ -s "$ROOT_DIR/archiso/profile/efiboot/loader/entries/01-sevenos-live.conf" \
      && -s "$ROOT_DIR/archiso/profile/efiboot/loader/entries/03-sevenos-live-safe.conf" \
      && -s "$ROOT_DIR/archiso/profile/syslinux/archiso_sys-linux.cfg" ]]; then
    boot_entries="OK"
  fi

  wifi_state="$(command_state nmcli)"
  [[ "$wifi_state" == OK || "$(command_state nmtui)" == OK ]] && wifi_state=OK
  bluetooth_state="$(command_state bluetoothctl)"
  disk_state="$(command_state lsblk)"
  [[ "$disk_state" == OK && "$(command_state udisksctl)" == OK ]] && disk_state=OK
  suspend_state="$(command_state systemctl)"
  gpu_state="$(command_state lspci)"
  [[ "$gpu_state" == OK || "$(command_state inxi)" == OK ]] && gpu_state=OK
  calamares_state="MISS"
  if [[ -s "$ROOT_DIR/archiso/localrepo/x86_64/sevenos-local.db.tar.gz" ]] \
    && compgen -G "$ROOT_DIR/archiso/localrepo/x86_64/calamares-*.pkg.tar.zst" >/dev/null 2>&1; then
    calamares_state="OK"
  fi
  repo_state="$(file_state archiso/localrepo/x86_64/sevenos-local.db.tar.gz)"

  ISO_PATH="$iso" ISO_STATE="$iso_state" ISO_SIZE="$iso_size" BOOT_ENTRIES="$boot_entries" \
  WIFI_STATE="$wifi_state" BLUETOOTH_STATE="$bluetooth_state" DISK_STATE="$disk_state" \
  SUSPEND_STATE="$suspend_state" GPU_STATE="$gpu_state" CALAMARES_STATE="$calamares_state" \
  REPO_STATE="$repo_state" ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json, os, platform, socket, subprocess, time

def env(name, default=""):
    return os.environ.get(name, default)

def probe(cmd):
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True, timeout=3)
        return out.strip()
    except Exception:
        return ""

checks = [
    {"key": "iso-artifact", "state": env("ISO_STATE"), "title": "Generated ISO artifact", "detail": env("ISO_PATH") or "No ISO found in out/iso."},
    {"key": "boot-entries", "state": env("BOOT_ENTRIES"), "title": "Branded boot entries", "detail": "UEFI, Safe Graphics and BIOS entries are tracked."},
    {"key": "calamares-runtime", "state": env("CALAMARES_STATE"), "title": "Calamares local ISO runtime", "detail": "Local package repository is ready." if env("CALAMARES_STATE") == "OK" else "Local Calamares package repository is incomplete."},
    {"key": "local-repo", "state": env("REPO_STATE"), "title": "SevenOS local package repository", "detail": "Repository database exists."},
    {"key": "wifi-tooling", "state": env("WIFI_STATE"), "title": "Wi-Fi tooling", "detail": "nmcli/nmtui route for live installation."},
    {"key": "bluetooth-tooling", "state": env("BLUETOOTH_STATE"), "title": "Bluetooth tooling", "detail": "bluetoothctl route for validation."},
    {"key": "disk-tooling", "state": env("DISK_STATE"), "title": "External disk tooling", "detail": "lsblk/udisksctl route for removable disks."},
    {"key": "suspend-tooling", "state": env("SUSPEND_STATE"), "title": "Suspend tooling", "detail": "systemctl route for suspend/resume validation."},
    {"key": "gpu-tooling", "state": env("GPU_STATE"), "title": "GPU detection tooling", "detail": "lspci/inxi route for Intel, AMD and NVIDIA evidence."},
]
ok = sum(1 for item in checks if item["state"] == "OK")
score = round(ok / max(len(checks), 1) * 100)
payload = {
    "schema": "sevenos.release-validation.v1",
    "state": "evidence-ready" if score >= 80 else "needs-evidence",
    "score": score,
    "generated_at": int(time.time()),
    "machine": {
        "hostname": socket.gethostname(),
        "kernel": platform.release(),
        "arch": platform.machine(),
        "cpu": probe(["bash", "-lc", "lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -1"]),
        "gpu": probe(["bash", "-lc", "lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -3"]),
        "memory": probe(["bash", "-lc", "free -h 2>/dev/null | awk '/^Mem:/ {print $2}'"]),
        "disks": probe(["bash", "-lc", "lsblk -dn -o NAME,TYPE,SIZE,TRAN 2>/dev/null | head -10"]),
    },
    "iso": {
        "path": env("ISO_PATH"),
        "size_bytes": int(env("ISO_SIZE", "0") or 0),
    },
    "checks": checks,
    "manual_matrix": [
        {"target": "Boot USB normal mode", "status": "manual-required"},
        {"target": "Boot USB Safe Graphics", "status": "manual-required"},
        {"target": "Calamares full install", "status": "manual-required"},
        {"target": "First boot after install", "status": "manual-required"},
        {"target": "Wi-Fi connection during live install", "status": "manual-required"},
        {"target": "Bluetooth pairing", "status": "manual-required"},
        {"target": "Suspend/resume", "status": "manual-required"},
        {"target": "External disk mount/unmount", "status": "manual-required"},
        {"target": "Intel/AMD/NVIDIA graphics coverage", "status": "manual-required"},
    ],
    "commands": {
        "record": "seven production validate",
        "json": "seven production validate --json",
        "iso": "./install.sh iso",
    },
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
}

case "$ACTION" in
  status|json)
    payload="$(collect_json)"
    if [[ "$JSON" == 1 || "$ACTION" == "json" ]]; then
      printf '%s\n' "$payload"
    else
      printf 'SevenOS Release Validation\n'
      printf '==========================\n'
      printf 'State: %s\n' "$(python -c 'import json,sys; print(json.load(sys.stdin).get("state","unknown"))' <<<"$payload")"
      printf 'Score: %s%%\n' "$(python -c 'import json,sys; print(json.load(sys.stdin).get("score",0))' <<<"$payload")"
      python -c 'import json,sys; data=json.load(sys.stdin); [print(f"- {i.get(\"state\")}: {i.get(\"title\")} — {i.get(\"detail\")}") for i in data.get("checks", [])]' <<<"$payload"
    fi
    ;;
  record)
    mkdir -p "$ROOT_DIR/out/release-validation"
    payload="$(collect_json)"
    stamp="$(date +%Y%m%d-%H%M%S)"
    path="$ROOT_DIR/out/release-validation/validation-$stamp.json"
    printf '%s\n' "$payload" >"$path"
    ln -sfn "$(basename "$path")" "$ROOT_DIR/out/release-validation/latest.json"
    if [[ "$JSON" == 1 ]]; then
      printf '%s\n' "$payload"
    else
      printf 'SevenOS validation evidence recorded: %s\n' "$path"
    fi
    ;;
  plan)
    cat <<'EOF'
SevenOS release validation plan
===============================
1. Generate the ISO: ./install.sh iso
2. Flash a USB drive with SevenOS USB Writer or KDE ISO Image Writer.
3. Boot normal mode and Safe Graphics.
4. Connect Wi-Fi from the live installer portal.
5. Run Calamares full install.
6. First boot, run seven first-run verify and seven update check.
7. Test Bluetooth, suspend/resume and an external disk.
8. Record local evidence: seven production validate.
EOF
    ;;
  *)
    echo "Usage: seven production validate [--json] | scripts/release-validation.sh [status|json|record|plan]" >&2
    exit 2
    ;;
esac
