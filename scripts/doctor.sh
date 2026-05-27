#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

AREA="${1:-all}"
JSON_OUTPUT=0
RELEASE_OUTPUT=0
if [[ "$AREA" == "release" || "$AREA" == "release-freeze" ]]; then
  AREA="all"
  RELEASE_OUTPUT=1
fi
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
  seven doctor check [all|system|desktop|installer|ecosystem|atlas] [--json]
  seven doctor release [--json]
  ./scripts/doctor.sh [all|system|desktop|installer|ecosystem|atlas|release] [--json]

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

glaze_state() {
  if pacman -Q glaze >/dev/null 2>&1; then
    printf OK
  elif [[ -f "$HOME/.local/lib/sevenos/glaze/include/glaze/glaze.hpp" &&
          -f "$HOME/.local/lib/sevenos/glaze/lib/pkgconfig/glaze.pc" ]]; then
    printf OK
  else
    printf MISS
  fi
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
  local swaync_state wlogout_state hypridle_state hyprlock_state hyprpaper_state hyprpicker_state hyprsunset_state matugen_state wallust_state glaze_state hyprsysteminfo_state waybar_state
  local waybar_unit notifications_unit idle_unit wallpaper_unit calamares_state archinstall_state system_repair_state
  local installer_release atlas_json ecosystem_json failed_json ufw_state ufw_detail profile_health_json profile_migration_json bridge_json

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
  hyprpicker_state="$(command_state hyprpicker)"
  hyprsunset_state="$(command_state hyprsunset)"
  matugen_state="$(command_state matugen)"
  wallust_state="$(command_state wallust)"
  glaze_state="$(glaze_state)"
  hyprsysteminfo_state="$(command_state hyprsysteminfo)"
  waybar_state="$(command_state waybar)"
  waybar_unit="$(user_service_state sevenos-waybar.service)"
  notifications_unit="$(user_service_state sevenos-notifications.service)"
  idle_unit="$(user_service_state sevenos-idle.service)"
  wallpaper_unit="$(user_service_state sevenos-wallpaper.service)"

  calamares_state="$(command_state calamares)"
  system_repair_state="$([[ -x "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/system-repair-required.sh" ]] && printf PENDING || printf OK)"
  archinstall_state="$(command_state archinstall)"
  installer_release="$("$ROOT_DIR/scripts/installer-stack.sh" release --json 2>/dev/null || printf '{}')"
  atlas_json="$("$ROOT_DIR/bin/seven" atlas status --json 2>/dev/null || printf '{}')"
  ecosystem_json="$("$ROOT_DIR/scripts/ecosystem.sh" json 2>/dev/null || printf '{}')"
  profile_health_json="$("$ROOT_DIR/profiles/profile-manager.sh" health --json 2>/dev/null || printf '{}')"
  profile_migration_json="$("$ROOT_DIR/profiles/profile-manager.sh" migrate-aliases --json 2>/dev/null || printf '{}')"
  bridge_json="$("$ROOT_DIR/scripts/mini-os-relay.sh" doctor --json 2>/dev/null || printf '{}')"
  failed_json="$(failed_units_json)"
  IFS=$'\t' read -r ufw_state ufw_detail < <(ufw_state_detail) || true

  ARCH_STATE="$arch_state" PACMAN_STATE="$pacman_state" SUDO_STATE="$sudo_state" \
  MEMORY_GB="$memory_gb" VIRT_STATE="$virt_state" UEFI_STATE="$uefi_state" \
  SWAYNC_STATE="$swaync_state" WLOGOUT_STATE="$wlogout_state" HYPRIDLE_STATE="$hypridle_state" \
  HYPRLOCK_STATE="$hyprlock_state" HYPRPAPER_STATE="$hyprpaper_state" HYPRPICKER_STATE="$hyprpicker_state" \
  HYPRSUNSET_STATE="$hyprsunset_state" MATUGEN_STATE="$matugen_state" WALLUST_STATE="$wallust_state" \
  GLAZE_STATE="$glaze_state" HYPRSYSTEMINFO_STATE="$hyprsysteminfo_state" WAYBAR_STATE="$waybar_state" \
  WAYBAR_UNIT="$waybar_unit" NOTIFICATIONS_UNIT="$notifications_unit" IDLE_UNIT="$idle_unit" WALLPAPER_UNIT="$wallpaper_unit" \
  CALAMARES_STATE="$calamares_state" ARCHINSTALL_STATE="$archinstall_state" INSTALLER_RELEASE="$installer_release" \
  ATLAS_JSON="$atlas_json" ECOSYSTEM_JSON="$ecosystem_json" PROFILE_HEALTH_JSON="$profile_health_json" PROFILE_MIGRATION_JSON="$profile_migration_json" BRIDGE_JSON="$bridge_json" FAILED_JSON="$failed_json" UFW_STATE="$ufw_state" UFW_DETAIL="$ufw_detail" SYSTEM_REPAIR_STATE="$system_repair_state" \
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
check("system", "virtualization", env("VIRT_STATE"), "CPU virtualization", "Optional for advanced VM workflows; not required by SevenOS mini OS identities.", "seven vm check", "low")
check("system", "uefi", env("UEFI_STATE"), "UEFI boot", "Recommended for public install consistency.", "ls /sys/firmware/efi", "low")
check("security", "ufw", env("UFW_STATE"), "Firewall status", env("UFW_DETAIL"), "seven shield enable", "high")

failed = json.loads(env("FAILED_JSON", "[]"))
repair_pending = env("SYSTEM_REPAIR_STATE") == "PENDING"
failed_detail = ", ".join(failed) if failed else "none"
if failed and repair_pending:
    failed_detail += "; root repair plan ready at ~/.config/sevenos/system-repair-required.sh"
check("system", "failed-units", "OK" if not failed else "PART", "Failed systemd units", failed_detail, "seven repair system --apply", "high" if failed else "low")

for key, state, title, command in [
    ("swaync", env("SWAYNC_STATE"), "Modern notifications", "seven identity visuals status"),
    ("wlogout", env("WLOGOUT_STATE"), "Premium power menu", "seven identity visuals install"),
    ("hypridle", env("HYPRIDLE_STATE"), "Idle policy", "seven identity visuals status"),
    ("hyprlock", env("HYPRLOCK_STATE"), "Lock screen", "seven identity visuals status"),
    ("hyprpaper", env("HYPRPAPER_STATE"), "Wallpaper engine", "seven wallpaper status"),
    ("hyprpicker", env("HYPRPICKER_STATE"), "Hyprland color picker", "seven hypr install --yes"),
    ("hyprsunset", env("HYPRSUNSET_STATE"), "Blue-light filter", "seven hypr install --yes"),
    ("matugen", env("MATUGEN_STATE"), "Wallpaper dynamic palette", "seven hypr install --yes"),
    ("wallust", env("WALLUST_STATE"), "Wallpaper palette cache", "seven hypr install --yes"),
    ("glaze", env("GLAZE_STATE"), "Hypr C++ UI dependency", "seven hypr install --yes"),
    ("hyprsysteminfo", env("HYPRSYSTEMINFO_STATE"), "Hyprland system dashboard", "seven hypr install --yes"),
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
release_state = installer.get("state", "unknown")
cal_ready_state = "OK" if cal_state == "OK" or release_state in ("graphical-ready", "tui-release-ready") else "PART"
cal_detail = "Calamares runtime available." if cal_state == "OK" else f"Calamares runtime absent on this host; SevenOS installer route is {release_state}."
check("installer", "calamares", cal_ready_state, "Graphical installer route", cal_detail, "seven installer graphical", "medium")
check("installer", "release", "OK" if release_state in ("graphical-ready", "tui-release-ready") else "PART", "Installer release contract", release_state, "seven installer release", "high")

atlas = load("ATLAS_JSON")
missing_atlas = atlas.get("missing_required") or []
check("atlas", "requirements", "OK" if not missing_atlas else "PART", "Atlas Explorer requirements", f"{len(missing_atlas)} required package(s) missing.", "seven atlas install --yes", "medium")

ecosystem = load("ECOSYSTEM_JSON")
modules = ecosystem.get("modules", [])
preview_count = sum(1 for item in modules if item.get("level") in ("product-preview", "guided-preview"))
check("ecosystem", "preview-count", "OK" if preview_count <= 6 else "PART", "Preview surface count", f"{preview_count} modules still preview/guided-preview.", "seven ecosystem maturity", "medium")

profile_health = load("PROFILE_HEALTH_JSON")
profile_summary = profile_health.get("summary", {})
profile_total = int(profile_summary.get("total", 0) or 0)
alias_pending = int(profile_summary.get("alias_migration_pending", 0) or 0)
check("profiles", "mini-os-count", "OK" if profile_total == 7 else "PART", "Seven mini OS model", f"{profile_total}/7 active mini OS profiles exposed.", "seven profile status --json", "high")
check("profiles", "alias-migration", "OK" if alias_pending == 0 else "PART", "Retired profile aliases", f"{alias_pending} stale profile alias reference(s).", "seven profile migrate-aliases --apply", "medium")
bridge = load("BRIDGE_JSON")
bridge_score = int(bridge.get("score", 0) or 0)
bridge_checks = bridge.get("checks", {}) if isinstance(bridge.get("checks"), dict) else {}
check("profiles", "mini-os-bridge", "OK" if bridge.get("state") == "ready" and bridge_score >= 95 else "PART", "Mini OS bridge and session isolation", f"{bridge_score}% bridge readiness; {bridge_checks.get('ready_profiles', 0)}/7 mini OS ready; {bridge_checks.get('relations', 0)} relation(s).", "seven bridge doctor", "high")

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

release_payload() {
  local doctor_json git_dirty design_state identity_state smoke_state surfaces_state quality_state ux_state installer_json atlas_json profile_json profile_health_json profile_migration_json bridge_json status_json
  doctor_json="$(SEVENOS_DOCTOR_AREA=all json_payload)"
  git_dirty="$(git -C "$ROOT_DIR" status --short 2>/dev/null | wc -l | tr -d ' ')"
  if timeout 30 "$ROOT_DIR/scripts/design-check.sh" >/dev/null 2>&1; then design_state="OK"; else design_state="PART"; fi
  if timeout "${SEVENOS_RELEASE_IDENTITY_TIMEOUT:-45s}" "$ROOT_DIR/scripts/identity-experience.sh" json >/dev/null 2>&1; then identity_state="OK"; else identity_state="PART"; fi
  if timeout "${SEVENOS_RELEASE_SMOKE_TIMEOUT:-60s}" "$ROOT_DIR/scripts/smoke.sh" doctor >/dev/null 2>&1; then smoke_state="OK"; else smoke_state="PART"; fi
  if timeout "${SEVENOS_RELEASE_SURFACES_TIMEOUT:-40s}" "$ROOT_DIR/scripts/surfaces.sh" doctor >/dev/null 2>&1; then surfaces_state="OK"; else surfaces_state="PART"; fi
  if timeout "${SEVENOS_RELEASE_QUALITY_TIMEOUT:-180s}" "$ROOT_DIR/scripts/public-experience.sh" doctor >/dev/null 2>&1; then quality_state="OK"; else quality_state="PART"; fi
  if [[ "${SEVENOS_RELEASE_DEEP:-0}" == "1" ]]; then
    if PYENV_DISABLE_REHASH=1 timeout "${SEVENOS_RELEASE_UX_TIMEOUT:-600s}" "$ROOT_DIR/scripts/ux-check.sh" >/dev/null 2>&1; then ux_state="OK"; else ux_state="PART"; fi
  else
    ux_state="SKIP"
  fi
  installer_json="$("$ROOT_DIR/scripts/installer-stack.sh" release --json 2>/dev/null || printf '{}')"
  atlas_json="$("$ROOT_DIR/bin/seven" atlas status --json 2>/dev/null || printf '{}')"
  profile_json="$("$ROOT_DIR/profiles/profile-manager.sh" status --json 2>/dev/null || printf '[]')"
  profile_health_json="$("$ROOT_DIR/profiles/profile-manager.sh" health --json 2>/dev/null || printf '{}')"
  profile_migration_json="$("$ROOT_DIR/profiles/profile-manager.sh" migrate-aliases --json 2>/dev/null || printf '{}')"
  bridge_json="$("$ROOT_DIR/scripts/mini-os-relay.sh" doctor --json 2>/dev/null || printf '{}')"
  status_json="$("$ROOT_DIR/scripts/status.sh" --json 2>/dev/null || printf '{}')"
  DOCTOR_JSON="$doctor_json" GIT_DIRTY="$git_dirty" DESIGN_STATE="$design_state" IDENTITY_STATE="$identity_state" SMOKE_STATE="$smoke_state" SURFACES_STATE="$surfaces_state" QUALITY_STATE="$quality_state" UX_STATE="$ux_state" \
  INSTALLER_JSON="$installer_json" ATLAS_JSON="$atlas_json" PROFILE_JSON="$profile_json" PROFILE_HEALTH_JSON="$profile_health_json" PROFILE_MIGRATION_JSON="$profile_migration_json" BRIDGE_JSON="$bridge_json" STATUS_JSON="$status_json" \
  python - <<'PY'
import json
import os

def load(name, fallback):
    try:
        data = json.loads(os.environ.get(name, ""))
        return data
    except Exception:
        return fallback

doctor = load("DOCTOR_JSON", {})
installer = load("INSTALLER_JSON", {})
atlas = load("ATLAS_JSON", {})
profiles = load("PROFILE_JSON", [])
profile_health = load("PROFILE_HEALTH_JSON", {})
profile_migration = load("PROFILE_MIGRATION_JSON", {})
bridge = load("BRIDGE_JSON", {})
status = load("STATUS_JSON", {})
git_dirty = int(os.environ.get("GIT_DIRTY", "0") or 0)

checks = []
def add(key, state, title, detail, command, severity="medium"):
    checks.append({
        "key": key,
        "state": state,
        "title": title,
        "detail": detail,
        "command": command,
        "severity": severity,
    })

summary = doctor.get("summary", {})
add("doctor", "OK" if summary.get("critical", 1) == 0 and summary.get("high", 1) == 0 else "PART", "Seven Doctor clean", f"{summary.get('critical', 0)} critical, {summary.get('high', 0)} high issue(s)", "seven doctor check", "high")
add("design-check", os.environ.get("DESIGN_STATE", "PART"), "Design coherence", "SevenOS design contract passes.", "scripts/design-check.sh", "high")
add("identity-experience", os.environ.get("IDENTITY_STATE", "PART"), "SevenOS identity experience", "Prism, native surfaces, language, theme, update and release guidance stay coherent.", "seven identity experience", "high")
add("smoke-check", os.environ.get("SMOKE_STATE", "PART"), "Fast product smoke gate", "SevenOS public contracts respond quickly.", "seven smoke doctor", "high")
add("surfaces-check", os.environ.get("SURFACES_STATE", "PART"), "Native surfaces and old-screen guard", "SevenOS visible surfaces are native and legacy screens stay blocked.", "seven surfaces doctor", "high")
add("public-quality", os.environ.get("QUALITY_STATE", "PART"), "Public experience aggregate", "Health, update, Shell, mini OS and Server/Deploy gates are coherent for users.", "seven quality doctor", "high")
ux_state = os.environ.get("UX_STATE", "PART")
ux_detail = "Full developer UX audit passed." if ux_state == "OK" else ("Set SEVENOS_RELEASE_DEEP=1 to run the full developer UX audit." if ux_state == "SKIP" else "Full developer UX audit failed or timed out.")
add("ux-check", ux_state, "Deep UX coherence", ux_detail, "SEVENOS_RELEASE_DEEP=1 scripts/ux-check.sh", "medium")
add("worktree-freeze", "OK" if git_dirty == 0 else "PART", "Release worktree freeze", f"{git_dirty} uncommitted path(s)", "git status --short", "high")
installer_state = installer.get("state", "unknown")
add("installer", "OK" if installer_state == "graphical-ready" else "PART", "Graphical installer release", installer_state, "seven installer release", "high")
missing_atlas = atlas.get("missing_required") or []
add("atlas", "OK" if not missing_atlas else "PART", "Atlas Explorer", f"{len(missing_atlas)} required package(s) missing", "seven atlas install --yes", "medium")
profile_total = len([item for item in profiles if isinstance(item, dict)])
profile_ready = sum(1 for item in profiles if isinstance(item, dict) and item.get("state") == "OK")
alias_pending = int((profile_health.get("summary") or {}).get("alias_migration_pending", profile_migration.get("pending", 0)) or 0)
add("profiles", "OK" if profile_total == 7 else "PART", "Seven mini OS profiles", f"{profile_total}/7 profile(s) exposed, {profile_ready} package-complete", "seven profile health --json", "medium")
add("profile-aliases", "OK" if alias_pending == 0 else "PART", "Retired profile alias cleanup", f"{alias_pending} stale alias reference(s)", "seven profile migrate-aliases --apply", "medium")
bridge_checks = bridge.get("checks") or {}
add("mini-os-bridge", "OK" if bridge.get("state") == "ready" and int(bridge.get("score", 0) or 0) >= 95 else "PART", "Mini OS bridge isolation", f"{bridge.get('score', 0)}% bridge readiness, {bridge_checks.get('ready_profiles', 0)}/7 ready profiles", "seven bridge doctor", "high")
services = status.get("services", [])
docker = next((item for item in services if item.get("key") == "docker"), {})
add("forge-docker", "OK" if docker.get("state") in {"OK", "QUIET", "PART"} else "PART", "Forge Docker service contract", docker.get("detail", docker.get("state", "unknown")), "seven profile activate forge", "medium")

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
issues = [item for item in checks if item["state"] not in {"OK", "READY", "RUN", "SKIP"}]
issues.sort(key=lambda item: (rank.get(item["severity"], 9), item["key"]))
daily_scope_ignored = {"worktree-freeze", "installer", "ux-check", "public-quality"}
public_ready = not issues
daily_ready = not any(item["severity"] in {"critical", "high"} and item["key"] not in daily_scope_ignored for item in issues)
print(json.dumps({
    "schema": "sevenos.release-doctor.v1",
    "state": "public-release-ready" if public_ready else "daily-driver-ready" if daily_ready else "release-blocked",
    "daily_driver_ready": daily_ready,
    "public_release_ready": public_ready,
    "checks": checks,
    "issues": issues,
    "next": issues[:8],
}, indent=2))
PY
}

if [[ "$RELEASE_OUTPUT" -eq 1 ]]; then
  payload="$(release_payload)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '%s\n' "$payload"
    exit 0
  fi
  RELEASE_JSON="$payload" python - <<'PY'
import json
import os
data = json.loads(os.environ["RELEASE_JSON"])
print("SevenOS Release Doctor")
print("======================")
print(f"State: public_release={data.get('public_release_ready')} daily_driver={data.get('daily_driver_ready')} ({data.get('state')})")
print()
if data.get("issues"):
    print("Release blockers / remaining gates:")
    for item in data["issues"]:
        print(f"  - {item['title']}: {item['detail']}")
        print(f"    {item['command']}")
else:
    print("No release gates left open.")
PY
  exit 0
fi

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
