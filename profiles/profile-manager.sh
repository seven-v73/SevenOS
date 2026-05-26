#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

host_home() {
  local home="${SEVENOS_HOST_HOME:-$HOME}"
  if [[ -n "${SEVENOS_HOST_HOME:-}" ]]; then
    printf '%s\n' "$home"
    return 0
  fi
  case "$home" in
    */.local/share/sevenos/profile-containers/*/home)
      printf '%s\n' "${home%%/.local/share/sevenos/profile-containers/*}"
      return 0
      ;;
  esac
  if [[ -n "${USER:-}" && -d "/home/$USER" ]]; then
    printf '/home/%s\n' "$USER"
  else
    printf '%s\n' "$home"
  fi
}

HOST_HOME="$(host_home)"
HOST_CONFIG_HOME="${SEVENOS_HOST_CONFIG_HOME:-$HOST_HOME/.config}"
HOST_DATA_HOME="${SEVENOS_HOST_DATA_HOME:-$HOST_HOME/.local/share}"
STATE_DIR="$HOST_CONFIG_HOME/sevenos"
STATE_FILE="$STATE_DIR/profile.env"
STATE_JSON="$STATE_DIR/profile.json"
LOCK_FILE="$STATE_DIR/profile.lock"
INSTALLED_PACKAGES_READY=0
declare -A INSTALLED_PACKAGES=()

normalize_profile_key() {
  case "$1" in
    horizon) printf 'forge' ;;
    *) printf '%s' "$1" ;;
  esac
}

profile_aliases_json() {
  cat <<'JSON'
{
  "schema": "sevenos.profile-aliases.v1",
  "active_profiles": ["equinox", "baobab", "forge", "shield", "studio", "windows", "pulse"],
  "retired_profiles": {
    "horizon": {
      "redirects_to": "forge",
      "title": "Horizon Cloud",
      "replacement": "Forge DevOps",
      "reason": "Development, local services, containers and cloud deployment now share one coherent DevOps mini OS."
    }
  }
}
JSON
}

profile_aliases_human() {
  cat <<'EOF'
SevenOS profile aliases

Active mini OS:
  equinox, baobab, forge, shield, studio, windows, pulse

Retired aliases:
  horizon -> forge
    Horizon Cloud is now part of Forge DevOps.
    Existing commands keep working, but new UI and docs show Forge DevOps only.
EOF
}

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
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'Equinox Balance' ;;
    forge) printf 'Forge DevOps' ;;
    shield) printf 'Shield Cybersecurity' ;;
    studio) printf 'Studio Creator' ;;
    windows) printf 'Windows' ;;
    pulse) printf 'Pulse Gaming' ;;
    baobab) printf 'Baobab Cultural OS' ;;
    *) printf '%s' "$1" ;;
  esac
}

profile_description() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'Balanced general SevenOS mini OS for daily use, broad readiness and neutral capability arbitration.' ;;
    forge) printf 'Developer and cloud deployment mini OS for code, toolchains, containers, local services, logs and releases.' ;;
    shield) printf 'Cybersecurity mini OS for authorized audit, forensics, sandboxing, network analysis and reports.' ;;
    studio) printf 'Creator mini OS for logos, design, video, audio, 3D, capture and asset production.' ;;
    windows) printf 'Espace Windows pour les applications Windows, les dossiers partagés et Windows complet à la demande.' ;;
    pulse) printf 'Linux gaming mini OS for Proton, low latency, overlays, controllers and frame pacing.' ;;
    baobab) printf 'African cultural mini OS for heritage, languages, oral traditions, music, maps, fashion, food, wisdom and offline community memory.' ;;
    *) printf 'SevenOS mini OS profile.' ;;
  esac
}

profile_package_files() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf '%s\n' "$ROOT_DIR/scripts/packages-base.txt" ;;
    forge)
      printf '%s\n' "$ROOT_DIR/scripts/packages-dev.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-server.txt"
      ;;
    shield)
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity-forensics.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity-reversing.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity-wireless.txt"
      printf '%s\n' "$ROOT_DIR/scripts/packages-cybersecurity-sandbox.txt"
      ;;
    studio) printf '%s\n' "$ROOT_DIR/scripts/packages-creation.txt" ;;
    windows) printf '%s\n' "$ROOT_DIR/scripts/packages-windows.txt" ;;
    pulse) printf '%s\n' "$ROOT_DIR/scripts/packages-performance.txt" ;;
    baobab) printf '%s\n' "$ROOT_DIR/scripts/packages-culture.txt" ;;
    *) return 1 ;;
  esac
}

profile_optional_package_files() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    baobab) printf '%s\n' "$ROOT_DIR/scripts/packages-culture-optional.txt" ;;
    pulse) printf '%s\n' "$ROOT_DIR/scripts/packages-performance-optional.txt" ;;
    *) return 0 ;;
  esac
}

profile_target() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'base' ;;
    forge) printf 'dev' ;;
    shield) printf 'cybersecurity' ;;
    studio) printf 'creation' ;;
    windows) printf 'windows' ;;
    pulse) printf 'performance' ;;
    baobab) printf 'culture' ;;
    *) return 1 ;;
  esac
}

profile_workspace() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf '%s/SevenOS' "$HOST_HOME" ;;
    forge) printf '%s/Forge' "$HOST_HOME" ;;
    shield) printf '%s/ShieldLab' "$HOST_HOME" ;;
    studio) printf '%s/Studio' "$HOST_HOME" ;;
    windows) printf '%s/WindowsMode' "$HOST_HOME" ;;
    pulse) printf '%s/Pulse' "$HOST_HOME" ;;
    baobab) printf '%s/Baobab' "$HOST_HOME" ;;
    *) return 1 ;;
  esac
}

profile_accent() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'indigo' ;;
    forge) printf 'gold' ;;
    shield) printf 'green' ;;
    studio) printf 'mauve' ;;
    windows) printf 'sky' ;;
    pulse) printf 'cyan' ;;
    baobab) printf 'baobab' ;;
    *) printf 'gold' ;;
  esac
}

profile_waybar_icon() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf '󰘦' ;;
    baobab) printf '󰔱' ;;
    forge) printf '󰙨' ;;
    shield) printf '󰒃' ;;
    studio) printf '󰏘' ;;
    windows) printf '󰖳' ;;
    pulse) printf '󰓅' ;;
    *) printf '󰐃' ;;
  esac
}

profile_short_label() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'EQX' ;;
    baobab) printf 'BAO' ;;
    forge) printf 'DEV' ;;
    shield) printf 'SEC' ;;
    studio) printf 'CRT' ;;
    windows) printf 'WIN' ;;
    pulse) printf 'GAME' ;;
    *) printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | cut -c1-3 ;;
  esac
}

profile_accent_color() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf '#8B7CFF' ;;
    baobab) printf '#A6E3A1' ;;
    forge) printf '#F9E2AF' ;;
    shield) printf '#00FFB3' ;;
    studio) printf '#CBA6F7' ;;
    windows) printf '#74C7EC' ;;
    pulse) printf '#00D4FF' ;;
    *) printf '#4DA3FF' ;;
  esac
}

profile_secondary_color() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf '#6EA8FF' ;;
    baobab) printf '#FAB387' ;;
    forge) printf '#89B4FA' ;;
    shield) printf '#94E2D5' ;;
    studio) printf '#F5C2E7' ;;
    windows) printf '#89B4FA' ;;
    pulse) printf '#89B4FA' ;;
    *) printf '#00D4FF' ;;
  esac
}

profile_ui_mood() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'neutral glass, balanced controls, general public readiness' ;;
    baobab) printf 'warm African digital village, heritage library, oral storytelling, textiles, soundscape and community memory' ;;
    forge) printf 'developer cockpit, cloud deploys, containers, services, logs and release flow' ;;
    shield) printf 'cybersecurity dashboard, visible scope, VPN, audit and isolation emphasis' ;;
    studio) printf 'creator canvas, media actions, color, capture and export flow' ;;
    windows) printf 'Applications Windows, dossiers partagés, réparation et Windows complet si nécessaire' ;;
    pulse) printf 'Linux gaming HUD, low latency, overlays, controllers and recording awareness' ;;
    *) printf 'SevenOS adaptive profile surface' ;;
  esac
}

profile_terminal_mode() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'classic' ;;
    forge) printf 'forge' ;;
    shield) printf 'cyber' ;;
    studio) printf 'focus' ;;
    windows) printf 'windows' ;;
    pulse) printf 'dark' ;;
    baobab) printf 'focus' ;;
    *) printf 'classic' ;;
  esac
}

profile_waybar_modules() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,ai' ;;
    baobab) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,ai' ;;
    forge) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,vpn,recorder,ai' ;;
    shield) printf 'profile,spotlight,wifi,bluetooth,audio,battery,vpn,recorder,ai' ;;
    studio) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,recorder,ai' ;;
    windows) printf 'profile,spotlight,wifi,bluetooth,audio,battery,ai' ;;
    pulse) printf 'profile,spotlight,media,wifi,bluetooth,audio,battery,recorder,ai' ;;
    *) printf 'profile,spotlight,wifi,bluetooth,audio,battery,ai' ;;
  esac
}

profile_role() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'Balance' ;;
    forge) printf 'DevOps' ;;
    shield) printf 'Cybersecurity' ;;
    studio) printf 'Creator' ;;
    windows) printf 'Windows' ;;
    pulse) printf 'Gaming' ;;
    baobab) printf 'Culture' ;;
    *) printf 'Mini OS' ;;
  esac
}

profile_symbol() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'logo-sevenos-symbol' ;;
    forge) printf 'forge-profile-mark' ;;
    shield) printf 'shield-profile-mark' ;;
    studio) printf 'motif-diamond' ;;
    windows) printf 'motif-cross' ;;
    pulse) printf 'motif-triangle' ;;
    baobab) printf 'baobab-system-mark' ;;
    *) printf 'logo-sevenos-symbol' ;;
  esac
}

profile_principle() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'balanced collaboration' ;;
    forge) printf 'build, ship and observe' ;;
    shield) printf 'visible protection' ;;
    studio) printf 'expressive production' ;;
    windows) printf 'windows when you need it' ;;
    pulse) printf 'responsive performance' ;;
    baobab) printf 'living heritage, offline-first' ;;
    *) printf 'sovereign workflow' ;;
  esac
}

profile_enter_command() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    windows) printf 'seven windows enter' ;;
    *) return 1 ;;
  esac
}

profile_story() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf 'Use SevenOS as a balanced general mini OS where capabilities collaborate without one profile dominating another.' ;;
    forge) printf 'Turn SevenOS into a DevOps mini OS for code, SDKs, containers, builds, local services, deployments, logs and technical learning.' ;;
    shield) printf 'Use SevenOS as a cybersecurity mini OS for authorized scope, audit, sandboxing, forensics and careful reporting.' ;;
    studio) printf 'Use SevenOS as a creator mini OS for logos, design, video, audio, 3D, capture and export.' ;;
    windows) printf 'Ouvre les applications Windows, les dossiers partagés et Windows complet depuis SevenOS sans étapes manuelles.' ;;
    pulse) printf 'Use SevenOS as a Linux gaming mini OS tuned for Proton, low latency, controllers, overlays and frame pacing.' ;;
    baobab) printf 'Enter Baobab as an African digital village: heritage library, oral stories, language hub, cultural sound, map exploration, fashion, food, wisdom and offline community memory.' ;;
    *) printf 'Use SevenOS as a coherent sovereign workspace.' ;;
  esac
}

profile_apps() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf '%s\n' "seven hub" "seven files" "kitty" ;;
    forge) printf '%s\n' "kitty" "code" "helix" "docker" "podman" "caddy" "ssh" ;;
    shield) printf '%s\n' "kitty" "wireshark" "nmap" "zaproxy" ;;
    studio) printf '%s\n' "gimp" "krita" "inkscape" "blender" "kdenlive" ;;
    windows) printf '%s\n' "virt-manager" "bottles" "lutris" ;;
    pulse) printf '%s\n' "lutris" "gamescope" "mangohud" "gamemoderun" ;;
    baobab) printf '%s\n' "seven hub" "seven baobab" "seven baobab modules" "seven reader" "foliate" "calibre" "mpv" ;;
    *) return 1 ;;
  esac
}

profile_optional_apps() {
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    baobab) printf '%s\n' "seven baobab" "seven baobab modules" "foliate" "calibre" "mpv" "espeak-ng" "festival" "translate-shell" ;;
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
    "seven baobab") printf 'seven baobab open' ;;
    "seven baobab modules") printf 'seven baobab modules' ;;
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
    "seven baobab") [[ -x "$ROOT_DIR/bin/seven" && -x "$ROOT_DIR/scripts/baobab.sh" ]] && printf 'OK' || printf 'MISS' ;;
    "seven baobab modules") [[ -x "$ROOT_DIR/bin/seven" && -x "$ROOT_DIR/scripts/baobab.sh" ]] && printf 'OK' || printf 'MISS' ;;
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

  if [[ -x "$ROOT_DIR/bin/seven-profile-requirements" ]]; then
    "$ROOT_DIR/bin/seven-profile-requirements" status "$key" --json 2>/dev/null |
      python -c 'import json,sys; data=json.load(sys.stdin); print("\n".join((data.get("missing") or {}).get("required", [])))' 2>/dev/null &&
      return 0
  fi

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
  local key
  key="$(normalize_profile_key "$1")"
  case "$key" in
    equinox) printf '%s\n' "Dashboard" "Documents" "Projects" "Media" "System" ;;
    forge) printf '%s\n' "Projects" "Sandboxes" "Containers" "Deployments" "Services" "Logs" "Notes" ;;
    shield) printf '%s\n' "Labs" "Reports" "Captures" "Wordlists" "Evidence" ;;
    studio) printf '%s\n' "Images" "Video" "Audio" "3D" "Exports" "References" ;;
    windows) printf '%s\n' "Applications" "Windows complet" "Installations" "Dossiers" ;;
    pulse) printf '%s\n' "Games" "Launchers" "Benchmarks" "Clips" ;;
    baobab) printf '%s\n' "Village" "Heritage" "Languages" "Stories" "Sound" "Explore" "Museum" "Fashion" "Food" "Wisdom" "Market" ;;
    *) return 1 ;;
  esac
}

profile_state_dir() {
  printf '%s/.sevenos' "$(profile_workspace "$1")"
}

profile_config_dir() {
  local key
  key="$(normalize_profile_key "$1")"
  printf '%s/profiles/%s' "$STATE_DIR" "$key"
}

sync_profile_language() {
  local key config_dir profile_sevenos_dir source_file target_file
  key="$(normalize_profile_key "$1")"
  config_dir="$(profile_config_dir "$key")"
  profile_sevenos_dir="$config_dir/sevenos"

  if is_dry_run; then
    printf 'sync SevenOS language preference into %q\n' "$profile_sevenos_dir"
    return 0
  fi

  mkdir -p "$profile_sevenos_dir"
  for source_file in "$STATE_DIR/language.conf" "$STATE_DIR/language.env"; do
    [[ -s "$source_file" ]] || continue
    target_file="$profile_sevenos_dir/$(basename "$source_file")"
    cp "$source_file" "$target_file"
  done
}

profile_manifest_path() {
  printf '%s/profile.json' "$(profile_state_dir "$1")"
}

profile_experience_path() {
  printf '%s/experience.json' "$(profile_config_dir "$1")"
}

profile_checklist_path() {
  printf '%s/CHECKLIST.md' "$(profile_state_dir "$1")"
}

profile_launcher_path() {
  printf '%s/launch.sh' "$(profile_state_dir "$1")"
}

profile_keys() {
  printf '%s\n' equinox baobab forge shield studio windows pulse
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
    forge) printf '%s\t%s\n' "Detect deployable project" "seven deploy detect ." ;;
    shield) printf '%s\t%s\n' "Open Cyber Lab" "seven shield lab --preset web" ;;
    windows)
      printf '%s\t%s\n' "Ouvrir Windows" "seven windows enter"
      printf '%s\t%s\n' "Ouvrir le panneau Windows" "seven windows open"
      ;;
    equinox) printf '%s\t%s\n' "Preview balanced runtime" "seven runtime plan equinox forge shield studio pulse" ;;
    pulse) printf '%s\t%s\n' "Open performance runtime plan" "seven runtime plan pulse shield" ;;
    baobab)
      printf '%s\t%s\n' "Open Baobab native interface" "seven baobab open"
      printf '%s\t%s\n' "Open Baobab patrimoine" "seven baobab native"
      printf '%s\t%s\n' "Open Baobab Story Mode" "seven baobab story"
      printf '%s\t%s\n' "Open Baobab Museum" "seven baobab museum"
      printf '%s\t%s\n' "Open Baobab Explore" "seven baobab explore"
      printf '%s\t%s\n' "Show Africa country index" "seven baobab countries"
      printf '%s\t%s\n' "Open Burkina Faso detail" "seven baobab country Burkina Faso"
      printf '%s\t%s\n' "Show UNESCO heritage index" "seven baobab unesco"
      printf '%s\t%s\n' "Audit Baobab packs" "seven baobab audit-packs"
      printf '%s\t%s\n' "Show Baobab modules" "seven baobab modules"
      printf '%s\t%s\n' "Check Baobab readiness" "seven baobab doctor"
      ;;
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
import os
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
containers = isolation.get("profile_containers") or {}
strict_runtime = isolation.get("strict_runtime") or {}
container = containers.get(key) if isinstance(containers, dict) else {}
strict = strict_runtime.get(key) if isinstance(strict_runtime, dict) else {}
if not isinstance(container, dict):
    container = {}
if not isinstance(strict, dict):
    strict = {}
selected = isolation.get("selected_profiles") or [active]
capabilities = isolation.get("capabilities") or []
primary = isolation.get("primary") or active
schema_ok = isolation.get("schema") == "sevenos.profile-isolation.v1"
system_contract = (
    key == "equinox"
    and schema_ok
    and container.get("state") == "system"
    and container.get("launch_mode") == "host-system"
    and strict.get("engine") == "host"
    and strict.get("isolation_mode") == "system"
)

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
    "runtime_contract": "host-system" if system_contract else ("mini-os-container" if schema_ok else "unknown"),
    "system_contract": system_contract,
    "launch_mode": container.get("launch_mode", ""),
    "engine": strict.get("engine", container.get("engine", "")),
    "app_data": strict.get("app_data", ""),
}
print(json.dumps(payload, separators=(",", ":")))
PY
}

active_profile() {
  local key
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
    key="${SEVENOS_ACTIVE_PROFILE:-equinox}"
  else
    key="equinox"
  fi
  normalize_profile_key "$key"
}

profile_migration_json() {
  local apply="${1:-0}"
  SEVENOS_PROFILE_MIGRATION_APPLY="$apply" \
  SEVENOS_STATE_DIR="$STATE_DIR" \
  python - <<'PY'
import json
import os
import re
from pathlib import Path

state_dir = Path(os.environ["SEVENOS_STATE_DIR"])
apply = os.environ.get("SEVENOS_PROFILE_MIGRATION_APPLY") == "1"
aliases = {"horizon": "forge"}
files = [
    "profile.env",
    "profile.json",
    "runtime.env",
    "runtime.json",
    "profile-isolation.env",
    "profile-isolation.json",
    "profile-ui.json",
    "profile-services.json",
    "inactive-packages.json",
    "mini-os-bridge.json",
]

def normalize_text(text: str) -> str:
    for old, new in aliases.items():
        text = re.sub(rf'(?<=[=",\\s:]){re.escape(old)}(?=[",\\s\\n])', new, text)
        text = text.replace(f'profile-{old}', f'profile-{new}')
    return text

changes = []
for name in files:
    path = state_dir / name
    if not path.exists() or not path.is_file():
        continue
    before = path.read_text(encoding="utf-8", errors="replace")
    after = normalize_text(before)
    if before == after:
        continue
    changes.append({"file": str(path), "changed": apply, "alias": "horizon", "target": "forge"})
    if apply:
        path.write_text(after, encoding="utf-8")

payload = {
    "schema": "sevenos.profile-migration.v1",
    "state_dir": str(state_dir),
    "apply": apply,
    "pending": 0 if apply else len(changes),
    "changed": len(changes) if apply else 0,
    "aliases": aliases,
    "files": changes,
}
print(json.dumps(payload, indent=2))
PY
}

profile_migration_human() {
  local apply="${1:-0}"
  PROFILE_MIGRATION_PAYLOAD="$(profile_migration_json "$apply")" python - <<'PY'
import json
import os

data = json.loads(os.environ["PROFILE_MIGRATION_PAYLOAD"])
mode = "Applied" if data.get("apply") else "Preview"
count = data.get("changed") if data.get("apply") else data.get("pending")
print(f"SevenOS profile alias migration · {mode}")
print(f"state: {count} file(s)")
if data.get("files"):
    for item in data["files"]:
        print(f"- {item['file']}: {item['alias']} -> {item['target']}")
else:
    print("- no stale profile aliases found")
if not data.get("apply") and data.get("pending"):
    print("\nRun: seven profile migrate-aliases --apply")
PY
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
  printf '"config_dir":%s,' "$(profile_config_dir "$key" | json_escape)"
  printf '"experience":%s,' "$(profile_experience_path "$key" | json_escape)"
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
    studio:MISS) priority="high" ;;
    studio:PART|windows:PART|windows:MISS) priority="high" ;;
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

  if [[ -x "$ROOT_DIR/bin/seven-profile-requirements" ]]; then
    local counts
    counts="$("$ROOT_DIR/bin/seven-profile-requirements" status "$key" --json 2>/dev/null |
      python -c 'import json,sys; data=json.load(sys.stdin); s=data.get("summary") or {}; total=int(s.get("required") or 0); missing=int(s.get("required_missing") or 0); print(f"{total - missing} {total}")' 2>/dev/null || true)"
    if [[ "$counts" =~ ^[0-9]+[[:space:]][0-9]+$ ]]; then
      printf '%s\n' "$counts"
      return 0
    fi
  fi

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

  python - "$key" "$(profile_title "$key")" "$(profile_description "$key")" "$(profile_workspace "$key")" "$(profile_accent "$key")" "$(profile_role "$key")" "$(profile_symbol "$key")" "$(profile_waybar_icon "$key")" "$(profile_short_label "$key")" "$(profile_accent_color "$key")" "$(profile_secondary_color "$key")" "$(profile_ui_mood "$key")" "$(profile_waybar_modules "$key")" "$(profile_principle "$key")" "$(profile_story "$key")" "$(profile_terminal_mode "$key")" "$(profile_apps "$key" | paste -sd ',')" <<'PY' > "$STATE_JSON"
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
    terminal_mode,
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
    "terminal_mode": terminal_mode,
    "apps": [item for item in apps.split(",") if item],
}
print(json.dumps(payload, indent=2))
PY
}

write_active_profile_json_fast() {
  local key="$1"
  local target="${2:-$STATE_JSON}"
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
  printf '"terminal_mode":%s,' "$(profile_terminal_mode "$key" | json_escape)"
  printf '"workspace":%s,' "$(profile_workspace "$key" | json_escape)"
  printf '"accent":%s,' "$(profile_accent "$key" | json_escape)"
  printf '"state":"OK","bootstrap_state":"OK","active":true,'
  printf '"updated_at":%s,' "$(date +%s)"
  printf '"fast_state":true'
  printf '}\n'
}

write_profile_experience() {
  local key="$1"
  local config_dir experience_file
  key="$(normalize_profile_key "$key")"
  config_dir="$(profile_config_dir "$key")"
  experience_file="$(profile_experience_path "$key")"
  mkdir -p "$config_dir"
  PROFILE_HOST_DATA_HOME="$HOST_DATA_HOME" python - "$key" "$(profile_title "$key")" "$(profile_role "$key")" "$(profile_workspace "$key")" "$config_dir" "$(profile_accent_color "$key")" "$(profile_secondary_color "$key")" "$(profile_ui_mood "$key")" "$(profile_principle "$key")" "$(profile_waybar_modules "$key")" "$(profile_terminal_mode "$key")" <<'PY' > "$experience_file"
import json
import os
import sys
from pathlib import Path

(
    key,
    title,
    role,
    workspace,
    config_dir,
    accent_color,
    secondary_color,
    ui_mood,
    principle,
    waybar_modules,
    terminal_mode,
) = sys.argv[1:]
config = Path(config_dir)
data_home = Path(os.environ.get("PROFILE_HOST_DATA_HOME", str(Path.home() / ".local/share")))
wallpaper_profile_dir = data_home / "sevenos/wallpapers/profiles" / key
bridge_profile_dir = data_home / "sevenos/bridge" / key
objects_dir = data_home / "sevenos/objects"
defaults = {
    "equinox": {
        "metaphor": "balance",
        "density": "medium",
        "pace": "steady",
        "home": "daily dashboard",
        "session_policy": "restore balanced work and public OS surfaces",
        "primary_apps": ["seven hub", "seven files", "seven settings"],
    },
    "baobab": {
        "metaphor": "knowledge tree",
        "density": "calm",
        "pace": "slow-learning",
        "home": "arbre de connaissance",
        "session_policy": "restore cultural memory, reading, collection and offline learning",
        "primary_apps": ["seven baobab open", "seven-reader", "mpv"],
    },
    "forge": {
        "metaphor": "workbench",
        "density": "dense",
        "pace": "build-observe",
        "home": "devops cockpit",
        "session_policy": "restore projects, terminals, services and deployment context",
        "primary_apps": ["seven-terminal forge", "code", "docker"],
    },
    "shield": {
        "metaphor": "authorized lab",
        "density": "controlled",
        "pace": "scoped",
        "home": "security operations room",
        "session_policy": "restore only active scope, reports and evidence lanes",
        "primary_apps": ["seven-shield-center-native", "seven shield scope", "wireshark"],
    },
    "studio": {
        "metaphor": "creative atelier",
        "density": "canvas",
        "pace": "creative-flow",
        "home": "studio board",
        "session_policy": "restore assets, references, exports and capture tools",
        "primary_apps": ["krita", "blender", "kdenlive"],
    },
    "windows": {
        "metaphor": "windows space",
        "density": "guided",
        "pace": "guided",
        "home": "windows panel",
        "session_policy": "restore Windows apps, shared folders and full Windows state",
        "primary_apps": ["seven windows open", "seven windows apps", "bottles"],
    },
    "pulse": {
        "metaphor": "performance stage",
        "density": "hud",
        "pace": "low-latency",
        "home": "game hub",
        "session_policy": "restore launchers, overlays, controller and performance state",
        "primary_apps": ["lutris", "gamescope", "mangohud"],
    },
}
experience = defaults.get(key, defaults["equinox"])
passages = {
    "equinox": {
        "enter": "Tu entres dans l'espace d'equilibre SevenOS.",
        "leave": "Tu quittes l'equilibre general pour une experience specialisee.",
        "transition": "SevenOS passe du rythme quotidien vers le mini OS choisi.",
        "sound": "soft-chime",
        "motion": "balanced fade",
    },
    "baobab": {
        "enter": "Tu entres dans l'arbre de connaissance Baobab.",
        "leave": "Tu quittes la memoire culturelle pour une autre forme d'action.",
        "transition": "Memoire culturelle vers construction, creation, securite ou performance.",
        "sound": "organic-breath",
        "motion": "root growth",
    },
    "forge": {
        "enter": "Tu entres dans l'etabli de construction Forge.",
        "leave": "Tu quittes la construction technique pour un autre espace SevenOS.",
        "transition": "L'atelier technique se synchronise avec le mini OS de destination.",
        "sound": "precise-click",
        "motion": "tool snap",
    },
    "shield": {
        "enter": "Tu entres dans un laboratoire autorise Shield.",
        "leave": "Tu quittes le sas de securite, les frontieres restent tracees.",
        "transition": "Le perimetre protege se referme avant le changement d'espace.",
        "sound": "lock-soft",
        "motion": "secure gate",
    },
    "studio": {
        "enter": "Tu entres dans l'atelier creatif Studio.",
        "leave": "Tu quittes le canvas creatif avec tes exports preserves.",
        "transition": "Les references et creations restent dans Studio sauf partage explicite.",
        "sound": "brush-air",
        "motion": "canvas reveal",
    },
    "windows": {
        "enter": "Tu entres dans l'espace Windows.",
        "leave": "Tu quittes Windows, tes dossiers et applications restent ranges.",
        "transition": "SevenOS prepare Windows puis revient vers le mini OS cible.",
        "sound": "soft-open",
        "motion": "window slide",
    },
    "pulse": {
        "enter": "Tu entres sur la scene performance Pulse.",
        "leave": "Tu quittes le mode performance, les captures et profils restent dans Pulse.",
        "transition": "Le rythme basse latence se calme avant le passage.",
        "sound": "low-latency-tick",
        "motion": "hud sweep",
    },
}
passage = passages.get(key, passages["equinox"])
payload = {
    "schema": "sevenos.profile-experience.v1",
    "profile": key,
    "title": title,
    "role": role,
    "principle": principle,
    "ui_mood": ui_mood,
    "workspace": workspace,
    "config_dir": str(config),
    "theme": {
        "mode_file": str(config / "theme.conf"),
        "accent_color": accent_color,
        "secondary_color": secondary_color,
        "waybar_modules": waybar_modules,
        "terminal_mode": terminal_mode,
    },
    "wallpaper": {
        "state": str(config / "wallpaper-state"),
        "custom": str(wallpaper_profile_dir / "wallpaper-custom.png"),
        "active": str(wallpaper_profile_dir / "wallpaper-active.png"),
        "projection": str(data_home / "sevenos/wallpapers/wallpaper-sevenos-active.png"),
    },
    "session": {
        "state": str(config / "session.json"),
        "policy": experience["session_policy"],
        "memory": ["recent_apps", "recent_paths", "workspace", "tasks", "pinned_objects", "mood"],
    },
    "experience": {
        **experience,
        "owned_state": [
            str(config / "theme.conf"),
            str(config / "wallpaper-state"),
            str(config / "profile-ui.json"),
            str(config / "experience.json"),
            str(config / "session.json"),
            str(config / "passage.json"),
            str(bridge_profile_dir / "bridge-inbox.jsonl"),
            str(bridge_profile_dir / "bridge-outbox.jsonl"),
        ],
        "projection_policy": "Only the active mini OS projects into shared Waybar, Hyprpaper and profile-ui files.",
        "passage": passage,
    },
    "communication": {
        "rule": "Profiles communicate through SevenOS runtime, events and explicit capabilities; they do not share hidden user config state.",
        "shared_bus": str(data_home / "sevenos/events.jsonl"),
        "bridge_inbox": str(bridge_profile_dir / "bridge-inbox.jsonl"),
        "bridge_outbox": str(bridge_profile_dir / "bridge-outbox.jsonl"),
        "objects": str(objects_dir),
    },
}
config.mkdir(parents=True, exist_ok=True)
wallpaper_profile_dir.mkdir(parents=True, exist_ok=True)
bridge_profile_dir.mkdir(parents=True, exist_ok=True)
objects_dir.mkdir(parents=True, exist_ok=True)

def write_json_if_missing(path, data):
    path = Path(path)
    if not path.exists() or path.stat().st_size == 0:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

write_json_if_missing(config / "session.json", {
    "schema": "sevenos.profile-session.v1",
    "profile": key,
    "title": title,
    "workspace": workspace,
    "restore_policy": experience["session_policy"],
    "recent_apps": [],
    "recent_paths": [],
    "recent_objects": [],
    "pinned_objects": [],
    "tasks": [],
    "mood": experience["pace"],
    "last_active_workspace": "",
    "updated_at": None,
})
write_json_if_missing(config / "passage.json", {
    "schema": "sevenos.profile-passage.v1",
    "profile": key,
    "title": title,
    **passage,
})
write_json_if_missing(config / "profile-ui.json", {
    "schema": "sevenos.profile-ui.v1",
    "profile": key,
    "title": title,
    "role": role,
    "principle": principle,
    "accent_color": accent_color,
    "secondary_color": secondary_color,
    "ui_mood": ui_mood,
    "home": experience["home"],
    "metaphor": experience["metaphor"],
    "density": experience["density"],
    "projection": "profile source of truth; global files are active projections",
})
for name in ("bridge-inbox.jsonl", "bridge-outbox.jsonl"):
    path = bridge_profile_dir / name
    path.touch(exist_ok=True)
wallpaper_state = config / "wallpaper-state"
if not wallpaper_state.exists() or wallpaper_state.stat().st_size == 0:
    wallpaper_state.write_text(
        "\n".join([
            f"profile\t{key}",
            "mode\tprofile-default",
            f"value\t{key}",
            f"custom\t{wallpaper_profile_dir / 'wallpaper-custom.png'}",
            f"active\t{data_home / 'sevenos/wallpapers/wallpaper-sevenos-active.png'}",
            f"profile_active\t{wallpaper_profile_dir / 'wallpaper-active.png'}",
            "",
        ]),
        encoding="utf-8",
    )
print(json.dumps(payload, indent=2, ensure_ascii=False))
PY
  if [[ ! -s "$config_dir/theme.conf" ]]; then
    cat > "$config_dir/theme.conf" <<EOF
mode=system
profile=$key
EOF
  fi
}

profile_experience_json() {
  local key
  key="$(normalize_profile_key "${1:-$(active_profile)}")"
  write_profile_experience "$key"
  cat "$(profile_experience_path "$key")"
}

profile_experience_human() {
  local key
  key="$(normalize_profile_key "${1:-$(active_profile)}")"
  write_profile_experience "$key"
  python - "$(profile_experience_path "$key")" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
theme = data.get("theme", {})
wallpaper = data.get("wallpaper", {})
print(f"{data.get('title')} experience")
print("=" * (len(str(data.get('title'))) + 11))
print(f"profile:    {data.get('profile')}")
print(f"config:     {data.get('config_dir')}")
print(f"workspace:  {data.get('workspace')}")
print(f"theme:      {theme.get('mode_file')}")
print(f"wallpaper:  {wallpaper.get('state')}")
print(f"custom png: {wallpaper.get('custom')}")
print(f"principle:  {data.get('principle')}")
PY
}

bootstrap_profile() {
  local key
  key="$(normalize_profile_key "$1")"
  profile_target "$key" >/dev/null

  log_info "Bootstrapping SevenOS profile workspace: $(profile_title "$key")"
  write_workspace_readme "$key"

  if ! is_dry_run; then
    write_profile_experience "$key"
    sync_profile_language "$key"
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

run_profile_background() {
  local logfile="$1"
  shift
  mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
  if ! { touch "$logfile" 2>/dev/null && [[ -w "$logfile" ]]; }; then
    logfile="${TMPDIR:-/tmp}/sevenos-profile-$(basename "$logfile")"
  fi
  printf '[%s] %s\n' "$(date -Is)" "$*" >>"$logfile" 2>/dev/null || true
  if command -v setsid >/dev/null 2>&1; then
    setsid -f "$@" >>"$logfile" 2>&1 </dev/null
  else
    nohup "$@" >>"$logfile" 2>&1 </dev/null &
  fi
}

profile_post_activate_refresh() {
  local key="$1"
  local previous_key="${2:-}"
  local logfile="$STATE_DIR/profile-activate-$key.log"
  run_profile_background "$logfile" bash -lc '
    set +e
    key="$1"
    previous_key="$2"
    root="$3"
    state_dir="$4"
    export SEVENOS_ROOT="$root"
    is_current_profile() {
      [[ -r "$state_dir/profile.env" ]] || return 1
      # shellcheck disable=SC1090
      source "$state_dir/profile.env" 2>/dev/null || return 1
      [[ "${SEVENOS_ACTIVE_PROFILE:-}" == "$key" ]]
    }
    is_current_profile || exit 0
    "$root/scripts/runtime-orchestrator.sh" activate "$key" --apply --yes >/dev/null 2>&1 || true
    is_current_profile || exit 0
    "$root/scripts/profile-isolation.sh" apply "$key" --yes >/dev/null 2>&1 || true
    is_current_profile || exit 0
    "$root/scripts/mini-os-bridge.sh" status --json >/dev/null 2>&1 || true
    is_current_profile || exit 0
    "$root/scripts/hypr-lua.sh" apply "$key" >/dev/null 2>&1 || true
    is_current_profile || exit 0
    if [[ -x "$root/scripts/motion.sh" ]]; then
      "$root/scripts/motion.sh" profile "$key" >/dev/null 2>&1 || true
    fi
    is_current_profile || exit 0
    SEVENOS_WALLPAPER_PROFILE="$key" "$root/bin/seven-wallpaper" refresh >/dev/null 2>&1 || true
    is_current_profile || exit 0
    "$root/scripts/events.sh" log \
      --source profile \
      --type profile \
      --state OK \
      --message "Active profile changed to $key" \
      --command "seven profile activate $key" >/dev/null 2>&1 || true
    is_current_profile || exit 0
    "$root/profiles/profile-manager.sh" write-current-json "$key" >/dev/null 2>&1 || true
    is_current_profile || exit 0
    if [[ "${SEVENOS_PROFILE_RESTART_WAYBAR:-0}" == "1" ]]; then
      "$root/bin/seven-profile-theme" apply >/dev/null 2>&1 || true
      is_current_profile || exit 0
      "$root/bin/seven-waybar" restart >/dev/null 2>&1 || true
    else
      pkill -RTMIN+8 -x waybar >/dev/null 2>&1 || true
    fi
  ' _ "$key" "$previous_key" "$ROOT_DIR" "$STATE_DIR"
}

signal_waybar_profile_refresh() {
  if command -v pkill >/dev/null 2>&1; then
    pkill -RTMIN+8 -x waybar >/dev/null 2>&1 || true
  fi
}

snapshot_profile_session() {
  local key="$1"
  [[ -n "$key" ]] || return 0
  PROFILE_KEY="$key" STATE_DIR="$STATE_DIR" python - <<'PY'
import json
import os
import subprocess
import time
from pathlib import Path

profile = os.environ.get("PROFILE_KEY", "equinox")
state_dir = Path(os.environ["STATE_DIR"])
session_path = state_dir / "profiles" / profile / "session.json"
try:
    clients = json.loads(subprocess.run(["hyprctl", "clients", "-j"], text=True, capture_output=True, check=False, timeout=1.0).stdout or "[]")
except Exception:
    clients = []
windows = []
for item in clients if isinstance(clients, list) else []:
    klass = str(item.get("class") or item.get("initialClass") or "")
    title = str(item.get("title") or "")
    if not klass and not title:
        continue
    workspace = item.get("workspace") if isinstance(item.get("workspace"), dict) else {}
    windows.append({
        "class": klass,
        "title": title,
        "workspace": workspace.get("name") or workspace.get("id") or "",
        "address": item.get("address", ""),
        "floating": bool(item.get("floating", False)),
    })
session_path.parent.mkdir(parents=True, exist_ok=True)
try:
    session = json.loads(session_path.read_text(encoding="utf-8") or "{}")
except Exception:
    session = {}
session.setdefault("schema", "sevenos.profile-session.v1")
session["profile"] = profile
session["last_windows"] = windows[:40]
session["last_window_count"] = len(windows)
session["updated_at"] = int(time.time())
session_path.write_text(json.dumps(session, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
}

activate_profile() {
  local key
  local tmp_env tmp_json previous_key should_leave_windows should_enter_windows
  key="$(normalize_profile_key "$1")"
  profile_target "$key" >/dev/null
  previous_key="$(active_profile 2>/dev/null || printf 'equinox')"
  should_leave_windows=0
  should_enter_windows=0
  if [[ "$previous_key" == "windows" && "$key" != "windows" && "${SEVENOS_WINDOWS_AUTO_LEAVE:-1}" != "0" ]]; then
    should_leave_windows=1
  fi
  if [[ "$key" == "windows" && "${SEVENOS_WINDOWS_AUTO_ENTER:-0}" == "1" ]]; then
    should_enter_windows=1
  fi

  if [[ "$previous_key" == "$key" && "${SEVENOS_PROFILE_FORCE:-0}" != "1" ]]; then
    log_success "Active profile: $(profile_title "$key")"
    log_info "Workspace: $(profile_workspace "$key")"
    return 0
  fi

  log_info "Activating SevenOS profile: $(profile_title "$key")"
  run_profile_background "$STATE_DIR/profile-session-$previous_key.log" bash -lc '
    export SEVENOS_ROOT="$1"
    "$1/profiles/profile-manager.sh" snapshot-session "$2" >/dev/null 2>&1 || true
  ' _ "$ROOT_DIR" "$previous_key"

  if is_dry_run; then
    write_workspace_readme "$key"
    printf 'mkdir -p %q\n' "$STATE_DIR"
    printf 'lock %q\n' "$LOCK_FILE"
    if [[ "$previous_key" != "$key" ]]; then
      printf 'seven-passage-overlay --from %q --to %q --duration 950\n' "$previous_key" "$key"
    fi
    printf 'seven profile migrate-aliases --apply\n'
    printf 'write %q\n' "$STATE_FILE"
    write_profile_json "$key"
    printf 'seven runtime activate %q --apply --yes\n' "$key"
    printf 'seven hypr lua apply %q\n' "$key"
    printf 'seven motion profile %q\n' "$key"
    if [[ "$previous_key" == "windows" && "$key" != "windows" && "${SEVENOS_WINDOWS_AUTO_LEAVE:-1}" != "0" ]]; then
      printf 'seven windows leave\n'
    fi
    if [[ "$key" == "windows" && "${SEVENOS_WINDOWS_AUTO_ENTER:-0}" == "1" ]]; then
      printf 'seven windows enter\n'
      printf 'sleep 5; seven windows sync\n'
    fi
    return 0
  fi

  mkdir -p "$STATE_DIR" "$STATE_DIR/profiles/$key"
  mkdir -p "$(profile_workspace "$key")"
  run_profile_background "$STATE_DIR/profile-workspace-$key.log" \
    "$ROOT_DIR/profiles/profile-manager.sh" prepare-workspace "$key"
  write_profile_experience "$key"
  exec 9>"$LOCK_FILE"
  if ! flock -w 45 9; then
    log_error "Another SevenOS profile change is already running."
    return 1
  fi

  run_profile_background "$STATE_DIR/profile-migration.log" \
    "$ROOT_DIR/profiles/profile-manager.sh" migrate-aliases --apply

  if [[ "$previous_key" != "$key" && "${SEVENOS_PASSAGE_OVERLAY:-1}" != "0" ]]; then
    if command -v seven-passage-overlay >/dev/null 2>&1; then
      run_profile_background "$STATE_DIR/profile-passage.log" seven-passage-overlay --from "$previous_key" --to "$key" --duration "${SEVENOS_PASSAGE_DURATION:-520}"
    elif [[ -x "$ROOT_DIR/bin/seven-passage-overlay" ]]; then
      run_profile_background "$STATE_DIR/profile-passage.log" "$ROOT_DIR/bin/seven-passage-overlay" --from "$previous_key" --to "$key" --duration "${SEVENOS_PASSAGE_DURATION:-520}"
    fi
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
SEVENOS_PROFILE_CONFIG="$STATE_DIR/profiles/$key"
SEVENOS_TERMINAL_MODE="$(profile_terminal_mode "$key")"
EOF
  write_active_profile_json_fast "$key" > "$tmp_json"
  mv -f "$tmp_env" "$STATE_FILE"
  mv -f "$tmp_json" "$STATE_JSON"
  signal_waybar_profile_refresh

  log_success "Active profile: $(profile_title "$key")"
  log_info "Workspace: $(profile_workspace "$key")"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "SevenOS Profile" -h string:x-canonical-private-synchronous:sevenos-profile -t 1200 "$(profile_waybar_icon "$key")  $(profile_title "$key")" "$(profile_ui_mood "$key")" >/dev/null 2>&1 || true
  fi

  if [[ "$should_leave_windows" == "1" ]]; then
    mkdir -p "$STATE_DIR"
    if command -v notify-send >/dev/null 2>&1; then
      notify-send -a "SevenOS Profile" -h string:x-canonical-private-synchronous:sevenos-windows-leave -t 1400 "󰖳  Windows" "Windows est rangé pour libérer les ressources." >/dev/null 2>&1 || true
    fi
    run_profile_background "$STATE_DIR/windows-enter.log" \
      env SEVENOS_ROOT="$ROOT_DIR" SEVENOS_WINDOWS_AUTO_STOPPED_BY_PROFILE=1 \
      SEVENOS_WINDOWS_LEAVE_MODE="${SEVENOS_WINDOWS_AUTO_LEAVE_MODE:-managedsave}" \
      "$ROOT_DIR/bin/seven-windows-assistant" leave
  fi

  if [[ "$should_enter_windows" == "1" ]]; then
    local enter_cmd
    enter_cmd="$(profile_enter_command "$key" 2>/dev/null || true)"
    if [[ -n "$enter_cmd" ]]; then
      mkdir -p "$STATE_DIR"
      if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "SevenOS Profile" -h string:x-canonical-private-synchronous:sevenos-windows-enter -t 1400 "󰖳  Windows" "SevenOS ouvre Windows et prépare l’accès internet." >/dev/null 2>&1 || true
      fi
      run_profile_background "$STATE_DIR/windows-enter.log" \
        env SEVENOS_ROOT="$ROOT_DIR" SEVENOS_WINDOWS_AUTO_STARTED_BY_PROFILE=1 \
        SEVENOS_WINDOWS_CONSOLE="${SEVENOS_WINDOWS_AUTO_CONSOLE:-virt-manager}" \
        "$ROOT_DIR/bin/seven-windows-assistant" enter
      run_profile_background "$STATE_DIR/windows-enter.log" \
        env SEVENOS_ROOT="$ROOT_DIR" SEVENOS_WINDOWS_AUTO_STARTED_BY_PROFILE=1 \
        SEVENOS_WINDOWS_CONSOLE="${SEVENOS_WINDOWS_AUTO_CONSOLE:-virt-manager}" \
        bash -lc 'sleep 5; "$SEVENOS_ROOT/bin/seven-windows-assistant" sync'
    fi
  fi
  flock -u 9
  if [[ "${SEVENOS_PROFILE_SYNC_ACTIVATE:-0}" == "1" ]]; then
    "$ROOT_DIR/scripts/runtime-orchestrator.sh" activate "$key" --apply --yes >/dev/null 2>&1 || true
    "$ROOT_DIR/scripts/profile-isolation.sh" apply "$key" --yes >/dev/null 2>&1 || true
    "$ROOT_DIR/scripts/mini-os-bridge.sh" status --json >/dev/null 2>&1 || true
    "$ROOT_DIR/scripts/hypr-lua.sh" apply "$key" >/dev/null 2>&1 || true
    "$ROOT_DIR/bin/seven-profile-theme" apply >/dev/null 2>&1 || true
    "$ROOT_DIR/bin/seven-waybar" restart >/dev/null 2>&1 || true
  else
    profile_post_activate_refresh "$key" "$previous_key"
  fi
}

open_profile() {
  local key
  local workspace
  key="$(normalize_profile_key "${1:-$(active_profile)}")"
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
  local key
  local target
  key="$(normalize_profile_key "$1")"
  target="$(profile_target "$key")"

  log_info "Installing SevenOS profile: $(profile_title "$key")"
  if [[ "$key" == "forge" ]]; then
    "$ROOT_DIR/install.sh" dev "${@:2}"
    "$ROOT_DIR/install.sh" server "${@:2}"
  else
    "$ROOT_DIR/install.sh" "$target" "${@:2}"
  fi
  post_install_profile "$key"
  activate_profile "$key"
}

post_install_profile() {
  local key
  key="$(normalize_profile_key "$1")"

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
    equinox)
      log_info "Equinox global profile ready."
      ;;
    forge)
      log_info "Forge DevOps post-install check..."
      "$ROOT_DIR/server/seven-server.sh" install-user-service || true
      "$ROOT_DIR/server/seven-server.sh" status || true
      "$ROOT_DIR/server/seven-deploy.sh" status || true
      ;;
    studio)
      log_info "Studio workspace ready for creative applications."
      ;;
    pulse)
      log_info "Pulse Gaming mini OS ready."
      ;;
    baobab)
      log_info "Bootstrapping Baobab cultural mini OS..."
      "$ROOT_DIR/scripts/baobab.sh" bootstrap || true
      ;;
  esac
}

show_profile() {
  local key
  local counts installed total state
  key="$(normalize_profile_key "$1")"
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
  PROFILE_STATUS_PAYLOAD="$(status_json)" \
  PROFILE_MIGRATION_PAYLOAD="$(profile_migration_json 0)" \
  python - <<'PY'
import json
import os

profiles = json.loads(os.environ["PROFILE_STATUS_PAYLOAD"])
migration = json.loads(os.environ["PROFILE_MIGRATION_PAYLOAD"])
summary = {
    "total": len(profiles),
    "active": sum(1 for item in profiles if item.get("runtime", {}).get("lifecycle") == "ACTIVE"),
    "capability": sum(1 for item in profiles if item.get("runtime", {}).get("lifecycle") == "CAPABILITY"),
    "quiet": sum(1 for item in profiles if item.get("runtime", {}).get("lifecycle") == "SUSPENDED"),
    "ready": sum(1 for item in profiles if item.get("state") == "OK" and item.get("bootstrap_state") == "OK"),
    "needs_install": sum(1 for item in profiles if item.get("state") != "OK"),
    "needs_bootstrap": sum(1 for item in profiles if item.get("bootstrap_state") != "OK"),
    "isolation_ready": all(item.get("runtime", {}).get("isolation_ready") for item in profiles),
    "alias_migration_pending": migration.get("pending", 0),
    "equinox_system_ready": any(
        item.get("key") == "equinox" and item.get("runtime", {}).get("system_contract")
        for item in profiles
    ),
}
issues = []
if migration.get("pending", 0):
    issues.append({
        "profile": "forge",
        "severity": "medium",
        "kind": "alias-migration",
        "detail": f"{migration.get('pending')} local state files still reference retired profile aliases",
        "command": "seven profile migrate-aliases --apply",
    })
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
    if item.get("key") == "equinox" and runtime.get("isolation_ready") and not runtime.get("system_contract"):
        issues.append({
            "profile": "equinox",
            "severity": "high",
            "kind": "system-contract",
            "detail": "Equinox must be host-system/admin, not a strict mini OS container",
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
print(f"equinox:  {'host-system' if summary.get('equinox_system_ready') else 'needs system apply'}")
print()
for item in data.get("profiles", []):
    runtime = item.get("runtime", {})
    print(f"{item.get('key'):<9} pkg={item.get('state'):<4} boot={item.get('bootstrap_state'):<4} runtime={runtime.get('lifecycle'):<10} contract={runtime.get('runtime_contract'):<17} quiet-packages={runtime.get('inactive_owned_packages', 0)}")
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
  seven profile experience [profile] [--json]
  seven profile gaps [--json]
  seven profile plan [--json] [--limit N]
  seven profile health [--json]
  seven profile aliases [--json]
  seven profile migrate-aliases [--apply] [--json]
  seven profile catalog [--json]
  seven profile isolation [status|plan|apply|doctor] [profile] [capability ...] [--json] [--yes]
  seven profile requirements [profile] [--apply --yes] [--optional]
  seven profile exec <profile> [--container|--rootfs|--independent] [--ephemeral] [--workspace PATH|--workspace-profile] <command> [args...]
  seven profile grant-folder [profile] <path> [--name NAME] [--rw|--ro] [--json]
  seven profile folders [profile] [--json]
  seven profile revoke-folder [profile] <name|path> [--json]
  seven profile open-folder [profile] <path>
  seven profile bootstrap <profile|all>
  seven profile activate <profile>
  seven profile install <profile>
  seven profile open [profile]

Profiles:
  equinox  Equinox Balance: balanced general mini OS
  baobab   Baobab Cultural OS: African heritage, learning, creation and offline memory
  forge    Forge DevOps: developer, containers and deployment mini OS
  shield   Shield Cybersecurity: cybersecurity mini OS
  studio   Studio Creator: creator mini OS
  windows  Windows: applications Windows, dossiers et Windows complet
  pulse    Pulse Gaming: Linux gaming mini OS
EOF
}

command="${1:-status}"
shift || true

profile_folder_grants() {
  local action="$1"
  shift || true
  PROFILE_ACTION="$action" ACTIVE_PROFILE="$(active_profile)" STATE_DIR="$STATE_DIR" python - "$@" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

profiles = {"equinox", "baobab", "forge", "shield", "studio", "windows", "pulse"}
action = os.environ.get("PROFILE_ACTION", "folders")
active = os.environ.get("ACTIVE_PROFILE", "equinox")
state_dir = Path(os.environ.get("STATE_DIR", str(Path.home() / ".config/sevenos")))
state_path = state_dir / "profile-folder-grants.json"
args = list(sys.argv[1:])

def load():
    try:
        return json.loads(state_path.read_text(encoding="utf-8"))
    except Exception:
        return {"schema": "sevenos.profile-folder-grants.v1", "profiles": {}}

def save(data):
    state_dir.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

def safe_name(value):
    value = re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip()).strip(".-")
    return value[:48] or "folder"

def parse_profile_path(rest):
    if rest and rest[0] in profiles:
        return rest[0], rest[1:]
    return active, rest

def print_payload(payload, json_output):
    if json_output:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return
    profile = payload.get("profile", active)
    print(f"SevenOS external folders for {profile}")
    print("=" * 36)
    grants = payload.get("folders", [])
    if not grants:
        print("No external folder grant.")
    for item in grants:
        print(f"- {item.get('name')} [{item.get('mode')}]: {item.get('path')}")
        print(f"  container: /external/{item.get('name')}")

json_output = "--json" in args or "json" in args
args = [item for item in args if item not in {"--json", "json"}]
data = load()
data.setdefault("profiles", {})

if action in {"folders", "list-folders"}:
    profile, rest = parse_profile_path(args)
    folders = data.get("profiles", {}).get(profile, [])
    print_payload({"schema": data.get("schema"), "profile": profile, "folders": folders}, json_output)
    raise SystemExit(0)

if action in {"grant-folder", "allow-folder"}:
    profile, rest = parse_profile_path(args)
    mode = "ro"
    name = ""
    cleaned = []
    i = 0
    while i < len(rest):
        if rest[i] == "--rw":
            mode = "rw"; i += 1; continue
        if rest[i] == "--ro":
            mode = "ro"; i += 1; continue
        if rest[i] == "--name" and i + 1 < len(rest):
            name = rest[i + 1]; i += 2; continue
        cleaned.append(rest[i]); i += 1
    if not cleaned:
        print("seven profile grant-folder needs a folder path", file=sys.stderr)
        raise SystemExit(2)
    path = Path(cleaned[0]).expanduser().resolve()
    if not path.is_dir():
        print(f"folder not found: {path}", file=sys.stderr)
        raise SystemExit(2)
    grant = {"name": safe_name(name or path.name), "path": str(path), "mode": mode}
    folders = data["profiles"].setdefault(profile, [])
    folders[:] = [item for item in folders if item.get("path") != str(path) and item.get("name") != grant["name"]]
    folders.append(grant)
    save(data)
    print_payload({"schema": data.get("schema"), "profile": profile, "folders": folders, "added": grant}, json_output)
    raise SystemExit(0)

if action == "revoke-folder":
    profile, rest = parse_profile_path(args)
    if not rest:
        print("seven profile revoke-folder needs a folder name or path", file=sys.stderr)
        raise SystemExit(2)
    target = rest[0]
    try:
        target_path = str(Path(target).expanduser().resolve())
    except Exception:
        target_path = target
    folders = data["profiles"].setdefault(profile, [])
    before = len(folders)
    folders[:] = [item for item in folders if item.get("name") != target and item.get("path") != target_path]
    save(data)
    print_payload({"schema": data.get("schema"), "profile": profile, "folders": folders, "removed": before - len(folders)}, json_output)
    raise SystemExit(0)

print(f"unknown folder grant action: {action}", file=sys.stderr)
raise SystemExit(2)
PY
}

case "$command" in
  list|status)
    if [[ "${1:-}" == "--json" ]]; then
      status_json
    else
      status_human
    fi
    ;;
  aliases)
    if [[ "${1:-}" == "--json" ]]; then
      profile_aliases_json
    else
      profile_aliases_human
    fi
    ;;
  migrate-aliases)
    apply=0
    json_output=0
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --apply|--yes) apply=1 ;;
        --json|json) json_output=1 ;;
        *) log_error "Unknown migrate-aliases option: $1"; usage; exit 1 ;;
      esac
      shift
    done
    if [[ "$json_output" -eq 1 ]]; then
      profile_migration_json "$apply"
    else
      profile_migration_human "$apply"
    fi
    ;;
  show)
    [[ -n "${1:-}" ]] || { usage; exit 1; }
    show_profile "$1"
    ;;
  current)
    key="$(active_profile)"
    if [[ "${1:-}" == "--json" ]]; then
      if [[ "${SEVENOS_PROFILE_FULL_JSON:-0}" != "1" && -s "$STATE_JSON" ]]; then
        cat "$STATE_JSON"
        printf '\n'
      else
        profile_json_object "$key"
        printf '\n'
      fi
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
  exec)
    key="${1:-}"
    [[ -n "$key" ]] || { usage; exit 1; }
    shift || true
    "$ROOT_DIR/bin/seven-profile-run" --profile "$key" "$@"
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
  experience)
    key="${1:-$(active_profile)}"
    if [[ "${2:-}" == "--json" || "${1:-}" == "--json" ]]; then
      [[ "${1:-}" == "--json" ]] && key="$(active_profile)"
      profile_experience_json "$key"
      printf '\n'
    else
      profile_experience_human "$key"
    fi
    ;;
  gaps)
    if [[ "${1:-}" == "--json" ]]; then
      gaps_json
    else
      gaps_human
    fi
    ;;
  requirements|deps|ensure)
    target="${1:-$(active_profile)}"
    shift || true
    req_action="status"
    for arg in "$@"; do
      case "$arg" in
        --apply) req_action="ensure" ;;
      esac
    done
    "$ROOT_DIR/bin/seven-profile-requirements" "$req_action" "$target" "$@"
    ;;
  grant-folder|allow-folder)
    profile_folder_grants grant-folder "$@"
    ;;
  folders|external-folders)
    profile_folder_grants folders "$@"
    ;;
  revoke-folder)
    profile_folder_grants revoke-folder "$@"
    ;;
  open-folder|access-folder)
    target_profile="$(active_profile)"
    if [[ -n "${1:-}" && "$1" =~ ^(equinox|baobab|forge|shield|studio|windows|pulse)$ ]]; then
      target_profile="$1"
      shift
    fi
    folder="${1:-}"
    [[ -n "$folder" ]] || { log_error "seven profile open-folder needs a folder path"; exit 2; }
    if [[ "$target_profile" == "equinox" ]]; then
      "$ROOT_DIR/bin/seven-files" open "$folder"
      exit $?
    fi
    profile_folder_grants grant-folder "$target_profile" "$folder" --rw >/dev/null
    "$ROOT_DIR/bin/seven-profile-run" --profile "$target_profile" --container --workspace "$folder" seven-files open /workspace
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
  snapshot-session)
    [[ -n "${1:-}" ]] || { usage; exit 1; }
    snapshot_profile_session "$(normalize_profile_key "$1")"
    ;;
  prepare-workspace)
    [[ -n "${1:-}" ]] || { usage; exit 1; }
    write_workspace_readme "$(normalize_profile_key "$1")"
    ;;
  write-current-json)
    [[ -n "${1:-}" ]] || { usage; exit 1; }
    write_profile_json "$(normalize_profile_key "$1")"
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
