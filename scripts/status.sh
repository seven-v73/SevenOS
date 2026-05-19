#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

JSON_OUTPUT=0

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    -h|--help|help)
      cat <<'EOF'
SevenOS status

Usage:
  seven status [--json]
  ./scripts/status.sh [--json]
EOF
      exit 0
      ;;
    *) log_error "Unknown status option: $arg"; exit 1 ;;
  esac
done

ok() {
  printf '[OK] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

missing() {
  printf '[MISS] %s\n' "$*"
}

section() {
  printf '\n== %s ==\n' "$*"
}

package_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

json_escape() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

flatpak_installed() {
  command -v flatpak >/dev/null 2>&1 && flatpak info "$1" >/dev/null 2>&1
}

service_active() {
  systemctl is-active --quiet "$1" >/dev/null 2>&1
}

service_enabled() {
  systemctl is-enabled --quiet "$1" >/dev/null 2>&1
}

group_member() {
  local group="$1"
  groups "$USER" | grep -qw "$group"
}

profile_status() {
  local name="$1"
  local package_file="$2"
  local installed=0
  local total=0
  local package

  while IFS= read -r package; do
    package="${package%%#*}"
    package="${package//[[:space:]]/}"
    [[ -z "$package" ]] && continue

    total=$((total + 1))
    if package_installed "$package"; then
      installed=$((installed + 1))
    fi
  done < "$package_file"

  if [[ "$total" -eq 0 ]]; then
    warn "$name: no packages declared"
  elif [[ "$installed" -eq "$total" ]]; then
    ok "$name: installed ($installed/$total packages)"
  elif [[ "$installed" -gt 0 ]]; then
    warn "$name: partial ($installed/$total packages)"
  else
    missing "$name: not installed (0/$total packages)"
  fi
}

service_status() {
  local service="$1"

  if service_active "$service"; then
    ok "$service: active"
  elif service_enabled "$service"; then
    warn "$service: enabled but not active"
  else
    missing "$service: inactive"
  fi
}

ufw_status_line() {
  local service_state command_output degraded_marker
  degraded_marker="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/security/ufw-degraded"

  if ! command -v ufw >/dev/null 2>&1; then
    printf 'MISS\tUFW command missing'
    return 0
  fi

  if [[ -s "$degraded_marker" ]]; then
    printf 'PART\tUFW degraded marker present'
    return 0
  fi

  if service_active ufw.service; then
    service_state="service active"
  elif service_enabled ufw.service; then
    service_state="service enabled"
  else
    service_state="service inactive"
  fi

  command_output="$(sudo -n ufw status 2>/dev/null | head -n 1 || true)"
  if [[ "$command_output" == *"active"* ]]; then
    printf 'OK\t%s' "$command_output"
  elif [[ -n "$command_output" ]]; then
    printf 'PART\t%s (%s)' "$command_output" "$service_state"
  elif service_active ufw.service; then
    printf 'OK\t%s; detailed status requires sudo' "$service_state"
  else
    printf 'PART\t%s; detailed status requires sudo' "$service_state"
  fi
}

package_status() {
  local package="$1"
  local label="${2:-$1}"

  if package_installed "$package"; then
    ok "$label"
  else
    missing "$label"
  fi
}

profile_json() {
  local key="$1"
  local name="$2"
  local package_file="$3"
  local installed=0
  local total=0
  local package state

  while IFS= read -r package; do
    package="${package%%#*}"
    package="${package//[[:space:]]/}"
    [[ -z "$package" ]] && continue
    total=$((total + 1))
    package_installed "$package" && installed=$((installed + 1))
  done < "$package_file"

  if [[ "$total" -eq 0 ]]; then
    state="MISS"
  elif [[ "$installed" -eq "$total" ]]; then
    state="OK"
  elif [[ "$installed" -gt 0 ]]; then
    state="PART"
  else
    state="MISS"
  fi

  printf '{"key":%s,"name":%s,"state":%s,"installed":%s,"total":%s}' \
    "$(printf '%s' "$key" | json_escape)" \
    "$(printf '%s' "$name" | json_escape)" \
    "$(printf '%s' "$state" | json_escape)" \
    "$installed" \
    "$total"
}

service_json() {
  local key="$1"
  local service="$2"
  local state

  if service_active "$service"; then
    state="OK"
  elif service_enabled "$service"; then
    state="PART"
  else
    state="MISS"
  fi

  printf '{"key":%s,"service":%s,"state":%s}' \
    "$(printf '%s' "$key" | json_escape)" \
    "$(printf '%s' "$service" | json_escape)" \
    "$(printf '%s' "$state" | json_escape)"
}

command_json() {
  local key="$1"
  local command_name="$2"
  local state="MISS"
  command -v "$command_name" >/dev/null 2>&1 && state="OK"
  printf '{"key":%s,"command":%s,"state":%s}' \
    "$(printf '%s' "$key" | json_escape)" \
    "$(printf '%s' "$command_name" | json_escape)" \
    "$(printf '%s' "$state" | json_escape)"
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '{'
  printf '"identity":{'
  if [[ -f /etc/sevenos-release ]]; then
    printf '"release":%s,' "$(head -n 1 /etc/sevenos-release | json_escape)"
  else
    printf '"release":null,'
  fi
  printf '"commands":['
  command_json seven seven
  printf ','
  command_json sevenpkg sevenpkg
  printf ','
  command_json seven_hub seven-hub
  printf ']},'

  printf '"profiles":['
  profile_json base "Base desktop" "$ROOT_DIR/scripts/packages-base.txt"
  printf ','
  profile_json forge "Forge" "$ROOT_DIR/scripts/packages-dev.txt"
  printf ','
  profile_json shield "Shield" "$ROOT_DIR/scripts/packages-cybersecurity.txt"
  printf ','
  profile_json studio "Studio" "$ROOT_DIR/scripts/packages-creation.txt"
  printf ','
  profile_json windows "Windows" "$ROOT_DIR/scripts/packages-windows.txt"
  printf ','
  profile_json security "Security" "$ROOT_DIR/scripts/packages-security.txt"
  printf '],'

  printf '"services":['
  service_json network NetworkManager.service
  printf ','
  service_json docker docker.service
  printf ','
  service_json libvirt libvirtd.service
  printf ','
  service_json firewall ufw.service
  printf '],'

  IFS=$'\t' read -r ufw_state ufw_detail < <(ufw_status_line) || true
  printf '"security":{'
  printf '"ufw":{"state":%s,"detail":%s}' \
    "$(printf '%s' "$ufw_state" | json_escape)" \
    "$(printf '%s' "$ufw_detail" | json_escape)"
  printf '},'

  printf '"desktop":{'
  printf '"current":%s,' "$(printf '%s' "${XDG_CURRENT_DESKTOP:-unknown}" | json_escape)"
  printf '"wayland":%s' "$(printf '%s' "${WAYLAND_DISPLAY:-missing}" | json_escape)"
  printf '}'
  printf '}\n'
  exit 0
fi

log_info "SevenOS system status"

section "Identity"
if [[ -f /etc/sevenos-release ]]; then
  ok "$(head -n 1 /etc/sevenos-release)"
else
  missing "/etc/sevenos-release"
fi
if command -v seven >/dev/null 2>&1; then
  ok "seven available"
else
  missing "seven command"
fi
if command -v sevenpkg >/dev/null 2>&1; then
  ok "sevenpkg available"
else
  missing "sevenpkg command"
fi
if command -v seven-country >/dev/null 2>&1; then
  ok "seven-country available"
else
  missing "seven-country command"
fi
if command -v sevenosctl >/dev/null 2>&1; then
  ok "sevenosctl legacy helper available"
fi

section "Profiles"
profile_status "Base desktop" "$ROOT_DIR/scripts/packages-base.txt"
profile_status "DEV" "$ROOT_DIR/scripts/packages-dev.txt"
profile_status "CYBERSECURITY" "$ROOT_DIR/scripts/packages-cybersecurity.txt"
profile_status "CYBER FORENSICS" "$ROOT_DIR/scripts/packages-cybersecurity-forensics.txt"
profile_status "CYBER REVERSING" "$ROOT_DIR/scripts/packages-cybersecurity-reversing.txt"
profile_status "CYBER WIRELESS" "$ROOT_DIR/scripts/packages-cybersecurity-wireless.txt"
profile_status "CYBER SANDBOX" "$ROOT_DIR/scripts/packages-cybersecurity-sandbox.txt"
profile_status "CREATION" "$ROOT_DIR/scripts/packages-creation.txt"
profile_status "WINDOWS" "$ROOT_DIR/scripts/packages-windows.txt"
profile_status "SECURITY" "$ROOT_DIR/scripts/packages-security.txt"

section "Services"
service_status "NetworkManager.service"
service_status "docker.service"
service_status "libvirtd.service"
service_status "ufw.service"

section "User Groups"
if group_member docker; then ok "$USER is in docker"; else missing "$USER is not in docker"; fi
if group_member libvirt; then ok "$USER is in libvirt"; else missing "$USER is not in libvirt"; fi
if group_member wireshark; then ok "$USER is in wireshark"; else missing "$USER is not in wireshark"; fi

section "Windows Compatibility"
package_status wine "Wine"
package_status lutris "Lutris"
package_status virt-manager "Virt Manager"
package_status qemu-full "QEMU"
if flatpak_installed com.usebottles.bottles; then
  ok "Bottles Flatpak"
else
  missing "Bottles Flatpak"
fi

section "Security"
IFS=$'\t' read -r ufw_state ufw_detail < <(ufw_status_line) || true
case "$ufw_state" in
  OK) ok "UFW: $ufw_detail" ;;
  PART) warn "UFW: $ufw_detail" ;;
  *) missing "UFW: $ufw_detail" ;;
esac
package_status firejail "Firejail"
package_status bubblewrap "Bubblewrap"
package_status keepassxc "KeePassXC"

section "Desktop"
if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
  ok "Desktop: $XDG_CURRENT_DESKTOP"
else
  warn "Desktop session unknown"
fi
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  ok "Wayland display: $WAYLAND_DISPLAY"
else
  warn "Wayland display not detected"
fi

log_success "Status report completed."
