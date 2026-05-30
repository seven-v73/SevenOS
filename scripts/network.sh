#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Network

Usage:
  seven network status [--json]
  seven network repair [--yes]
  ./scripts/network.sh bootstrap [--yes]

SevenOS uses NetworkManager as the default network backend. This script keeps
Wi-Fi usable on fresh installs by enabling the service, unblocking radios and
opening the SevenOS Wi-Fi connector.
EOF
}

JSON_OUTPUT=0
YES="${SEVENOS_YES:-0}"
ACTION="${1:-status}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
NETWORK_CACHE="$CACHE_DIR/network-status.json"
NETWORK_CACHE_TTL="${SEVENOS_NETWORK_CACHE_TTL:-30}"
REFRESH_CACHE="${SEVENOS_NETWORK_REFRESH:-0}"
shift || true

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    --refresh|--no-cache) REFRESH_CACHE=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown network option: $arg"; usage; exit 1 ;;
  esac
done

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

require_interactive_admin() {
  if is_dry_run || [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi
  if [[ -z "$(privileged_backend)" ]]; then
    log_error "Administrator permission is required, but no interactive password prompt is available."
    log_info "Open Seven Terminal and run:"
    log_info "  cd $ROOT_DIR"
    log_info "  ./install.sh network --yes"
    log_info "Then check with: seven network status"
    return 1
  fi
}

service_state() {
  local unit="$1"
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    printf RUN
  elif systemctl is-enabled --quiet "$unit" 2>/dev/null; then
    printf PART
  else
    printf MISS
  fi
}

wifi_device() {
  command -v nmcli >/dev/null 2>&1 || return 0
  nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }' || true
}

wifi_radio() {
  command -v nmcli >/dev/null 2>&1 || { printf missing; return 0; }
  nmcli radio wifi 2>/dev/null | tr -d '\n' || printf unknown
}

active_ssid() {
  command -v nmcli >/dev/null 2>&1 || return 0
  nmcli -t -f ACTIVE,SSID device wifi 2>/dev/null | awk -F: '$1 == "yes" { print $2; exit }' || true
}

json_cache_valid() {
  [[ -s "$1" ]] || return 1
  python - "$1" "$ROOT_DIR" >/dev/null 2>&1 <<'PY'
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)
if data.get("root") != str(Path(sys.argv[2]).resolve()):
    raise SystemExit(1)
raise SystemExit(0)
PY
}

cache_is_fresh() {
  local path="$1" ttl="$2" now mtime
  [[ "$REFRESH_CACHE" == "1" ]] && return 1
  json_cache_valid "$path" || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || printf 0)"
  (( now - mtime < ttl ))
}

write_json_cache() {
  local path="$1" tmp
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.XXXXXX")"
  cat >"$tmp"
  if json_cache_valid "$tmp"; then
    mv -f "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
}

clear_network_cache() {
  rm -f "$NETWORK_CACHE" 2>/dev/null || true
}

status_json() {
  if cache_is_fresh "$NETWORK_CACHE" "$NETWORK_CACHE_TTL"; then
    cat "$NETWORK_CACHE"
    return 0
  fi
  local nmcli_state nmtui_state editor_state nm_state modem_state radio device ssid
  nmcli_state="$(command_state nmcli)"
  nmtui_state="$(command_state nmtui)"
  editor_state="$(command_state nm-connection-editor)"
  nm_state="$(service_state NetworkManager.service)"
  modem_state="$(service_state ModemManager.service)"
  radio="$(wifi_radio)"
  device="$(wifi_device)"
  ssid="$(active_ssid)"
  local payload
  payload="$(python - "$ROOT_DIR" "$nmcli_state" "$nmtui_state" "$editor_state" "$nm_state" "$modem_state" "$radio" "$device" "$ssid" <<'PY'
import json
import sys
from pathlib import Path

keys = ("nmcli", "nmtui", "nm_connection_editor", "networkmanager", "modemmanager", "wifi_radio", "wifi_device", "ssid")
payload = dict(zip(keys, sys.argv[2:]))
payload["schema"] = "sevenos.network.v1"
payload["root"] = str(Path(sys.argv[1]).resolve())
payload["ready"] = payload["nmcli"] == "OK" and payload["networkmanager"] == "RUN"
print(json.dumps(payload))
PY
)"
  printf '%s\n' "$payload" | write_json_cache "$NETWORK_CACHE" || true
  printf '%s\n' "$payload"
}

status_human() {
  printf 'SevenOS Network\n'
  printf '===============\n'
  printf 'NetworkManager: %s\n' "$(service_state NetworkManager.service)"
  printf 'ModemManager:   %s\n' "$(service_state ModemManager.service)"
  printf 'nmcli:          %s\n' "$(command_state nmcli)"
  printf 'nmtui:          %s\n' "$(command_state nmtui)"
  printf 'GUI editor:     %s\n' "$(command_state nm-connection-editor)"
  printf 'Wi-Fi radio:    %s\n' "$(wifi_radio)"
  printf 'Wi-Fi device:   %s\n' "$(wifi_device)"
  printf 'SSID:           %s\n' "$(active_ssid)"
}

enable_network_services() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return 0
  fi

  if is_dry_run; then
    printf '%q systemctl enable --now NetworkManager.service\n' "$(privileged_backend_label)"
    printf '%q systemctl enable --now ModemManager.service # when installed\n' "$(privileged_backend_label)"
    return 0
  fi

  if systemctl list-unit-files NetworkManager.service >/dev/null 2>&1; then
    run_privileged_cmd systemctl enable --now NetworkManager.service
  fi
  if systemctl list-unit-files ModemManager.service >/dev/null 2>&1; then
    run_privileged_cmd systemctl enable --now ModemManager.service || true
  fi
}

unblock_wifi() {
  if command -v rfkill >/dev/null 2>&1; then
    run_cmd rfkill unblock wifi || true
    run_cmd rfkill unblock all || true
  fi
  if command -v nmcli >/dev/null 2>&1; then
    run_cmd nmcli networking on || true
    run_cmd nmcli radio wifi on || true
  fi
}

bootstrap_network() {
  clear_network_cache
  log_info "Preparing SevenOS network stack..."
  require_interactive_admin
  install_package_file "$ROOT_DIR/scripts/packages-network.txt"
  enable_network_services
  unblock_wifi
  log_success "SevenOS network stack prepared."
}

repair_network() {
  clear_network_cache
  log_info "Repairing SevenOS network stack..."
  require_interactive_admin
  enable_network_services
  unblock_wifi
  if is_dry_run; then
    printf 'nmcli device status\n'
    printf 'nmcli device wifi rescan\n'
    return 0
  fi
  if command -v nmcli >/dev/null 2>&1; then
    nmcli device status || true
    nmcli device wifi rescan >/dev/null 2>&1 || true
  fi
  if [[ "${YES:-0}" == "1" ]]; then
    return 0
  fi
  if [[ -x "$ROOT_DIR/bin/seven-wifi" ]]; then
    "$ROOT_DIR/bin/seven-wifi" connect || true
  elif command -v seven-wifi >/dev/null 2>&1; then
    seven-wifi connect || true
  elif command -v nmtui >/dev/null 2>&1; then
    nmtui
  fi
}

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      status_json
    else
      status_human
    fi
    ;;
  bootstrap|apply)
    bootstrap_network
    ;;
  repair|fix)
    repair_network
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    log_error "Unknown network action: $ACTION"
    usage
    exit 1
    ;;
esac
