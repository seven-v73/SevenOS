#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
STATE_FILE="$STATE_DIR/profile.env"
STATE_JSON="$STATE_DIR/profile.json"
LOCK_FILE="$STATE_DIR/profile.lock"
INSTALLED_PACKAGES_READY=0
declare -A INSTALLED_PACKAGES=()

json_escape() {
  local value
  value="$(cat)"
  value="${value%$'\n'}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"\n' "$value"
}

profile_title() {
  case "$1" in
    equinox) printf 'Equinox Balance' ;;
    forge) printf 'Forge Developer' ;;
    shield) printf 'Shield Cybersecurity' ;;
    studio) printf 'Studio Creator' ;;
    windows) printf 'Windows Bridge' ;;
    horizon) printf 'Horizon Cloud' ;;
    pulse) printf 'Pulse Gaming' ;;
    baobab) printf 'Baobab Culture' ;;
    *) printf '%s' "$1" ;;
  esac
}

profile_description() {
  case "$1" in
    equinox) printf 'Balanced general SevenOS mini OS for daily use, broad readiness and neutral capability arbitration.' ;;
    forge) printf 'Developer mini OS for software engineering, toolchains, containers, local services and builds.' ;;
    shield) printf 'Cybersecurity mini OS for authorized audit, forensics, sandboxing, network analysis and reports.' ;;
    studio) printf 'Creator mini OS for logos, design, video, audio, 3D, capture and asset production.' ;;
    windows) printf 'Windows Bridge mini OS: VM-first Windows experience with Wine and Bottles as fallback paths.' ;;
    horizon) printf 'Cloud/server mini OS for deployment, reverse proxy, services, self-hosting and infrastructure.' ;;
    pulse) printf 'Linux gaming mini OS for Proton, low latency, overlays, controllers and frame pacing.' ;;
    baobab) printf 'Culture and learning mini OS for African knowledge, languages, community memory and reading.' ;;
    *) printf 'SevenOS mini OS profile.' ;;
  esac
}

profile_package_files() {
  case "$1" in
    equinox) printf '%s\n' "$ROOT_DIR/scripts/packages-base.txt" ;;
    forge) printf '%s\n' "$ROOT_DIR/scripts/packages-dev.txt" ;;
    shield)
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity-forensics.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity-reversing.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity-wireless.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity-sandbox.txt"
      ;;
    studio) printf '%s\n' "$ROOT_DIR/scripts/packages-creation.txt" ;;
    windows) printf '%s\n' "$ROOT_DIR/scripts/packages-windows.txt" ;;
    horizon) printf '%s\n' "$ROOT_DIR/scripts/packages-server.txt" ;;
    pulse) printf '%s\n' "$ROOT_DIR/scripts/packages-performance.txt" ;;
    baobab) printf '%s\n' "$ROOT_DIR/scripts/packages-culture.txt" ;;
    *) return 1 ;;
  esac
}

profile_optional_package_files() {
  case "$1" in
    baobab) printf '%s\n' "$ROOT_DIR/scripts/packages-culture-optional.txt" ;;
    pulse) printf '%s\n' "$ROOT_DIR/scripts/packages-performance-optional.txt" ;;
    *) return 0 ;;
  esac
}

profile_target() {
  case "$1" in
    equinox) printf 'base' ;;
    forge) printf 'dev' ;;
    shield) printf 'cybersecurity' ;;
    studio) printf 'creation' ;;
    windows) printf 'windows' ;;
    horizon) printf 'server' ;;
    pulse) printf 'performance' ;;
    baobab) printf 'culture' ;;
    *) return 1 ;;
  esac
}

profile_workspace() {
  case "$1" in
    equinox) printf '%s/SevenOS' "$HOME" ;;
    forge) printf '%s/Forge' "$HOME" ;;
    shield) printf '%s/ShieldLab' "$HOME" ;;
    studio) printf '%s/Studio' "$HOME" ;;
    windows) printf '%s/WindowsMode' "$HOME" ;;
    horizon) printf '%s/HorizonDeploy' "$HOME" ;;
    pulse) printf '%s/Pulse' "$HOME" ;;
    baobab) printf '%s/Baobab' "$HOME" ;;
    *) return 1 ;;
  esac
}

profile_accent() {
  case "$1" in
    equinox) printf 'indigo' ;;
    forge) printf 'gold' ;;
    shield) printf 'green' ;;
    studio) printf 'mauve' ;;
    windows) printf 'sky' ;;
    horizon) printf 'sky' ;;
    pulse) printf 'cyan' ;;
    baobab) printf 'baobab' ;;
    *) printf 'gold' ;;
  esac
}

profile_waybar_icon() {
  case "$1" in
    equinox) printf '󰘦' ;;
    baobab) printf '󰔱' ;;
    forge) printf '󰙨' ;;
    shield) printf '󰒃' ;;
    studio) printf '󰏘' ;;
    windows) printf '󰖳' ;;
    horizon) printf '󰖟' ;;
    pulse) printf '󰓅' ;;
    *) printf '󰐃' ;;
  esac
}

profile_short_label() {
  case "$1" in
    equinox) printf 'EQX' ;;
    baobab) printf 'BAO' ;;
    forge) printf 'DEV' ;;
    shield) printf 'SEC' ;;
    studio) printf 'CRT' ;;
    windows) printf 'VM' ;;
    horizon) printf 'CLD' ;;
    pulse) printf 'GAME' ;;
    *) printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | cut -c1-3 ;;
  esac
}

profile_accent_color() {
  case "$1" in
    equinox) printf '#8B7CFF' ;;
    baobab) printf '#A6E3A1' ;;
    forge) printf '#F9E2AF' ;;
    shield) printf '#00FFB3' ;;
    studio) printf '#CBA6F7' ;;
    windows) printf '#74C7EC' ;;
    horizon) printf '#89DCEB' ;;
    pulse) printf '#00D4FF' ;;
    *) printf '#4DA3FF' ;;
  esac
}

profile_secondary_color() {
  case "$1" in
    equinox) printf '#6EA8FF' ;;
    baobab) printf '#FAB387' ;;
    forge) printf '#89B4FA' ;;
    shield) printf '#94E2D5' ;;
    studio) printf '#F5C2E7' ;;
    windows) printf '#89B4FA' ;;
    horizon) printf '#94E2D5' ;;
    pulse) printf '#89B4FA' ;;
    *) printf '#00D4FF' ;;
  esac
}

profile_ui_mood() {
  case "$1" in
    equinox) printf 'neutral glass, balanced controls, general public readiness' ;;
    baobab) printf 'African culture, learning, community memory and calm reading surfaces' ;;
    forge) printf 'developer cockpit, terminal clarity, git, builds and local services' ;;
    shield) printf 'cybersecurity dashboard, visible scope, VPN, audit and isolation emphasis' ;;
    studio) printf 'creator canvas, media actions, color, capture and export flow' ;;
    windows) printf 'Windows VM bridge, snapshots, shared folders, Wine/Bottles fallback guidance' ;;
    horizon) printf 'cloud/server navigator, services, endpoints, logs and deployment controls' ;;
    pulse) printf 'Linux gaming HUD, low latency, overlays, controllers and recording awareness' ;;
    *) printf 'SevenOS adaptive profile surface' ;;
  esac
}

profile_waybar_modules() {
  case "$1" in
    equinox) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,ai' ;;
    baobab) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,ai' ;;
    forge) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,recorder,ai' ;;
    shield) printf 'profile,spotlight,wifi,bluetooth,audio,battery,vpn,recorder,ai' ;;
    studio) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,recorder,ai' ;;
    windows) printf 'profile,spotlight,wifi,bluetooth,audio,battery,ai' ;;
    horizon) printf 'profile,spotlight,wifi,bluetooth,audio,battery,vpn,recorder,ai' ;;
    pulse) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,recorder,ai' ;;
    *) printf 'profile,spotlight,wifi,bluetooth,audio,battery,ai' ;;
  esac
}

profile_role() {
  case "$1" in
    equinox) printf 'Balance' ;;
    forge) printf 'Developer' ;;
    shield) printf 'Cybersecurity' ;;
    studio) printf 'Creator' ;;
    windows) printf 'Windows VM' ;;
    horizon) printf 'Cloud' ;;
    pulse) printf 'Gaming' ;;
    baobab) printf 'Culture' ;;
    *) printf 'Mini OS' ;;
  esac
}

profile_symbol() {
  case "$1" in
    equinox) printf 'logo-sevenos-symbol' ;;
    forge) printf 'forge-profile-mark' ;;
    shield) printf 'shield-profile-mark' ;;
    studio) printf 'motif-diamond' ;;
    windows) printf 'motif-cross' ;;
    horizon) printf 'motif-stripe' ;;
    pulse) printf 'motif-triangle' ;;
    baobab) printf 'baobab-system-mark' ;;
    *) printf 'logo-sevenos-symbol' ;;
  esac
}

profile_principle() {
  case "$1" in
    equinox) printf 'balanced collaboration' ;;
    forge) printf 'creation through skill' ;;
    shield) printf 'visible protection' ;;
    studio) printf 'expressive production' ;;
    windows) printf 'compatibility without surrender' ;;
    horizon) printf 'deployment and reach' ;;
    pulse) printf 'responsive performance' ;;
    baobab) printf 'culture without noise' ;;
    *) printf 'sovereign workflow' ;;
  esac
}

profile_story() {
  case "$1" in
    equinox) printf 'Use SevenOS as a balanced general mini OS where capabilities collaborate without one profile dominating another.' ;;
    forge) printf 'Turn SevenOS into a developer mini OS for code, SDKs, containers, builds, local services and technical learning.' ;;
    shield) printf 'Use SevenOS as a cybersecurity mini OS for authorized scope, audit, sandboxing, forensics and careful reporting.' ;;
    studio) printf 'Use SevenOS as a creator mini OS for logos, design, video, audio, 3D, capture and export.' ;;
    windows) printf 'Run a complete Windows VM-first experience from SevenOS, using Wine and Bottles only as lighter fallback paths.' ;;
    horizon) printf 'Use SevenOS as a cloud/server mini OS for deployments, services, reverse proxy, logs and self-hosting.' ;;
    pulse) printf 'Use SevenOS as a Linux gaming mini OS tuned for Proton, low latency, controllers, overlays and frame pacing.' ;;
    baobab) printf 'Center African culture, learning, languages and community memory without pulling in dev, security, cloud or gaming stacks.' ;;
    *) printf 'Use SevenOS as a coherent sovereign workspace.' ;;
  esac
}

profile_apps() {
  case "$1" in
    equinox) printf '%s\n' "seven hub" "seven files" "kitty" ;;
    forge) printf '%s\n' "kitty" "code" "helix" "docker" ;;
    shield) printf '%s\n' "kitty" "wireshark" "nmap" "zaproxy" ;;
    studio) printf '%s\n' "gimp" "krita" "inkscape" "blender" "kdenlive" ;;
    windows) printf '%s\n' "virt-manager" "bottles" "lutris" ;;
    horizon) printf '%s\n' "kitty" "podman" "caddy" ;;
    pulse) printf '%s\n' "lutris" "gamescope" "mangohud" "gamemoderun" ;;
    baobab) printf '%s\n' "seven hub" "seven reader" "foliate" "calibre" ;;
    *) return 1 ;;
  esac
}

profile_optional_apps() {
  case "$1" in
    baobab) printf '%s\n' "foliate" "calibre" ;;
    pulse) printf '%s\n' "gamescope" "mangohud" ;;
    *) return 0 ;;
  esac
}

profile_app_optional() {
  local key="$1" app="$2" item
  while IFS= read -r item; do
    [[ "$item" == "$app" ]] && return 0
  done < <(profile_optional_apps "$key")
  return 1
}

profile_app_command() {
  case "$1" in
    "seven hub") printf 'seven hub' ;;
    "seven files") printf 'seven-files profile' ;;
    "seven reader") printf 'seven-reader' ;;
    bottles) printf 'seven windows apps' ;;
    "virt-manager") printf 'seven windows vm' ;;
    docker) printf 'docker info' ;;
    podman) printf 'podman info' ;;
    caddy) printf 'caddy version' ;;
    gamescope) printf 'gamescope --help' ;;
    mangohud) printf 'mangohud --help' ;;
    *) printf '%s' "$1" ;;
  esac
}

profile_app_state() {
  local app="$1"
  case "$app" in
    "seven hub") [[ -x "$ROOT_DIR/seven-hub/bin/seven-hub" || -x "$ROOT_DIR/bin/seven" ]] && printf 'OK' || printf 'MISS' ;;
    "seven files") [[ -x "$ROOT_DIR/bin/seven-files" ]] && printf 'OK' || printf 'MISS' ;;
    "seven reader") [[ -x "$ROOT_DIR/bin/seven-reader" ]] && printf 'OK' || printf 'MISS' ;;
    bottles)
      if command -v flatpak >/dev/null 2>&1 && flatpak info com.usebottles.bottles >/dev/null 2>&1; then
        printf 'OK'
      else
        printf 'MISS'
      fi
      ;;
    gimp)
      command -v gimp >/dev/null 2>&1 || flatpak_app_installed org.gimp.GIMP && printf 'OK' || printf 'MISS'
      ;;
    krita)
      command -v krita >/dev/null 2>&1 || flatpak_app_installed org.kde.krita && printf 'OK' || printf 'MISS'
      ;;
    inkscape)
      command -v inkscape >/dev/null 2>&1 || flatpak_app_installed org.inkscape.Inkscape && printf 'OK' || printf 'MISS'
      ;;
    blender)
      command -v blender >/dev/null 2>&1 || flatpak_app_installed org.blender.Blender && printf 'OK' || printf 'MISS'
      ;;
    kdenlive)
      command -v kdenlive >/dev/null 2>&1 || flatpak_app_installed org.kde.kdenlive && printf 'OK' || printf 'MISS'
      ;;
    *) command -v "$app" >/dev/null 2>&1 && printf 'OK' || printf 'MISS' ;;
  esac
}

profile_missing_packages() {
  local key="$1"
  local package package_file

  while IFS= read -r package_file; do
    [[ -f "$package_file" ]] || continue
    while IFS= read -r package; do
      package="${package%%#*}"
      package="${package//[[:space:]]/}"
      [[ -z "$package" ]] && continue
      package_installed "$package" || printf '%s\n' "$package"
    done < "$package_file"
  done < <(profile_package_files "$key")
}

profile_missing_apps() {
  local key="$1"
  local app

  while IFS= read -r app; do
    if [[ "$(profile_app_state "$app")" == "OK" ]]; then
      continue
    fi
    profile_app_optional "$key" "$app" && continue
    printf '%s\n' "$app"
  done < <(profile_apps "$key")
}

profile_workspace_dirs() {
  case "$1" in
    equinox) printf '%s\n' "Dashboard" "Documents" "Projects" "Media" "System" ;;
    forge) printf '%s\n' "Projects" "Sandboxes" "Containers" "Notes" ;;
    shield) printf '%s\n' "Labs" "Reports" "Captures" "Wordlists" "Evidence" ;;
    studio) printf '%s\n' "Images" "Video" "Audio" "3D" "Exports" "References" ;;
    windows) printf '%s\n' "Bottles" "VMs" "Installers" "Shared" ;;
    horizon) printf '%s\n' "Projects" "Deployments" "Services" "Logs" ;;
    pulse) printf '%s\n' "Games" "Launchers" "Benchmarks" "Clips" ;;
    baobab) printf '%s\n' "Culture" "Languages" "Community" "Archives" "Stories" ;;
    *) return 1 ;;
  esac
}

profile_state_dir() {
  printf '%s/.sevenos' "$(profile_workspace "$1")"
}

profile_manifest_path() {
  printf '%s/profile.json' "$(profile_state_dir "$1")"
}

profile_checklist_path() {
  printf '%s/CHECKLIST.md' "$(profile_state_dir "$1")"
}

profile_launcher_path() {
  printf '%s/launch.sh' "$(profile_state_dir "$1")"
}

profile_keys() {
  printf '%s\n' equinox baobab forge shield studio windows horizon pulse
}

profile_next_actions() {
  local key="$1"
  local counts installed total state
  counts="$(profile_counts "$key")"
  installed="${counts%% *}"
  total="${counts##* }"
  state="$(profile_state "$installed" "$total")"

  if [[ "$(active_profile)" != "$key" ]]; then
    printf '%s\t%s\n' "Activate $(profile_title "$key")" "seven profile activate $key"
  fi
  if [[ "$(profile_bootstrap_state "$key")" != "OK" ]]; then
    printf '%s\t%s\n' "Bootstrap $(profile_title "$key") workspace" "seven profile bootstrap $key"
  fi
  if [[ "$state" != "OK" ]]; then
    printf '%s\t%s\n' "Install missing $(profile_title "$key") tools" "seven profile install $key"
  fi
  printf '%s\t%s\n' "Open $(profile_title "$key") center" "seven profile center $key"
  printf '%s\t%s\n' "Open $(profile_title "$key") workspace" "seven profile open $key"
  printf '%s\t%s\n' "Show $(profile_title "$key") apps" "seven profile apps $key"
  case "$key" in
    shield) printf '%s\t%s\n' "Open Cyber Lab" "seven shield lab --preset web" ;;
    windows) printf '%s\t%s\n' "Open Windows Mode guide" "seven windows guide" ;;
    horizon) printf '%s\t%s\n' "Detect deployable project" "seven deploy detect ." ;;
    equinox) printf '%s\t%s\n' "Preview balanced runtime" "seven runtime plan equinox forge shield studio horizon pulse" ;;
    pulse) printf '%s\t%s\n' "Open performance runtime plan" "seven runtime plan pulse shield" ;;
  esac
}

profile_bootstrap_state() {
  local key="$1"
  local manifest checklist launcher
  manifest="$(profile_manifest_path "$key")"
  checklist="$(profile_checklist_path "$key")"
  launcher="$(profile_launcher_path "$key")"

  if [[ -s "$manifest" && -s "$checklist" && -x "$launcher" ]]; then
    printf 'OK'
  elif [[ -e "$manifest" || -e "$checklist" || -e "$launcher" ]]; then
    printf 'PART'
  else
    printf 'MISS'
  fi
}

profile_runtime_summary_json() {
  local key="$1"
  local isolation_file="$STATE_DIR/profile-isolation.json"
  local services_file="$STATE_DIR/profile-services.json"
  local inactive_file="$STATE_DIR/inactive-packages.json"
  python - "$key" "$isolation_file" "$services_file" "$inactive_file" "$(active_profile)" <<'PY'
import json
import sys
from pathlib import Path

key, isolation_path, services_path, inactive_path, active = sys.argv[1:]

def load(path, default):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default

isolation = load(isolation_path, {})
services = load(services_path, [])
inactive = load(inactive_path, [])
selected = isolation.get("selected_profiles") or [active]
capabilities = isolation.get("capabilities") or []
primary = isolation.get("primary") or active
schema_ok = isolation.get("schema") == "sevenos.profile-isolation.v1"

if key == primary:
    lifecycle = "ACTIVE"
    isolation_state = "active"
elif key in capabilities or key in selected:
    lifecycle = "CAPABILITY"
    isolation_state = "injected"
elif schema_ok:
    lifecycle = "SUSPENDED"
    isolation_state = "quiet"
else:
    lifecycle = "UNKNOWN"
    isolation_state = "stale"

inactive_owned = [
    item.get("package") for item in inactive
    if key in [owner.split(":", 1)[0] for owner in item.get("owners", [])]
]
owned_services = [
    item for item in services
    if key in item.get("owners", [])
]
allowed_services = [item.get("service") for item in owned_services if item.get("allowed")]
quiet_services = [item.get("service") for item in owned_services if not item.get("allowed")]

payload = {
    "lifecycle": lifecycle,
    "isolation_state": isolation_state,
    "primary": primary,
    "selected": key in selected,
    "capability_active": key in capabilities,
    "isolation_ready": schema_ok,
    "inactive_owned_packages": len(inactive_owned),
    "inactive_owned_packages_preview": inactive_owned[:8],
    "allowed_services": allowed_services,
    "quiet_services": quiet_services,
    "service_state": "mixed" if allowed_services and quiet_services else ("allowed" if allowed_services else ("quiet" if quiet_services else "none")),
}
print(json.dumps(payload, separators=(",", ":")))
PY
}

active_profile() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
    printf '%s' "${SEVENOS_ACTIVE_PROFILE:-equinox}"
  else
    printf 'equinox'
  fi
}

apps_json() {
  local key="$1"
  local first=1 app app_state optional_bool
  printf '['
  while IFS= read -r app; do
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    app_state="$(profile_app_state "$app")"
    optional_bool=false
    if [[ "$app_state" != "OK" ]] && profile_app_optional "$key" "$app"; then
      app_state="OPT"
      optional_bool=true
    fi
    printf '{'
    printf '"name":%s,' "$(printf '%s' "$app" | json_escape)"
    printf '"state":%s,' "$(printf '%s' "$app_state" | json_escape)"
    printf '"optional":%s,' "$optional_bool"
    printf '"command":%s' "$(profile_app_command "$app" | json_escape)"
    printf '}'
  done < <(profile_apps "$key")
  printf ']'
}

next_actions_json() {
  local key="$1"
  local first=1 label command
  printf '['
  while IFS=$'\t' read -r label command; do
    [[ -n "${label:-}" ]] || continue
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    printf '{'
    printf '"label":%s,' "$(printf '%s' "$label" | json_escape)"
    printf '"command":%s' "$(printf '%s' "$command" | json_escape)"
    printf '}'
  done < <(profile_next_actions "$key")
  printf ']'
}

profile_json_object() {
  local key="$1"
  local counts installed total state active_bool
  counts="$(profile_counts "$key")"
  installed="${counts%% *}"
  total="${counts##* }"
  state="$(profile_state "$installed" "$total")"
  active_bool=false
  [[ "$(active_profile)" == "$key" ]] && active_bool=true

  printf '{'
  printf '"key":%s,' "$(printf '%s' "$key" | json_escape)"
  printf '"title":%s,' "$(profile_title "$key" | json_escape)"
  printf '"description":%s,' "$(profile_description "$key" | json_escape)"
  printf '"role":%s,' "$(profile_role "$key" | json_escape)"
  printf '"symbol":%s,' "$(profile_symbol "$key" | json_escape)"
  printf '"waybar_icon":%s,' "$(profile_waybar_icon "$key" | json_escape)"
  printf '"short_label":%s,' "$(profile_short_label "$key" | json_escape)"
  printf '"accent_color":%s,' "$(profile_accent_color "$key" | json_escape)"
  printf '"secondary_color":%s,' "$(profile_secondary_color "$key" | json_escape)"
  printf '"ui_mood":%s,' "$(profile_ui_mood "$key" | json_escape)"
  printf '"waybar_modules":%s,' "$(profile_waybar_modules "$key" | json_escape)"
  printf '"principle":%s,' "$(profile_principle "$key" | json_escape)"
  printf '"story":%s,' "$(profile_story "$key" | json_escape)"
  printf '"state":%s,' "$(printf '%s' "$state" | json_escape)"
  printf '"bootstrap_state":%s,' "$(profile_bootstrap_state "$key" | json_escape)"
  printf '"runtime":'
  profile_runtime_summary_json "$key"
  printf ','
  printf '"installed":%s,' "$installed"
  printf '"total":%s,' "$total"
  printf '"active":%s,' "$active_bool"
  printf '"workspace":%s,' "$(profile_workspace "$key" | json_escape)"
  printf '"state_dir":%s,' "$(profile_state_dir "$key" | json_escape)"
  printf '"manifest":%s,' "$(profile_manifest_path "$key" | json_escape)"
  printf '"checklist":%s,' "$(profile_checklist_path "$key" | json_escape)"
  printf '"launcher":%s,' "$(profile_launcher_path "$key" | json_escape)"
  printf '"accent":%s,' "$(profile_accent "$key" | json_escape)"
  printf '"apps":['
  local app_first=1 app
  while IFS= read -r app; do
    [[ "$app_first" -eq 1 ]] || printf ','
    app_first=0
    printf '%s' "$(printf '%s' "$app" | json_escape)"
  done < <(profile_apps "$key")
  printf '],'
  printf '"app_status":'
  apps_json "$key"
  printf ','
  printf '"next_actions":'
  next_actions_json "$key"
  printf ','
  printf '"action":%s,' "$(printf 'seven profile install %s' "$key" | json_escape)"
  printf '"bootstrap_command":%s' "$(printf 'seven profile bootstrap %s' "$key" | json_escape)"
  printf '}'
}

gap_json_object() {
  local key="$1"
  local counts installed total state priority missing_count missing_app_count
  counts="$(profile_counts "$key")"
  installed="${counts%% *}"
  total="${counts##* }"
  state="$(profile_state "$installed" "$total")"
  missing_count=$((total - installed))
  missing_app_count="$(profile_missing_apps "$key" | sed '/^$/d' | wc -l | tr -d ' ')"

  case "$key:$state" in
    shield:*) priority="critical" ;;
    studio:MISS|horizon:MISS) priority="high" ;;
    studio:PART|horizon:PART|windows:PART|windows:MISS) priority="high" ;;
    *:PART) priority="medium" ;;
    *:MISS) priority="high" ;;
    *) priority="low" ;;
  esac

  printf '{'
  printf '"key":%s,' "$(printf '%s' "$key" | json_escape)"
  printf '"title":%s,' "$(profile_title "$key" | json_escape)"
  printf '"state":%s,' "$(printf '%s' "$state" | json_escape)"
  printf '"bootstrap_state":%s,' "$(profile_bootstrap_state "$key" | json_escape)"
  printf '"runtime":'
  profile_runtime_summary_json "$key"
  printf ','
  printf '"priority":%s,' "$(printf '%s' "$priority" | json_escape)"
  printf '"installed":%s,' "$installed"
  printf '"total":%s,' "$total"
  printf '"missing_count":%s,' "$missing_count"
  printf '"missing_app_count":%s,' "$missing_app_count"
  printf '"workspace":%s,' "$(profile_workspace "$key" | json_escape)"
  printf '"install_command":%s,' "$(printf 'seven profile install %s' "$key" | json_escape)"
  printf '"bootstrap_command":%s,' "$(printf 'seven profile bootstrap %s' "$key" | json_escape)"
  printf '"open_command":%s,' "$(printf 'seven profile open %s' "$key" | json_escape)"
  printf '"missing_packages":['
  local first=1 package
  while IFS= read -r package; do
    [[ -n "$package" ]] || continue
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    printf '%s' "$(printf '%s' "$package" | json_escape)"
  done < <(profile_missing_packages "$key")
  printf '],'
  printf '"missing_apps":['
  first=1
  while IFS= read -r app; do
    [[ -n "$app" ]] || continue
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    printf '%s' "$(printf '%s' "$app" | json_escape)"
  done < <(profile_missing_apps "$key")
  printf ']'
  printf '}'
}

package_installed() {
  if [[ "$INSTALLED_PACKAGES_READY" -eq 0 ]]; then
    INSTALLED_PACKAGES_READY=1
    if command -v pacman >/dev/null 2>&1; then
      local package
      while IFS= read -r package; do
        [[ -n "$package" ]] && INSTALLED_PACKAGES["$package"]=1
      done < <(pacman -Qq 2>/dev/null || true)
    fi
  fi

  [[ -n "${INSTALLED_PACKAGES[$1]+x}" ]] && return 0

  local alternative
  while IFS= read -r alternative; do
    [[ -n "$alternative" ]] || continue
    [[ -n "${INSTALLED_PACKAGES[$alternative]+x}" ]] && return 0
  done < <(package_alternatives "$1")

  local flatpak_id
  flatpak_id="$(package_flatpak_equivalent "$1")"
  [[ -n "$flatpak_id" ]] && flatpak_app_installed "$flatpak_id"
}

package_alternatives() {
  case "$1" in
    code) printf '%s\n' visual-studio-code-bin vscodium-bin vscodium ;;
    p7zip) printf '%s\n' 7zip ;;
    7zip) printf '%s\n' p7zip ;;
  esac
}

flatpak_app_installed() {
  local app_id="$1"
  command -v flatpak >/dev/null 2>&1 && flatpak info "$app_id" >/dev/null 2>&1
}

package_flatpak_equivalent() {
  case "$1" in
    gimp) printf 'org.gimp.GIMP' ;;
    krita) printf 'org.kde.krita' ;;
    inkscape) printf 'org.inkscape.Inkscape' ;;
    blender) printf 'org.blender.Blender' ;;
    kdenlive) printf 'org.kde.kdenlive' ;;
    obs-studio) printf 'com.obsproject.Studio' ;;
    audacity) printf 'org.audacityteam.Audacity' ;;
    darktable) printf 'org.darktable.Darktable' ;;
    rawtherapee) printf 'com.rawtherapee.RawTherapee' ;;
    scribus) printf 'net.scribus.Scribus' ;;
    lmms) printf 'io.lmms.LMMS' ;;
    handbrake) printf 'fr.handbrake.ghb' ;;
  esac
}

profile_counts() {
  local key="$1"
  local installed=0
  local total=0
  local package package_file

  while IFS= read -r package_file; do
    [[ -f "$package_file" ]] || continue
    while IFS= read -r package; do
      package="${package%%#*}"
      package="${package//[[:space:]]/}"
      [[ -z "$package" ]] && continue
      total=$((total + 1))
      package_installed "$package" && installed=$((installed + 1))
    done < "$package_file"
  done < <(profile_package_files "$key")

  printf '%s %s\n' "$installed" "$total"
}

profile_state() {
  local installed="$1"
  local total="$2"

  if [[ "$total" -eq 0 ]]; then
    printf 'MISS'
  elif [[ "$installed" -eq "$total" ]]; then
    printf 'OK'
  elif [[ "$installed" -gt 0 ]]; then
    printf 'PART'
  else
    printf 'MISS'
  fi
}

write_workspace_readme() {
  local key="$1"
  local workspace
  workspace="$(profile_workspace "$key")"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$workspace"
    while IFS= read -r dir; do
      printf 'mkdir -p %q\n' "$workspace/$dir"
    done < <(profile_workspace_dirs "$key")
    printf 'write %q\n' "$workspace/README.md"
    write_profile_manifest "$key"
    write_profile_checklist "$key"
    write_profile_launcher "$key"
    return 0
  fi

  mkdir -p "$workspace"
  while IFS= read -r dir; do
    mkdir -p "$workspace/$dir"
  done < <(profile_workspace_dirs "$key")
  cat > "$workspace/README.md" <<EOF
# SevenOS $(profile_title "$key")

$(profile_description "$key")

Role: $(profile_role "$key")
Principle: $(profile_principle "$key")
Accent: $(profile_accent "$key")
Symbol: $(profile_symbol "$key")

$(profile_story "$key")

Useful commands:

- seven profile status
- seven profile show $key
- seven profile activate $key
- seven profile install $key
- seven profile open $key
EOF
  write_profile_manifest "$key"
  write_profile_checklist "$key"
  write_profile_launcher "$key"
}

write_profile_manifest() {
  local key="$1"
  local state_dir manifest
  state_dir="$(profile_state_dir "$key")"
  manifest="$(profile_manifest_path "$key")"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$state_dir"
    printf 'write %q\n' "$manifest"
    return 0
  fi

  mkdir -p "$state_dir"
  profile_json_object "$key" > "$manifest"
}

write_profile_checklist() {
  local key="$1"
  local state_dir checklist workspace counts installed total state item label command missing_packages
  state_dir="$(profile_state_dir "$key")"
  checklist="$(profile_checklist_path "$key")"
  workspace="$(profile_workspace "$key")"
  counts="$(profile_counts "$key")"
  installed="${counts%% *}"
  total="${counts##* }"
  state="$(profile_state "$installed" "$total")"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$state_dir"
    printf 'write %q\n' "$checklist"
    return 0
  fi

  mkdir -p "$state_dir"
  {
    printf '# SevenOS %s Checklist\n\n' "$(profile_title "$key")"
    printf '%s\n\n' "$(profile_description "$key")"
    printf -- '- Role: %s\n' "$(profile_role "$key")"
    printf -- '- Principle: %s\n' "$(profile_principle "$key")"
    printf -- '- State: %s (%s/%s packages)\n' "$state" "$installed" "$total"
    printf -- '- Workspace: `%s`\n\n' "$workspace"
    printf '## Workspace\n\n'
    while IFS= read -r item; do
      printf -- '- [ ] `%s/%s`\n' "$workspace" "$item"
    done < <(profile_workspace_dirs "$key")
    printf '\n## Apps\n\n'
    while IFS= read -r item; do
      printf -- '- [%s] `%s` - `%s`\n' "$([[ "$(profile_app_state "$item")" == "OK" ]] && printf x || printf ' ')" "$item" "$(profile_app_command "$item")"
    done < <(profile_apps "$key")
    printf '\n## Missing Packages\n\n'
    missing_packages="$(profile_missing_packages "$key" | sed '/^$/d')"
    if [[ -z "$missing_packages" ]]; then
      printf -- '- [x] No missing packages detected.\n'
    else
      while IFS= read -r item; do
        [[ -n "$item" ]] && printf -- '- [ ] `%s`\n' "$item"
      done <<<"$missing_packages"
    fi
    printf '\n## Next Actions\n\n'
    while IFS=$'\t' read -r label command; do
      [[ -n "${label:-}" ]] || continue
      printf -- '- [ ] %s: `%s`\n' "$label" "$command"
    done < <(profile_next_actions "$key")
  } > "$checklist"
}

write_profile_launcher() {
  local key="$1"
  local state_dir launcher title workspace app command
  state_dir="$(profile_state_dir "$key")"
  launcher="$(profile_launcher_path "$key")"
  title="$(profile_title "$key")"
  workspace="$(profile_workspace "$key")"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$state_dir"
    printf 'write %q\n' "$launcher"
    printf 'chmod +x %q\n' "$launcher"
    return 0
  fi

  mkdir -p "$state_dir"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -Eeuo pipefail\n\n'
    printf 'PROFILE_KEY=%q\n' "$key"
    printf 'PROFILE_TITLE=%q\n' "$title"
    printf 'WORKSPACE=%q\n' "$workspace"
    printf 'ROOT_DIR="${SEVENOS_ROOT:-%q}"\n\n' "$ROOT_DIR"
    cat <<'EOF'
run_command() {
  local command="$1"
  if [[ -z "$command" ]]; then
    return 0
  fi
  bash -lc "$command"
}

show_menu() {
  printf 'SevenOS %s workspace\n\n' "$PROFILE_TITLE"
  printf '  open      Open workspace\n'
  printf '  install   Install missing profile tools\n'
  printf '  status    Show profile status\n'
  printf '  checklist Open checklist path\n'
EOF
    while IFS= read -r app; do
      printf '  printf %q %q %q\n' '  %-9s Launch %s\n' "$app" "$app"
    done < <(profile_apps "$key")
    cat <<'EOF'
}

case "${1:-menu}" in
  menu)
    show_menu
    ;;
  open)
    exec "${ROOT_DIR}/bin/seven" profile open "$PROFILE_KEY"
    ;;
  install)
    exec "${ROOT_DIR}/bin/seven" profile install "$PROFILE_KEY"
    ;;
  status)
    exec "${ROOT_DIR}/bin/seven" profile show "$PROFILE_KEY"
    ;;
  checklist)
    printf '%s\n' "$WORKSPACE/.sevenos/CHECKLIST.md"
    ;;
EOF
    while IFS= read -r app; do
      command="$(profile_app_command "$app")"
      printf '  %q)\n' "$app"
      printf '    run_command %q\n' "$command"
      printf '    ;;\n'
    done < <(profile_apps "$key")
    cat <<'EOF'
  *)
    printf 'Unknown SevenOS profile action: %s\n\n' "$1" >&2
    show_menu >&2
    exit 1
    ;;
esac
EOF
  } > "$launcher"
  chmod +x "$launcher"
}

write_profile_json() {
  local key="$1"
  if is_dry_run; then
    printf 'write %q\n' "$STATE_JSON"
    return 0
  fi

  python - "$key" "$(profile_title "$key")" "$(profile_description "$key")" "$(profile_workspace "$key")" "$(profile_accent "$key")" "$(profile_role "$key")" "$(profile_symbol "$key")" "$(profile_waybar_icon "$key")" "$(profile_short_label "$key")" "$(profile_accent_color "$key")" "$(profile_secondary_color "$key")" "$(profile_ui_mood "$key")" "$(profile_waybar_modules "$key")" "$(profile_principle "$key")" "$(profile_story "$key")" "$(profile_apps "$key" | paste -sd ',')" <<'PY' > "$STATE_JSON"
import json
import sys

(
    key,
    title,
    description,
    workspace,
    accent,
    role,
    symbol,
    waybar_icon,
    short_label,
    accent_color,
    secondary_color,
    ui_mood,
    waybar_modules,
    principle,
    story,
    apps,
) = sys.argv[1:]
payload = {
    "key": key,
    "title": title,
    "description": description,
    "workspace": workspace,
    "accent": accent,
    "role": role,
    "symbol": symbol,
    "waybar_icon": waybar_icon,
    "short_label": short_label,
    "accent_color": accent_color,
    "secondary_color": secondary_color,
    "ui_mood": ui_mood,
    "waybar_modules": waybar_modules,
    "principle": principle,
    "story": story,
    "apps": [item for item in apps.split(",") if item],
}
print(json.dumps(payload, indent=2))
PY
}

bootstrap_profile() {
  local key="$1"
  profile_target "$key" >/dev/null

  log_info "Bootstrapping SevenOS profile workspace: $(profile_title "$key")"
  write_workspace_readme "$key"

  if ! is_dry_run; then
    "$ROOT_DIR/scripts/events.sh" log \
      --source profile \
      --type profile \
      --state OK \
      --message "Profile workspace bootstrapped: $(profile_title "$key")" \
      --command "seven profile bootstrap $key" >/dev/null || true
  fi

  log_success "Profile workspace ready: $(profile_workspace "$key")"
  log_info "Manifest: $(profile_manifest_path "$key")"
  log_info "Checklist: $(profile_checklist_path "$key")"
  log_info "Launcher: $(profile_launcher_path "$key")"
}

bootstrap_all_profiles() {
  local key
  while IFS= read -r key; do
    bootstrap_profile "$key"
  done < <(profile_keys)
}

activate_profile() {
  local key="$1"
  local tmp_env tmp_json
  profile_target "$key" >/dev/null

  log_info "Activating SevenOS profile: $(profile_title "$key")"
  write_workspace_readme "$key"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$STATE_DIR"
    printf 'lock %q\n' "$LOCK_FILE"
    printf 'write %q\n' "$STATE_FILE"
    write_profile_json "$key"
    printf 'seven runtime activate %q --apply --yes\n' "$key"
    printf 'seven hypr lua apply %q\n' "$key"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  exec 9>"$LOCK_FILE"
  if ! flock -w 8 9; then
    log_error "Another SevenOS profile change is already running."
    return 1
  fi

  tmp_env="$(mktemp "$STATE_DIR/profile.env.XXXXXX")"
  tmp_json="$(mktemp "$STATE_DIR/profile.json.XXXXXX")"
  cat > "$tmp_env" <<EOF
SEVENOS_ACTIVE_PROFILE="$key"
SEVENOS_PROFILE_TITLE="$(profile_title "$key")"
SEVENOS_PROFILE_ACCENT="$(profile_accent "$key")"
SEVENOS_PROFILE_ACCENT_COLOR="$(profile_accent_color "$key")"
SEVENOS_PROFILE_SECONDARY_COLOR="$(profile_secondary_color "$key")"
SEVENOS_PROFILE_WORKSPACE="$(profile_workspace "$key")"
EOF
  STATE_JSON="$tmp_json" write_profile_json "$key"
  mv -f "$tmp_env" "$STATE_FILE"
  mv -f "$tmp_json" "$STATE_JSON"

  if [[ -x "$ROOT_DIR/scripts/runtime-orchestrator.sh" ]]; then
    "$ROOT_DIR/scripts/runtime-orchestrator.sh" activate "$key" --apply --yes >/dev/null 2>&1 || true
  fi
  if [[ -x "$ROOT_DIR/scripts/profile-isolation.sh" ]]; then
    "$ROOT_DIR/scripts/profile-isolation.sh" apply "$key" --yes >/dev/null 2>&1 || true
  fi
  if [[ -x "$ROOT_DIR/scripts/hypr-lua.sh" ]]; then
    "$ROOT_DIR/scripts/hypr-lua.sh" apply "$key" >/dev/null 2>&1 || true
  fi

  "$ROOT_DIR/scripts/events.sh" log \
    --source profile \
    --type profile \
    --state OK \
    --message "Active profile changed to $(profile_title "$key")" \
    --command "seven profile activate $key" >/dev/null || true

  log_success "Active profile: $(profile_title "$key")"
  log_info "Workspace: $(profile_workspace "$key")"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "SevenOS Profile" -h string:x-canonical-private-synchronous:sevenos-profile -t 1200 "$(profile_waybar_icon "$key")  $(profile_title "$key")" "$(profile_ui_mood "$key")" >/dev/null 2>&1 || true
  fi
  if command -v seven-profile-theme >/dev/null 2>&1; then
    seven-profile-theme apply >/dev/null 2>&1 || true
  elif [[ -x "$ROOT_DIR/bin/seven-profile-theme" ]]; then
    "$ROOT_DIR/bin/seven-profile-theme" apply >/dev/null 2>&1 || true
  fi
  if command -v seven-waybar >/dev/null 2>&1; then
    seven-waybar restart >/dev/null 2>&1 || true
  elif [[ -x "$ROOT_DIR/bin/seven-waybar" ]]; then
    "$ROOT_DIR/bin/seven-waybar" restart >/dev/null 2>&1 || true
  fi
  flock -u 9
}

open_profile() {
  local key="${1:-$(active_profile)}"
  local workspace
  workspace="$(profile_workspace "$key")"
  write_workspace_readme "$key"

  if is_dry_run; then
    printf 'seven-files open %q\n' "$workspace"
    return 0
  fi

  if command -v seven-files >/dev/null 2>&1; then
    seven-files open "$workspace"
  elif [[ -x "$ROOT_DIR/bin/seven-files" ]]; then
    "$ROOT_DIR/bin/seven-files" open "$workspace"
  else
    xdg-open "$workspace" >/dev/null 2>&1 || printf '%s\n' "$workspace"
  fi
}

install_profile() {
  local key="$1"
  local target
  target="$(profile_target "$key")"

  log_info "Installing SevenOS profile: $(profile_title "$key")"
  "$ROOT_DIR/install.sh" "$target" "${@:2}"
  post_install_profile "$key"
  activate_profile "$key"
}

post_install_profile() {
  local key="$1"

  case "$key" in
    shield)
      log_info "Bootstrapping Shield native workspace..."
      "$ROOT_DIR/security/shield-workspace.sh" bootstrap || true
      log_info "Running Shield post-install audit..."
      "$ROOT_DIR/security/shield-status.sh" status || true
      ;;
    windows)
      log_info "Preparing Windows Mode post-install guidance..."
      "$ROOT_DIR/bin/seven-windows-assistant" plan || true
      ;;
    horizon)
      log_info "Preparing Horizon backend service..."
      "$ROOT_DIR/server/seven-server.sh" install-user-service || true
      "$ROOT_DIR/server/seven-server.sh" start || true
      "$ROOT_DIR/server/seven-server.sh" status || true
      ;;
    equinox)
      log_info "Equinox global profile ready."
      ;;
    forge)
      log_info "Forge post-install check..."
      "$ROOT_DIR/server/seven-deploy.sh" status || true
      ;;
    studio)
      log_info "Studio workspace ready for creative applications."
      ;;
    pulse)
      log_info "Pulse Gaming mini OS ready."
      ;;
    baobab)
      log_info "Baobab cultural workspace ready."
      ;;
  esac
}

show_profile() {
  local key="$1"
  local counts installed total state
  counts="$(profile_counts "$key")"
  installed="${counts%% *}"
  total="${counts##* }"
  state="$(profile_state "$installed" "$total")"

  printf 'Name:        %s\n' "$(profile_title "$key")"
  printf 'Key:         %s\n' "$key"
  printf 'Role:        %s\n' "$(profile_role "$key")"
  printf 'Principle:   %s\n' "$(profile_principle "$key")"
  printf 'Symbol:      %s\n' "$(profile_symbol "$key")"
  printf 'State:       %s %s/%s packages\n' "$state" "$installed" "$total"
  printf 'Bootstrap:   %s\n' "$(profile_bootstrap_state "$key")"
  PROFILE_RUNTIME="$(profile_runtime_summary_json "$key")" python - <<'PY'
import json
import os

runtime = json.loads(os.environ["PROFILE_RUNTIME"])
print(f"Runtime:     {runtime.get('lifecycle')} · {runtime.get('isolation_state')}")
print(f"Isolation:   {'ready' if runtime.get('isolation_ready') else 'stale'} · inactive owned packages: {runtime.get('inactive_owned_packages', 0)}")
if runtime.get("allowed_services"):
    print("Services on: " + ", ".join(runtime["allowed_services"]))
if runtime.get("quiet_services"):
    print("Services off: " + ", ".join(runtime["quiet_services"]))
PY
  printf 'Active:      %s\n' "$([[ "$(active_profile)" == "$key" ]] && printf yes || printf no)"
  printf 'Workspace:   %s\n' "$(profile_workspace "$key")"
  printf 'Accent:      %s\n' "$(profile_accent "$key")"
  printf 'Description: %s\n' "$(profile_description "$key")"
  printf 'Story:       %s\n' "$(profile_story "$key")"
  printf '\nPackage manifests:\n'
  profile_package_files "$key" | sed "s#^$ROOT_DIR/##; s#^#- #"
}

guide_profile() {
  local key="${1:-$(active_profile)}"
  profile_target "$key" >/dev/null

  printf 'SevenOS %s profile\n\n' "$(profile_title "$key")"
  printf '%s · %s · %s\n\n' "$(profile_role "$key")" "$(profile_accent "$key")" "$(profile_principle "$key")"
  printf '%s\n\n' "$(profile_description "$key")"
  printf '%s\n\n' "$(profile_story "$key")"
  printf 'Workspace:\n'
  printf '  %s\n\n' "$(profile_workspace "$key")"
  printf 'Recommended actions:\n'
  while IFS=$'\t' read -r label command; do
    [[ -n "${label:-}" ]] || continue
    printf '  - %-34s %s\n' "$label" "$command"
  done < <(profile_next_actions "$key")
}

apps_human() {
  local key="${1:-$(active_profile)}"
  local app
  profile_target "$key" >/dev/null

  printf 'SevenOS %s apps\n\n' "$(profile_title "$key")"
  while IFS= read -r app; do
    printf '  %-18s %-4s %s\n' "$app" "$(profile_app_state "$app")" "$(profile_app_command "$app")"
  done < <(profile_apps "$key")
}

gaps_json() {
  local first=1 key
  printf '{"schema":"sevenos.profile-gaps.v1","profiles":['
  while IFS= read -r key; do
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    gap_json_object "$key"
  done < <(profile_keys)
  printf ']}\n'
}

gaps_human() {
  local key counts installed total state missing_count missing_apps runtime_label
  printf 'SevenOS Profile Gaps\n\n'
  printf '%-9s %-5s %-9s %-10s %-7s %-8s %s\n' "Profile" "State" "Bootstrap" "Runtime" "Missing" "Apps" "Next"
  printf '%-9s %-5s %-9s %-10s %-7s %-8s %s\n' "-------" "-----" "---------" "-------" "-------" "----" "----"
  while IFS= read -r key; do
    counts="$(profile_counts "$key")"
    installed="${counts%% *}"
    total="${counts##* }"
    state="$(profile_state "$installed" "$total")"
    missing_count=$((total - installed))
    missing_apps="$(profile_missing_apps "$key" | sed '/^$/d' | wc -l | tr -d ' ')"
    runtime_label="$(profile_runtime_summary_json "$key" | python -c 'import json,sys; print(json.load(sys.stdin).get("lifecycle","UNKNOWN"))')"
    printf '%-9s %-5s %-9s %-10s %2s/%-4s %-8s seven profile install %s\n' "$key" "$state" "$(profile_bootstrap_state "$key")" "$runtime_label" "$missing_count" "$total" "$missing_apps" "$key"
  done < <(profile_keys)
}

plan_json() {
  local limit="${1:-6}"
  PROFILE_GAPS_PAYLOAD="$(gaps_json)" PLAN_LIMIT="$limit" python - <<'PY'
import json
import os

data = json.loads(os.environ["PROFILE_GAPS_PAYLOAD"])
limit = int(os.environ.get("PLAN_LIMIT", "6"))
rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}

items = []
for profile in data.get("profiles", []):
    if profile.get("state") == "OK" and profile.get("bootstrap_state") == "OK":
        continue
    missing_packages = profile.get("missing_packages", [])
    missing_apps = profile.get("missing_apps", [])
    items.append({
        "key": profile.get("key"),
        "title": profile.get("title"),
        "priority": profile.get("priority", "medium"),
        "state": profile.get("state"),
        "bootstrap_state": profile.get("bootstrap_state", "MISS"),
        "missing_count": profile.get("missing_count", 0),
        "missing_app_count": profile.get("missing_app_count", 0),
        "missing_packages_preview": missing_packages[:limit],
        "missing_apps": missing_apps,
        "bootstrap_command": profile.get("bootstrap_command"),
        "command": profile.get("install_command"),
        "open_command": profile.get("open_command"),
        "reason": f"{profile.get('title')} is {profile.get('state')} with {profile.get('missing_count', 0)} missing packages and bootstrap {profile.get('bootstrap_state', 'MISS')}",
    })

items.sort(key=lambda item: (rank.get(item["priority"], 9), -int(item.get("missing_count", 0)), item.get("key") or ""))

print(json.dumps({
    "schema": "sevenos.profile-plan.v1",
    "summary": {
        "total": len(items),
        "critical": sum(1 for item in items if item["priority"] == "critical"),
        "high": sum(1 for item in items if item["priority"] == "high"),
        "medium": sum(1 for item in items if item["priority"] == "medium"),
    },
    "next": items[:limit],
}, indent=2))
PY
}

plan_human() {
  local limit="${1:-6}"
  PLAN_PAYLOAD="$(plan_json "$limit")" python - <<'PY'
import json
import os

data = json.loads(os.environ["PLAN_PAYLOAD"])
summary = data.get("summary", {})

print("SevenOS Profile Plan")
print("====================")
print(
    f"Open profiles: {summary.get('total', 0)} "
    f"({summary.get('critical', 0)} critical, {summary.get('high', 0)} high, {summary.get('medium', 0)} medium)"
)
print()
for item in data.get("next", []):
    packages = ", ".join(item.get("missing_packages_preview", [])) or "none"
    apps = ", ".join(item.get("missing_apps", [])) or "none"
    print(f"{item.get('priority', '').upper():<8} {item.get('title')} ({item.get('state')})")
    print(f"         missing packages: {item.get('missing_count')} · preview: {packages}")
    print(f"         missing apps: {apps}")
    print(f"         next: {item.get('command')}")
PY
}

status_json() {
  local first=1
  local active
  active="$(active_profile)"
  printf '['
  while IFS= read -r key; do
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    profile_json_object "$key"
  done < <(profile_keys)
  printf ']\n'
}

health_json() {
  PROFILE_STATUS_PAYLOAD="$(status_json)" python - <<'PY'
import json
import os

profiles = json.loads(os.environ["PROFILE_STATUS_PAYLOAD"])
summary = {
    "total": len(profiles),
    "active": sum(1 for item in profiles if item.get("runtime", {}).get("lifecycle") == "ACTIVE"),
    "capability": sum(1 for item in profiles if item.get("runtime", {}).get("lifecycle") == "CAPABILITY"),
    "quiet": sum(1 for item in profiles if item.get("runtime", {}).get("lifecycle") == "SUSPENDED"),
    "ready": sum(1 for item in profiles if item.get("state") == "OK" and item.get("bootstrap_state") == "OK"),
    "needs_install": sum(1 for item in profiles if item.get("state") != "OK"),
    "needs_bootstrap": sum(1 for item in profiles if item.get("bootstrap_state") != "OK"),
    "isolation_ready": all(item.get("runtime", {}).get("isolation_ready") for item in profiles),
}
issues = []
for item in profiles:
    runtime = item.get("runtime", {})
    if item.get("state") != "OK":
        issues.append({
            "profile": item.get("key"),
            "severity": "high",
            "kind": "packages",
            "detail": f"{item.get('total', 0) - item.get('installed', 0)} packages missing",
            "command": item.get("action"),
        })
    if item.get("bootstrap_state") != "OK":
        issues.append({
            "profile": item.get("key"),
            "severity": "medium",
            "kind": "bootstrap",
            "detail": "workspace manifest/checklist/launcher missing or partial",
            "command": item.get("bootstrap_command"),
        })
    if runtime.get("isolation_state") == "stale":
        issues.append({
            "profile": item.get("key"),
            "severity": "high",
            "kind": "isolation",
            "detail": "profile isolation state is missing or stale",
            "command": "seven profile isolation apply equinox --yes",
        })

print(json.dumps({
    "schema": "sevenos.profile-health.v1",
    "summary": summary,
    "profiles": profiles,
    "issues": issues,
}, indent=2))
PY
}

health_human() {
  PROFILE_HEALTH_PAYLOAD="$(health_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["PROFILE_HEALTH_PAYLOAD"])
summary = data.get("summary", {})
print("SevenOS Profile Health")
print("======================")
print(f"profiles: {summary.get('total', 0)} · ready: {summary.get('ready', 0)} · active: {summary.get('active', 0)} · capabilities: {summary.get('capability', 0)} · quiet: {summary.get('quiet', 0)}")
print(f"isolation: {'ready' if summary.get('isolation_ready') else 'needs apply'}")
print()
for item in data.get("profiles", []):
    runtime = item.get("runtime", {})
    print(f"{item.get('key'):<9} pkg={item.get('state'):<4} boot={item.get('bootstrap_state'):<4} runtime={runtime.get('lifecycle'):<10} isolation={runtime.get('isolation_state'):<8} quiet-packages={runtime.get('inactive_owned_packages', 0)}")
if data.get("issues"):
    print("\nIssues:")
    for issue in data["issues"]:
        print(f"- {issue['profile']}: {issue['kind']} · {issue['detail']} · {issue['command']}")
PY
}

status_human() {
  local active
  active="$(active_profile)"
  printf 'SevenOS profiles\n\n'
  printf '%s %-8s %-4s %-9s %-10s %2s/%-2s %s\n' " " "Profile" "Pkg" "Bootstrap" "Runtime" "OK" "All" "Description"
  while IFS= read -r key; do
    local counts installed total state marker runtime_label
    counts="$(profile_counts "$key")"
    installed="${counts%% *}"
    total="${counts##* }"
    state="$(profile_state "$installed" "$total")"
    marker=' '
    [[ "$active" == "$key" ]] && marker='*'
    runtime_label="$(profile_runtime_summary_json "$key" | python -c 'import json,sys; print(json.load(sys.stdin).get("lifecycle","UNKNOWN"))')"
    printf '%s %-8s %-4s %-9s %-10s %2s/%-2s %s\n' "$marker" "$key" "$state" "$(profile_bootstrap_state "$key")" "$runtime_label" "$installed" "$total" "$(profile_description "$key")"
  done < <(profile_keys)
  printf '\n* active profile. Use: seven profile activate <name>\n'
}

usage() {
  cat <<'EOF'
SevenOS profile manager

Usage:
  seven profile list [--json]
  seven profile status [--json]
  seven profile show <profile>
  seven profile current [--json]
  seven profile guide [profile]
  seven profile apps [profile] [--json]
  seven profile center [profile]
  seven profile gaps [--json]
  seven profile plan [--json] [--limit N]
  seven profile health [--json]
  seven profile catalog [--json]
  seven profile isolation [status|plan|apply|doctor] [profile] [capability ...] [--json] [--yes]
  seven profile bootstrap <profile|all>
  seven profile activate <profile>
  seven profile install <profile>
  seven profile open [profile]

Profiles:
  equinox  Equinox Balance: balanced general mini OS
  baobab   Baobab Culture: African culture and learning mini OS
  forge    Forge Developer: developer mini OS
  shield   Shield Cybersecurity: cybersecurity mini OS
  studio   Studio Creator: creator mini OS
  windows  Windows Bridge: VM-first Windows mini OS
  horizon  Horizon Cloud: cloud/server mini OS
  pulse    Pulse Gaming: Linux gaming mini OS
EOF
}

command="${1:-status}"
shift || true

case "$command" in
  list|status)
    if [[ "${1:-}" == "--json" ]]; then
      status_json
    else
      status_human
    fi
    ;;
  show)
    [[ -n "${1:-}" ]] || { usage; exit 1; }
    show_profile "$1"
    ;;
  current)
    key="$(active_profile)"
    if [[ "${1:-}" == "--json" ]]; then
      profile_json_object "$key"
      printf '\n'
    else
      show_profile "$key"
    fi
    ;;
  catalog)
    if [[ "${1:-}" == "--json" ]]; then
      cat "$ROOT_DIR/profiles/catalog.json"
    else
      python - "$ROOT_DIR/profiles/catalog.json" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print("SevenOS Profile Catalog")
print("=======================")
print(f"default: {data.get('default_profile')}")
for key, item in data.get("profiles", {}).items():
    print(f"{key:<9} {item.get('role', ''):<12} {item.get('domain', '')} · {item.get('runtime_slice', '')}")
PY
    fi
    ;;
  isolation)
    "$ROOT_DIR/scripts/profile-isolation.sh" "$@"
    ;;
  guide)
    guide_profile "${1:-$(active_profile)}"
    ;;
  apps)
    key="${1:-$(active_profile)}"
    if [[ "${2:-}" == "--json" || "${1:-}" == "--json" ]]; then
      [[ "${1:-}" == "--json" ]] && key="$(active_profile)"
      apps_json "$key"
      printf '\n'
    else
      apps_human "$key"
    fi
    ;;
  center)
    key="${1:-$(active_profile)}"
    "$ROOT_DIR/bin/seven-mini-os-center" "$key" >/dev/null 2>&1 &
    ;;
  gaps)
    if [[ "${1:-}" == "--json" ]]; then
      gaps_json
    else
      gaps_human
    fi
    ;;
  health)
    if [[ "${1:-}" == "--json" ]]; then
      health_json
    else
      health_human
    fi
    ;;
  plan)
    json_output=0
    limit=6
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --json|json) json_output=1 ;;
        --limit)
          shift
          limit="${1:-6}"
          [[ "$limit" =~ ^[0-9]+$ ]] || { log_error "--limit expects a number."; exit 1; }
          ;;
        *) log_error "Unknown profile plan option: $1"; usage; exit 1 ;;
      esac
      shift
    done
    if [[ "$json_output" -eq 1 ]]; then
      plan_json "$limit"
    else
      plan_human "$limit"
    fi
    ;;
  activate)
    [[ -n "${1:-}" ]] || { usage; exit 1; }
    activate_profile "$1"
    ;;
  bootstrap)
    target="${1:-$(active_profile)}"
    if [[ "$target" == "all" ]]; then
      bootstrap_all_profiles
    else
      bootstrap_profile "$target"
    fi
    ;;
  install)
    [[ -n "${1:-}" ]] || { usage; exit 1; }
    profile="$1"
    shift
    install_profile "$profile" "$@"
    ;;
  open)
    open_profile "${1:-$(active_profile)}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    # Backward-compatible shortcut: seven profile forge
    install_profile "$command" "$@"
    ;;
esac
