#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

AREA="${1:-all}"
JSON_OUTPUT=0
if [[ "$AREA" == "--json" || "$AREA" == "json" ]]; then
  AREA="all"
  JSON_OUTPUT=1
fi
shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help)
      cat <<'EOF'
SevenOS Doctor

Usage:
  seven doctor check [all|system|desktop|installer|ecosystem|windows] [--json]
  ./scripts/doctor.sh [all|system|desktop|installer|ecosystem|windows] [--json]

Seven Doctor is a human-facing quality gate. It reports what is ready, what is
degraded, and which command should fix or guide each issue.
EOF
      exit 0
      ;;
    *) log_error "Unknown doctor option: $arg"; exit 1 ;;
  esac
done

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

package_state() {
  pacman -Q "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

service_state() {
  local unit="$1"
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    printf OK
  elif systemctl is-enabled --quiet "$unit" 2>/dev/null; then
    printf PART
  else
    printf MISS
  fi
}

user_service_state() {
  local unit="$1"
  if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
    printf OK
  elif systemctl --user is-enabled --quiet "$unit" 2>/dev/null; then
    printf PART
  else
    printf MISS
  fi
}

ufw_state_detail() {
  local detail service
  if ! command -v ufw >/dev/null 2>&1; then
    printf 'MISS\tUFW command is missing'
    return 0
  fi
  if [[ -s "${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/security/ufw-degraded" ]]; then
    printf 'PART\tUFW degraded marker present'
    return 0
  fi
  service="$(service_state ufw.service)"
  detail="$(sudo -n ufw status 2>/dev/null | head -n 1 || true)"
  if [[ "$detail" == *"active"* ]]; then
    printf 'OK\t%s' "$detail"
  elif [[ "$service" == "OK" ]]; then
    printf 'OK\tufw.service active; detailed status requires sudo'
  elif [[ -n "$detail" ]]; then
    printf 'PART\t%s' "$detail"
  else
    printf 'PART\tufw.service %s; detailed status requires sudo' "$service"
  fi
}

failed_units_json() {
  if ! command -v systemctl >/dev/null 2>&1; then
    printf '[]'
    return 0
  fi
  systemctl --failed --plain --no-legend 2>/dev/null |
    awk '{print $1}' |
    python -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))'
}

json_payload() {
  local arch_state pacman_state sudo_state memory_kb memory_gb virt_state uefi_state
  local swaync_state wlogout_state hypridle_state hyprlock_state hyprpaper_state waybar_state
  local waybar_unit notifications_unit idle_unit wallpaper_unit calamares_state archinstall_state
  local installer_release windows_json ecosystem_json failed_json ufw_state ufw_detail

  arch_state="$([[ -f /etc/arch-release ]] && printf OK || printf MISS)"
  pacman_state="$(command_state pacman)"
  sudo_state="$(command_state sudo)"
  memory_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  memory_gb="$((memory_kb / 1024 / 1024))"
  virt_state="$(grep -Eiq '(vmx|svm)' /proc/cpuinfo && printf OK || printf PART)"
  uefi_state="$([[ -d /sys/firmware/efi ]] && printf OK || printf PART)"

  swaync_state="$(command_state swaync)"
  wlogout_state="$(command_state wlogout)"
  hypridle_state="$(command_state hypridle)"
  hyprlock_state="$(command_state hyprlock)"
  hyprpaper_state="$(command_state hyprpaper)"
  waybar_state="$(command_state waybar)"
  waybar_unit="$(user_service_state sevenos-waybar.service)"
  notifications_unit="$(user_service_state sevenos-notifications.service)"
  idle_unit="$(user_service_state sevenos-idle.service)"
  wallpaper_unit="$(user_service_state sevenos-wallpaper.service)"

  calamares_state="$(command_state calamares)"
  archinstall_state="$(command_state archinstall)"
  installer_release="$("$ROOT_DIR/scripts/installer-stack.sh" release --json 2>/dev/null || printf '{}')"
  windows_json="$("$ROOT_DIR/bin/seven-windows-assistant" status --json 2>/dev/null || printf '{}')"
  ecosystem_json="$("$ROOT_DIR/scripts/ecosystem.sh" json 2>/dev/null || printf '{}')"
  failed_json="$(failed_units_json)"
  IFS=$'\t' read -r ufw_state ufw_detail < <(ufw_state_detail) || true

  ARCH_STATE="$arch_state" PACMAN_STATE="$pacman_state" SUDO_STATE="$sudo_state" \
  MEMORY_GB="$memory_gb" VIRT_STATE="$virt_state" UEFI_STATE="$uefi_state" \
  SWAYNC_STATE="$swaync_state" WLOGOUT_STATE="$wlogout_state" HYPRIDLE_STATE="$hypridle_state" \
  HYPRLOCK_STATE="$hyprlock_state" HYPRPAPER_STATE="$hyprpaper_state" WAYBAR_STATE="$waybar_state" \
  WAYBAR_UNIT="$waybar_unit" NOTIFICATIONS_UNIT="$notifications_unit" IDLE_UNIT="$idle_unit" WALLPAPER_UNIT="$wallpaper_unit" \
  CALAMARES_STATE="$calamares_state" ARCHINSTALL_STATE="$archinstall_state" INSTALLER_RELEASE="$installer_release" \
  WINDOWS_JSON="$windows_json" ECOSYSTEM_JSON="$ecosystem_json" FAILED_JSON="$failed_json" UFW_STATE="$ufw_state" UFW_DETAIL="$ufw_detail" \
  python - <<'PY'
import json
import os

def env(name, default=""):
    return os.environ.get(name, default)

def load(name):
    try:
        return json.loads(env(name, "{}"))
    except json.JSONDecodeError:
        return {}

issues = []
checks = []

def check(area, key, state, title, detail, command, severity="medium"):
    item = {
        "area": area,
        "key": key,
        "state": state,
        "title": title,
        "detail": detail,
        "command": command,
        "severity": severity,
    }
    checks.append(item)
    if state not in ("OK", "READY", "RUN"):
        issues.append(item)

check("system", "arch", env("ARCH_STATE"), "Arch base", "SevenOS expects an Arch-based host.", "cat /etc/arch-release", "critical")
check("system", "pacman", env("PACMAN_STATE"), "Pacman", "Package manager availability.", "command -v pacman", "critical")
check("system", "sudo", env("SUDO_STATE"), "Sudo", "Admin workflow availability.", "command -v sudo", "high")
mem_state = "OK" if int(env("MEMORY_GB", "0")) >= 16 else "PART" if int(env("MEMORY_GB", "0")) >= 8 else "MISS"
check("system", "memory", mem_state, "Memory", f"{env('MEMORY_GB')} GB RAM detected.", "free -h", "medium")
check("system", "virtualization", env("VIRT_STATE"), "CPU virtualization", "Required for Windows VM mode.", "seven vm check", "medium")
check("system", "uefi", env("UEFI_STATE"), "UEFI boot", "Recommended for public install consistency.", "ls /sys/firmware/efi", "low")
check("security", "ufw", env("UFW_STATE"), "Firewall status", env("UFW_DETAIL"), "seven shield enable", "high")

failed = json.loads(env("FAILED_JSON", "[]"))
check("system", "failed-units", "OK" if not failed else "PART", "Failed systemd units", ", ".join(failed) if failed else "none", "seven ai diagnose system", "high" if failed else "low")

for key, state, title, command in [
    ("swaync", env("SWAYNC_STATE"), "Modern notifications", "seven identity visuals status"),
    ("wlogout", env("WLOGOUT_STATE"), "Premium power menu", "seven identity visuals install"),
    ("hypridle", env("HYPRIDLE_STATE"), "Idle policy", "seven identity visuals status"),
    ("hyprlock", env("HYPRLOCK_STATE"), "Lock screen", "seven identity visuals status"),
    ("hyprpaper", env("HYPRPAPER_STATE"), "Wallpaper engine", "seven wallpaper status"),
    ("waybar", env("WAYBAR_STATE"), "Waybar runtime", "seven-waybar restart"),
]:
    check("desktop", key, state, title, f"{key} command availability.", command, "medium")

for key, state, title in [
    ("sevenos-waybar", env("WAYBAR_UNIT"), "Waybar service"),
    ("sevenos-notifications", env("NOTIFICATIONS_UNIT"), "Notification service"),
    ("sevenos-idle", env("IDLE_UNIT"), "Idle service"),
    ("sevenos-wallpaper", env("WALLPAPER_UNIT"), "Wallpaper service"),
]:
    check("desktop", key, state, title, "SevenOS user service state.", "seven session restart", "medium")

installer = load("INSTALLER_RELEASE")
check("installer", "archinstall", env("ARCHINSTALL_STATE"), "Guided TUI installer", "Archinstall backend.", "seven installer install", "high")
cal_state = env("CALAMARES_STATE")
check("installer", "calamares", cal_state if cal_state == "OK" else "PART", "Graphical installer runtime", "SevenOS profile is present; runtime must be available on the ISO build host.", "seven installer graphical", "medium")
release_state = installer.get("state", "unknown")
check("installer", "release", "OK" if release_state in ("graphical-ready", "tui-release-ready") else "PART", "Installer release contract", release_state, "seven installer release", "high")

windows = load("WINDOWS_JSON")
check("windows", "vm-ready", "OK" if windows.get("vm_ready") else "PART", "Windows VM stack", "KVM/libvirt readiness.", "seven windows guide", "medium")
check("windows", "vm-created", "OK" if windows.get("windows_vm") == "OK" else "PART", "Windows VM instance", "No VM is required to be ready, but daily use needs one guided VM.", "seven windows create --iso /path/windows.iso --virtio-iso /path/virtio-win.iso", "medium")

ecosystem = load("ECOSYSTEM_JSON")
modules = ecosystem.get("modules", [])
preview_count = sum(1 for item in modules if item.get("level") in ("product-preview", "guided-preview"))
check("ecosystem", "preview-count", "OK" if preview_count <= 6 else "PART", "Preview surface count", f"{preview_count} modules still preview/guided-preview.", "seven ecosystem maturity", "medium")

severity_rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
issues.sort(key=lambda item: (severity_rank.get(item["severity"], 9), item["area"], item["key"]))
decision = "ready" if not issues else "ready-with-actions" if not any(item["severity"] == "critical" for item in issues) else "blocked"
print(json.dumps({
    "schema": "sevenos.doctor.v1",
    "decision": decision,
    "area": os.environ.get("SEVENOS_DOCTOR_AREA", "all"),
    "summary": {
        "checks": len(checks),
        "issues": len(issues),
        "critical": sum(1 for item in issues if item["severity"] == "critical"),
        "high": sum(1 for item in issues if item["severity"] == "high"),
        "medium": sum(1 for item in issues if item["severity"] == "medium"),
    },
    "checks": checks,
    "issues": issues,
}, indent=2))
PY
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  SEVENOS_DOCTOR_AREA="$AREA" json_payload
  exit 0
fi

payload="$(SEVENOS_DOCTOR_AREA="$AREA" json_payload)"
DOCTOR_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["DOCTOR_JSON"])
area = data.get("area", "all")
issues = [item for item in data.get("issues", []) if area == "all" or item.get("area") == area]
checks = [item for item in data.get("checks", []) if area == "all" or item.get("area") == area]

print("SevenOS Doctor")
print("==============")
print(f"Decision: {data.get('decision')}")
print(f"Area:     {area}")
print(f"Checks:   {len(checks)}")
print(f"Issues:   {len(issues)}")
print()

if checks:
    print("Signals:")
    for item in checks:
        state = item.get("state", "MISS")
        marker = "OK" if state in ("OK", "READY", "RUN") else "WARN" if state == "PART" else "MISS"
        print(f"  {marker:<4} {item.get('title'):<28} {item.get('detail')}")

if issues:
    print()
    print("Recommended actions:")
    for item in issues[:10]:
        print(f"  - {item.get('title')}: {item.get('command')}")
        print(f"    {item.get('detail')}")
else:
    print()
    print("No hard issues detected.")
PY

log_success "Doctor checks completed."
