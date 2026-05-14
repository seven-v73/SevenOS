#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
STATE_FILE="$STATE_DIR/profile.env"
STATE_JSON="$STATE_DIR/profile.json"

json_escape() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

profile_title() {
  case "$1" in
    forge) printf 'Forge' ;;
    shield) printf 'Shield' ;;
    studio) printf 'Studio' ;;
    windows) printf 'Windows' ;;
    horizon) printf 'Horizon' ;;
    baobab) printf 'Baobab' ;;
    *) printf '%s' "$1" ;;
  esac
}

profile_description() {
  case "$1" in
    forge) printf 'Development workspace for code, containers, databases and deployment.' ;;
    shield) printf 'Cybersecurity workspace with audit, sandbox, forensics, reversing and network tools.' ;;
    studio) printf 'Creative workspace for image, vector, video, audio and 3D production.' ;;
    windows) printf 'Compatibility workspace for Wine, Bottles, Lutris and KVM Windows Mode.' ;;
    horizon) printf 'Server and deployment workspace for containers, reverse proxy and self-hosting.' ;;
    baobab) printf 'SevenOS base desktop, shell, theme and system foundation.' ;;
    *) printf 'SevenOS workspace.' ;;
  esac
}

profile_package_files() {
  case "$1" in
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
    baobab) printf '%s\n' "$ROOT_DIR/scripts/packages-base.txt" ;;
    *) return 1 ;;
  esac
}

profile_target() {
  case "$1" in
    forge) printf 'dev' ;;
    shield) printf 'cybersecurity' ;;
    studio) printf 'creation' ;;
    windows) printf 'windows' ;;
    horizon) printf 'server' ;;
    baobab) printf 'base' ;;
    *) return 1 ;;
  esac
}

profile_workspace() {
  case "$1" in
    forge) printf '%s/Forge' "$HOME" ;;
    shield) printf '%s/ShieldLab' "$HOME" ;;
    studio) printf '%s/Studio' "$HOME" ;;
    windows) printf '%s/WindowsMode' "$HOME" ;;
    horizon) printf '%s/HorizonDeploy' "$HOME" ;;
    baobab) printf '%s/SevenOS' "$HOME" ;;
    *) return 1 ;;
  esac
}

profile_accent() {
  case "$1" in
    forge) printf 'indigo' ;;
    shield) printf 'clay' ;;
    studio) printf 'gold' ;;
    windows) printf 'baobab' ;;
    horizon) printf 'baobab' ;;
    baobab) printf 'gold' ;;
    *) printf 'gold' ;;
  esac
}

profile_apps() {
  case "$1" in
    forge) printf '%s\n' "kitty" "code" "helix" "docker" ;;
    shield) printf '%s\n' "kitty" "wireshark" "burpsuite" "zaproxy" ;;
    studio) printf '%s\n' "gimp" "krita" "inkscape" "blender" "kdenlive" ;;
    windows) printf '%s\n' "bottles" "lutris" "virt-manager" ;;
    horizon) printf '%s\n' "kitty" "podman" "caddy" ;;
    baobab) printf '%s\n' "seven hub" "seven files" ;;
    *) return 1 ;;
  esac
}

profile_workspace_dirs() {
  case "$1" in
    forge) printf '%s\n' "Projects" "Sandboxes" "Containers" "Notes" ;;
    shield) printf '%s\n' "Labs" "Reports" "Captures" "Wordlists" "Evidence" ;;
    studio) printf '%s\n' "Images" "Video" "Audio" "3D" "Exports" "References" ;;
    windows) printf '%s\n' "Bottles" "VMs" "Installers" "Shared" ;;
    horizon) printf '%s\n' "Projects" "Deployments" "Services" "Logs" ;;
    baobab) printf '%s\n' "Notes" "Backups" ;;
    *) return 1 ;;
  esac
}

profile_keys() {
  printf '%s\n' baobab forge shield studio windows horizon
}

active_profile() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
    printf '%s' "${SEVENOS_ACTIVE_PROFILE:-baobab}"
  else
    printf 'baobab'
  fi
}

package_installed() {
  pacman -Q "$1" >/dev/null 2>&1
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
    return 0
  fi

  mkdir -p "$workspace"
  while IFS= read -r dir; do
    mkdir -p "$workspace/$dir"
  done < <(profile_workspace_dirs "$key")
  cat > "$workspace/README.md" <<EOF
# SevenOS $(profile_title "$key")

$(profile_description "$key")

Useful commands:

- seven profile status
- seven profile show $key
- seven profile activate $key
- seven profile install $key
- seven profile open $key
EOF
}

write_profile_json() {
  local key="$1"
  if is_dry_run; then
    printf 'write %q\n' "$STATE_JSON"
    return 0
  fi

  python - "$key" "$(profile_title "$key")" "$(profile_description "$key")" "$(profile_workspace "$key")" "$(profile_accent "$key")" "$(profile_apps "$key" | paste -sd ',')" <<'PY' > "$STATE_JSON"
import json
import sys

key, title, description, workspace, accent, apps = sys.argv[1:]
payload = {
    "key": key,
    "title": title,
    "description": description,
    "workspace": workspace,
    "accent": accent,
    "apps": [item for item in apps.split(",") if item],
}
print(json.dumps(payload, indent=2))
PY
}

activate_profile() {
  local key="$1"
  profile_target "$key" >/dev/null

  log_info "Activating SevenOS profile: $(profile_title "$key")"
  write_workspace_readme "$key"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$STATE_DIR"
    printf 'write %q\n' "$STATE_FILE"
    write_profile_json "$key"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  cat > "$STATE_FILE" <<EOF
SEVENOS_ACTIVE_PROFILE="$key"
SEVENOS_PROFILE_TITLE="$(profile_title "$key")"
SEVENOS_PROFILE_ACCENT="$(profile_accent "$key")"
SEVENOS_PROFILE_WORKSPACE="$(profile_workspace "$key")"
EOF
  write_profile_json "$key"

  log_success "Active profile: $(profile_title "$key")"
  log_info "Workspace: $(profile_workspace "$key")"
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
  activate_profile "$key"
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
  printf 'State:       %s %s/%s packages\n' "$state" "$installed" "$total"
  printf 'Active:      %s\n' "$([[ "$(active_profile)" == "$key" ]] && printf yes || printf no)"
  printf 'Workspace:   %s\n' "$(profile_workspace "$key")"
  printf 'Accent:      %s\n' "$(profile_accent "$key")"
  printf 'Description: %s\n' "$(profile_description "$key")"
  printf '\nPackage manifests:\n'
  profile_package_files "$key" | sed "s#^$ROOT_DIR/##; s#^#- #"
}

status_json() {
  local first=1
  local active
  active="$(active_profile)"
  printf '['
  while IFS= read -r key; do
    local counts installed total state workspace active_bool
    counts="$(profile_counts "$key")"
    installed="${counts%% *}"
    total="${counts##* }"
    state="$(profile_state "$installed" "$total")"
    workspace="$(profile_workspace "$key")"
    active_bool=false
    [[ "$active" == "$key" ]] && active_bool=true

    [[ "$first" -eq 1 ]] || printf ','
    first=0
    printf '{'
    printf '"key":%s,' "$(printf '%s' "$key" | json_escape)"
    printf '"title":%s,' "$(profile_title "$key" | json_escape)"
    printf '"description":%s,' "$(profile_description "$key" | json_escape)"
    printf '"state":%s,' "$(printf '%s' "$state" | json_escape)"
    printf '"installed":%s,' "$installed"
    printf '"total":%s,' "$total"
    printf '"active":%s,' "$active_bool"
    printf '"workspace":%s,' "$(printf '%s' "$workspace" | json_escape)"
    printf '"accent":%s,' "$(profile_accent "$key" | json_escape)"
    printf '"apps":['
    local app_first=1 app
    while IFS= read -r app; do
      [[ "$app_first" -eq 1 ]] || printf ','
      app_first=0
      printf '%s' "$(printf '%s' "$app" | json_escape)"
    done < <(profile_apps "$key")
    printf '],'
    printf '"action":%s' "$(printf 'seven profile install %s' "$key" | json_escape)"
    printf '}'
  done < <(profile_keys)
  printf ']\n'
}

status_human() {
  local active
  active="$(active_profile)"
  printf 'SevenOS profiles\n\n'
  while IFS= read -r key; do
    local counts installed total state marker
    counts="$(profile_counts "$key")"
    installed="${counts%% *}"
    total="${counts##* }"
    state="$(profile_state "$installed" "$total")"
    marker=' '
    [[ "$active" == "$key" ]] && marker='*'
    printf '%s %-8s %-4s %2s/%-2s %s\n' "$marker" "$key" "$state" "$installed" "$total" "$(profile_description "$key")"
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
  seven profile activate <profile>
  seven profile install <profile>
  seven profile open [profile]

Profiles:
  baobab   Base desktop and system foundation
  forge    Development
  shield   Cybersecurity
  studio   Creation
  windows  Windows compatibility
  horizon  Server and deployment
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
  activate)
    [[ -n "${1:-}" ]] || { usage; exit 1; }
    activate_profile "$1"
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
