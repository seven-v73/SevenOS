#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

VM_NAME="sevenos-windows"
ACTION="${1:-status}"
shift || true
LOG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
CONSOLE_LOG="$LOG_DIR/windows-console.log"
VM_LOCK="$LOG_DIR/windows-vm.lock"
WATCH_PID_FILE="$LOG_DIR/windows-watch.pid"
CONSOLE_STATE_FILE="$LOG_DIR/windows-console-state.env"
VM_LOCK_FD=""

usage() {
  cat <<'EOF'
SevenOS Windows Mode

Usage:
  ./install.sh windows-mode <action> [options]

Actions:
  status [--json]     Show Windows Mode readiness
  plan [--json]       Show prioritized Windows Mode setup actions
  guide               Explain the friendly Windows setup path
  catalog [--json]    List app-first Windows workflows
  resolve APP [--json] Show the preferred engine for a Windows app
  prepare APP         Prepare a dedicated Windows app prefix
  diagnose APP        Explain a failed installer/app in human language
  run APP             Launch a Windows app through the app-first resolver
  open                Open the best available Windows surface
  enter [--name VM]   Enter Windows Bridge: fix network, start VM and open console
  leave [--name VM]   Leave Windows Bridge and save/shutdown VM to free resources
  sync [--name VM]    Reconcile VM state with the active SevenOS profile
  bridge-status [--json]
                    Show profile/VM/console synchronization state
  apps                Open Bottles for Windows applications
  vm                  Open Virt Manager for the Windows VM
  create [options]    Create/install Windows VM, forwards options to vm-windows
  start [--name VM]   Start Windows VM
  console [--name VM] Open Windows VM console in Virt Manager
  boot-installer [--name VM]
                    Restart VM and press the Windows ISO boot key automatically
  fix-network [--name VM]
                    Attach a Windows-friendly e1000e user-mode network card
  stop [--name VM]    Gracefully stop Windows VM

Examples:
  ./install.sh windows-mode status
  ./install.sh windows-mode guide
  ./install.sh windows-mode resolve photoshop --json
  ./install.sh windows-mode run /path/setup.exe
  ./install.sh windows-mode apps
  seven windows provision --yes
  ./install.sh windows-mode create --iso /path/windows.iso --virtio-iso /path/virtio.iso --os win11
  ./install.sh windows-mode start
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --name) VM_NAME="${2:-}"; shift 2 ;;
    -h|--help|help) usage; exit 0 ;;
    *) break ;;
  esac
done

command_state() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 && printf 'OK' || printf 'MISS'
}

service_state() {
  local service="$1"
  systemctl is-active --quiet "$service" 2>/dev/null && printf 'OK' || printf 'MISS'
}

vm_state() {
  if ! command -v virsh >/dev/null 2>&1; then
    printf 'MISS'
    return 0
  fi

  virsh -c qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1 && printf 'OK' || printf 'MISS'
}

vm_running() {
  local state
  command -v virsh >/dev/null 2>&1 || return 1
  state="$(vm_domstate)"
  [[ "$state" == "running" || "$state" == "paused" ]]
}

vm_domstate() {
  command -v virsh >/dev/null 2>&1 || return 1
  LC_ALL=C LANG=C virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null || true
}

vm_exists() {
  command -v virsh >/dev/null 2>&1 || return 1
  virsh -c qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1
}

notify_user() {
  local title="$1"
  local body="$2"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "SevenOS Windows Bridge" -h string:x-canonical-private-synchronous:sevenos-windows -t 1800 "$title" "$body" >/dev/null 2>&1 || true
  fi
}

active_profile() {
  local profile_file="$LOG_DIR/profile.env"
  if [[ -f "$profile_file" ]]; then
    awk -F= '/^SEVENOS_ACTIVE_PROFILE=/{gsub(/["'\'']/, "", $2); print $2; exit}' "$profile_file" 2>/dev/null || true
  fi
}

console_is_open() {
  local display_uri
  display_uri="$(virsh -c qemu:///system domdisplay "$VM_NAME" 2>/dev/null || true)"
  if [[ -n "$display_uri" ]] && pgrep -u "$(id -u)" -f "remote-viewer .*${display_uri}" >/dev/null 2>&1; then
    return 0
  fi
  if pgrep -u "$(id -u)" -f "virt-viewer .*${VM_NAME}" >/dev/null 2>&1; then
    return 0
  fi
  if pgrep -u "$(id -u)" -f "python3 /usr/bin/virt-manager .*${VM_NAME}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

watchdog_state() {
  local pid
  if [[ -s "$WATCH_PID_FILE" ]]; then
    pid="$(cat "$WATCH_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      printf 'running'
      return 0
    fi
  fi
  printf 'stopped'
}

console_fallback_until() {
  if [[ -f "$CONSOLE_STATE_FILE" ]]; then
    awk -F= '/^FALLBACK_UNTIL=/{gsub(/["'\'']/, "", $2); print $2; exit}' "$CONSOLE_STATE_FILE" 2>/dev/null || true
  fi
}

console_prefer_fallback() {
  local now until
  [[ "${SEVENOS_WINDOWS_CONSOLE:-auto}" == "virt-manager" ]] && return 0
  [[ "${SEVENOS_WINDOWS_CONSOLE:-auto}" == "remote-viewer" ]] && return 1
  now="$(date +%s)"
  until="$(console_fallback_until)"
  [[ -n "$until" && "$until" =~ ^[0-9]+$ && "$until" -gt "$now" ]]
}

console_record_failure() {
  local now count first fallback_until
  now="$(date +%s)"
  count=0
  first="$now"
  if [[ -f "$CONSOLE_STATE_FILE" ]]; then
    count="$(awk -F= '/^FAIL_COUNT=/{gsub(/["'\'']/, "", $2); print $2; exit}' "$CONSOLE_STATE_FILE" 2>/dev/null || printf '0')"
    first="$(awk -F= '/^FIRST_FAIL=/{gsub(/["'\'']/, "", $2); print $2; exit}' "$CONSOLE_STATE_FILE" 2>/dev/null || printf '%s' "$now")"
  fi
  [[ "$count" =~ ^[0-9]+$ ]] || count=0
  [[ "$first" =~ ^[0-9]+$ ]] || first="$now"
  if (( now - first > 90 )); then
    first="$now"
    count=0
  fi
  count=$((count + 1))
  fallback_until="$(console_fallback_until)"
  if (( count >= 2 )); then
    fallback_until=$((now + 900))
    printf '[%s] console fallback enabled: virt-manager for 15 minutes after %s remote-viewer failures\n' "$(date -Is)" "$count" >>"$CONSOLE_LOG"
  fi
  {
    printf 'FAIL_COUNT=%s\n' "$count"
    printf 'FIRST_FAIL=%s\n' "$first"
    printf 'FALLBACK_UNTIL=%s\n' "${fallback_until:-0}"
  } >"$CONSOLE_STATE_FILE"
}

console_record_success() {
  true
}

close_console_action() {
  if is_dry_run; then
    printf 'pkill remote-viewer/virt-viewer/virt-manager for %q\n' "$VM_NAME"
    return 0
  fi
  local display_uri
  display_uri="$(virsh -c qemu:///system domdisplay "$VM_NAME" 2>/dev/null || true)"
  if [[ -n "$display_uri" ]]; then
    pkill -u "$(id -u)" -f "remote-viewer .*${display_uri}" >/dev/null 2>&1 || true
  fi
  pkill -u "$(id -u)" -f "virt-viewer .*${VM_NAME}" >/dev/null 2>&1 || true
  pkill -u "$(id -u)" -f "python3 /usr/bin/virt-manager .*${VM_NAME}" >/dev/null 2>&1 || true
}

run_console_detached() {
  mkdir -p "$LOG_DIR"
  printf '[%s] %s\n' "$(date -Is)" "$*" >>"$CONSOLE_LOG"
  if command -v setsid >/dev/null 2>&1; then
    setsid -f "$@" >>"$CONSOLE_LOG" 2>&1 </dev/null
  else
    nohup "$@" >>"$CONSOLE_LOG" 2>&1 </dev/null &
  fi
}

run_watchdog_detached() {
  [[ "${SEVENOS_WINDOWS_NO_WATCH:-0}" == "1" ]] && return 0
  mkdir -p "$LOG_DIR"
  if [[ -s "$WATCH_PID_FILE" ]]; then
    local old_pid
    old_pid="$(cat "$WATCH_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
      return 0
    fi
  fi
  if command -v setsid >/dev/null 2>&1; then
    setsid env SEVENOS_ROOT="$ROOT_DIR" SEVENOS_WINDOWS_NO_WATCH=1 "$0" watch-enter --name "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 </dev/null &
  else
    env SEVENOS_ROOT="$ROOT_DIR" SEVENOS_WINDOWS_NO_WATCH=1 "$0" watch-enter --name "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 </dev/null &
  fi
  printf '%s\n' "$!" >"$WATCH_PID_FILE"
}

acquire_vm_lock() {
  mkdir -p "$LOG_DIR"
  exec {VM_LOCK_FD}>"$VM_LOCK"
  if ! flock -w 45 "$VM_LOCK_FD"; then
    log_error "Windows VM operation is already running."
    log_warn "Try again in a moment, or inspect: $VM_LOCK"
    exec {VM_LOCK_FD}>&-
    VM_LOCK_FD=""
    return 1
  fi
}

release_vm_lock() {
  if [[ -n "${VM_LOCK_FD:-}" ]]; then
    flock -u "$VM_LOCK_FD" 2>/dev/null || true
    eval "exec ${VM_LOCK_FD}>&-" 2>/dev/null || true
    VM_LOCK_FD=""
  fi
}

status_action() {
  printf 'SevenOS Windows Mode\n\n'
  printf '  %-14s %s\n' "wine" "$(command_state wine)"
  printf '  %-14s %s\n' "lutris" "$(command_state lutris)"
  printf '  %-14s %s\n' "flatpak" "$(command_state flatpak)"
  printf '  %-14s %s\n' "virt-manager" "$(command_state virt-manager)"
  printf '  %-14s %s\n' "virsh" "$(command_state virsh)"
  printf '  %-14s %s\n' "libvirtd" "$(service_state libvirtd.service)"
  printf '  %-14s %s\n' "$VM_NAME" "$(vm_state)"
  printf '\n'
  printf 'Next steps:\n'
  printf '  seven improve compatibility\n'
  printf '  ./install.sh vm-check\n'
  printf '  ./install.sh vm-network\n'
  printf '  seven windows provision --yes\n'
  printf '  ./install.sh windows-mode create --iso /path/windows.iso --virtio-iso /path/virtio.iso\n'
}

bridge_status_json() {
  local profile state exists console watch desired synchronized recommendation
  profile="$(active_profile)"
  state="$(vm_domstate || true)"
  if vm_exists; then
    exists="true"
  else
    exists="false"
    state="missing"
  fi
  if console_is_open; then
    console="open"
  else
    console="closed"
  fi
  watch="$(watchdog_state)"

  if [[ "$profile" == "windows" ]]; then
    desired="running-with-console"
    if [[ "$exists" == "true" && "$state" == "running" && "$console" == "open" ]]; then
      synchronized="true"
      recommendation="none"
    else
      synchronized="false"
      recommendation="seven windows sync"
    fi
  else
    desired="idle"
    if [[ "$exists" == "false" || ( "$state" != "running" && "$state" != "paused" ) ]]; then
      synchronized="true"
      recommendation="none"
    else
      synchronized="false"
      recommendation="seven windows sync"
    fi
  fi

  python - "$VM_NAME" "${profile:-unknown}" "$exists" "${state:-unknown}" "$console" "$watch" "$desired" "$synchronized" "$recommendation" "$CONSOLE_LOG" <<'PY'
import json
import sys

keys = [
    "vm_name",
    "active_profile",
    "vm_exists",
    "vm_state",
    "console",
    "watchdog",
    "desired_state",
    "synchronized",
    "recommended_action",
    "log",
]
payload = dict(zip(keys, sys.argv[1:]))
payload["schema"] = "sevenos.windows-bridge-runtime.v1"
payload["vm_exists"] = payload["vm_exists"] == "true"
payload["synchronized"] = payload["synchronized"] == "true"
print(json.dumps(payload, indent=2))
PY
}

bridge_status_human() {
  local json
  json="$(bridge_status_json)"
  WINDOWS_BRIDGE_JSON="$json" python - <<'PY'
import json
import os

data = json.loads(os.environ["WINDOWS_BRIDGE_JSON"])
print("SevenOS Windows Bridge Runtime")
print()
print(f"  Active profile      {data.get('active_profile')}")
print(f"  VM                  {data.get('vm_name')}")
print(f"  VM state            {data.get('vm_state')}")
print(f"  Console             {data.get('console')}")
print(f"  Watchdog            {data.get('watchdog')}")
print(f"  Desired state       {data.get('desired_state')}")
print(f"  Synchronized        {str(data.get('synchronized')).lower()}")
if data.get("recommended_action") != "none":
    print()
    print(f"Recommended action: {data.get('recommended_action')}")
print(f"Log: {data.get('log')}")
PY
}

start_action() {
  if is_dry_run; then
    printf 'virsh -c qemu:///system start %q\n' "$VM_NAME"
    return 0
  fi
  require_command virsh
  acquire_vm_lock
  if ! virsh -c qemu:///system start "$VM_NAME"; then
    release_vm_lock
    return 1
  fi
  release_vm_lock
}

console_action() {
  local display_uri
  if is_dry_run; then
    printf 'remote-viewer spice://127.0.0.1:5900 || virt-manager --connect qemu:///system --show-domain-console %q\n' "$VM_NAME"
    return 0
  fi
  require_command virsh
  display_uri="$(virsh -c qemu:///system domdisplay "$VM_NAME" 2>/dev/null || true)"
  if [[ -n "$display_uri" ]] && pgrep -u "$(id -u)" -f "remote-viewer .*${display_uri}" >/dev/null 2>&1; then
    notify_user "Windows Bridge" "Windows console is already open."
    return 0
  fi
  if console_prefer_fallback && command -v virt-manager >/dev/null 2>&1; then
    printf '[%s] opening stable VM console with virt-manager\n' "$(date -Is)" >>"$CONSOLE_LOG"
    pkill -u "$(id -u)" -f "python3 /usr/bin/virt-manager .*${VM_NAME}" >/dev/null 2>&1 || true
    sleep 0.5
    run_console_detached virt-manager --connect qemu:///system --show-domain-console "$VM_NAME"
    return 0
  fi
  if [[ "$display_uri" == spice://* ]] && command -v remote-viewer >/dev/null 2>&1; then
    run_console_detached remote-viewer "$display_uri"
    sleep 1
    if pgrep -u "$(id -u)" -f "remote-viewer .*${display_uri}" >/dev/null 2>&1; then
      console_record_success
      return 0
    fi
    log_warn "remote-viewer closed quickly. See: $CONSOLE_LOG"
    console_record_failure
    if command -v virt-manager >/dev/null 2>&1; then
      run_console_detached virt-manager --connect qemu:///system --show-domain-console "$VM_NAME"
      return 0
    fi
    return 0
  fi
  if command -v virt-viewer >/dev/null 2>&1; then
    run_console_detached virt-viewer --connect qemu:///system --wait "$VM_NAME"
    return 0
  fi
  require_command virt-manager
  run_console_detached virt-manager --connect qemu:///system --show-domain-console "$VM_NAME"
}

boot_installer_action() {
  if is_dry_run; then
    printf 'virsh -c qemu:///system reset %q || virsh -c qemu:///system start %q\n' "$VM_NAME" "$VM_NAME"
    printf 'sleep 2 && virsh -c qemu:///system send-key %q KEY_SPACE\n' "$VM_NAME"
    printf 'sleep 1 && virsh -c qemu:///system send-key %q KEY_ENTER\n' "$VM_NAME"
    return 0
  fi
  require_command virsh
  local state
  state="$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null || true)"
  if [[ "$state" == "running" ]]; then
    virsh -c qemu:///system reset "$VM_NAME"
  else
    virsh -c qemu:///system start "$VM_NAME"
  fi
  sleep 2
  virsh -c qemu:///system send-key "$VM_NAME" KEY_SPACE || true
  sleep 1
  virsh -c qemu:///system send-key "$VM_NAME" KEY_ENTER || true
  console_action
}

fix_network_action() {
  if is_dry_run; then
    printf "virsh -c qemu:///system attach-device %q /tmp/sevenos-windows-e1000e.xml --live --config\n" "$VM_NAME"
    return 0
  fi
  require_command virsh
  local xml
  if virsh -c qemu:///system dumpxml "$VM_NAME" 2>/dev/null | grep -q "<model type='e1000e'/>"; then
    log_success "Windows-friendly e1000e network card is already attached."
    return 0
  fi
  xml="$(mktemp)"
  cat >"$xml" <<'EOF'
<interface type='user'>
  <model type='e1000e'/>
</interface>
EOF
  virsh -c qemu:///system attach-device "$VM_NAME" "$xml" --live --config
  rm -f "$xml"
  log_success "Attached e1000e user-mode network card to $VM_NAME."
  log_info "Inside Windows, disable/enable the adapter or reboot Windows if the network icon does not refresh immediately."
}

enter_action() {
  if is_dry_run; then
    printf 'seven windows fix-network\n'
    printf 'virsh -c qemu:///system start %q || true\n' "$VM_NAME"
    printf 'seven windows console\n'
    return 0
  fi
  require_command virsh
  acquire_vm_lock
  if ! virsh -c qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1; then
    notify_user "Windows Bridge" "VM not created yet. Opening the Windows assistant."
    "$ROOT_DIR/bin/seven-windows-assistant" status || true
    "$ROOT_DIR/bin/seven-windows-assistant" vm || true
    release_vm_lock
    return 1
  fi

  run_watchdog_detached

  fix_network_action || true
  mkdir -p "$LOG_DIR"
  local state
  state="$(vm_domstate)"
  printf '[%s] enter state-before=%s vm=%s\n' "$(date -Is)" "${state:-unknown}" "$VM_NAME" >>"$CONSOLE_LOG"

  if [[ "$state" == "in shutdown" || "$state" == "shutting down" ]]; then
    notify_user "Windows Bridge" "Waiting for the previous Windows shutdown to finish..."
    for _ in $(seq 1 40); do
      state="$(vm_domstate)"
      [[ "$state" != "in shutdown" && "$state" != "shutting down" ]] && break
      sleep 0.5
    done
    printf '[%s] enter state-after-shutdown-wait=%s vm=%s\n' "$(date -Is)" "${state:-unknown}" "$VM_NAME" >>"$CONSOLE_LOG"
  fi

  if [[ "$state" == "paused" ]]; then
    notify_user "Windows Bridge" "Resuming the Windows VM..."
    virsh -c qemu:///system resume "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
    sleep 1
    state="$(vm_domstate)"
    printf '[%s] enter state-after-resume=%s vm=%s\n' "$(date -Is)" "${state:-unknown}" "$VM_NAME" >>"$CONSOLE_LOG"
  fi

  if [[ "$state" != "running" && "$state" != "paused" ]]; then
    notify_user "Windows Bridge" "Starting the Windows VM..."
    if ! virsh -c qemu:///system start "$VM_NAME"; then
      release_vm_lock
      log_error "Unable to start Windows VM: $VM_NAME"
      log_warn "Run: seven windows status"
      return 1
    fi
    for _ in $(seq 1 20); do
      state="$(vm_domstate)"
      [[ "$state" == "running" || "$state" == "paused" ]] && break
      sleep 0.5
    done
    if [[ "$state" != "running" && "$state" != "paused" ]]; then
      release_vm_lock
      log_error "Windows VM did not reach a runnable state. Current state: ${state:-unknown}"
      return 1
    fi
    if [[ "$state" == "paused" ]]; then
      virsh -c qemu:///system resume "$VM_NAME" >/dev/null 2>&1 || true
    fi
  else
    notify_user "Windows Bridge" "Windows VM is already running."
  fi

  state="$(vm_domstate)"
  if [[ "$state" == "paused" ]]; then
    virsh -c qemu:///system resume "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
    sleep 1
    state="$(vm_domstate)"
  fi
  if [[ "$state" != "running" ]]; then
    release_vm_lock
    log_error "Windows VM is not running after enter. Current state: ${state:-unknown}"
    log_warn "Run: seven windows status"
    return 1
  fi
  release_vm_lock
  console_action
  run_watchdog_detached
}

watch_enter_action() {
  if is_dry_run; then
    printf 'watch Windows Bridge console and VM stability for %q\n' "$VM_NAME"
    return 0
  fi
  require_command virsh
  mkdir -p "$LOG_DIR"
  printf '%s\n' "$$" >"$WATCH_PID_FILE"
  trap 'rm -f "$WATCH_PID_FILE"' EXIT
  local state
  local tick=0
  sleep 2
  while true; do
    if [[ "$(active_profile)" != "windows" ]]; then
      printf '[%s] watch stopped: active profile is %s\n' "$(date -Is)" "$(active_profile)" >>"$CONSOLE_LOG"
      return 0
    fi

    state="$(vm_domstate)"
    if [[ "$state" != "running" && "$state" != "paused" ]]; then
      printf '[%s] watch detected VM state=%s, restarting %s\n' "$(date -Is)" "${state:-unknown}" "$VM_NAME" >>"$CONSOLE_LOG"
      virsh -c qemu:///system start "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
      sleep 3
      state="$(vm_domstate)"
      if [[ "$state" == "paused" ]]; then
        virsh -c qemu:///system resume "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
      fi
      console_action || true
    elif [[ "$state" == "paused" ]]; then
      printf '[%s] watch detected paused VM, resuming %s\n' "$(date -Is)" "$VM_NAME" >>"$CONSOLE_LOG"
      virsh -c qemu:///system resume "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
      sleep 2
      console_action || true
    elif ! console_is_open; then
      printf '[%s] watch detected closed console, reopening %s\n' "$(date -Is)" "$VM_NAME" >>"$CONSOLE_LOG"
      console_record_failure
      console_action || true
    fi

    tick=$((tick + 1))
    if (( tick % 15 == 0 )); then
      printf '[%s] watch alive: profile=windows state=%s console=%s\n' "$(date -Is)" "$state" "$(console_is_open && printf open || printf closed)" >>"$CONSOLE_LOG"
    fi
    sleep 4
  done
}

leave_action() {
  local mode="${SEVENOS_WINDOWS_LEAVE_MODE:-managedsave}"
  if is_dry_run; then
    printf 'seven windows close-console\n'
    printf 'virsh -c qemu:///system %s %q\n' "$mode" "$VM_NAME"
    return 0
  fi
  require_command virsh
  acquire_vm_lock
  if [[ "${SEVENOS_WINDOWS_AUTO_STOPPED_BY_PROFILE:-0}" == "1" ]]; then
    local active_profile_file active_profile
    active_profile_file="$LOG_DIR/profile.env"
    if [[ -f "$active_profile_file" ]]; then
      active_profile="$(awk -F= '/^SEVENOS_ACTIVE_PROFILE=/{gsub(/["'\'']/, "", $2); print $2; exit}' "$active_profile_file" 2>/dev/null || true)"
      if [[ "$active_profile" == "windows" ]]; then
        printf '[%s] leave skipped because active profile is windows again\n' "$(date -Is)" >>"$CONSOLE_LOG"
        release_vm_lock
        notify_user "Windows Bridge" "Windows Bridge is active again; VM shutdown skipped."
        return 0
      fi
    fi
  fi
  if ! vm_exists; then
    notify_user "Windows Bridge" "No Windows VM is registered yet."
    release_vm_lock
    return 0
  fi

  close_console_action || true
  if ! vm_running; then
    notify_user "Windows Bridge" "Windows VM is already idle."
    release_vm_lock
    return 0
  fi

  mkdir -p "$LOG_DIR"
  printf '[%s] leave mode=%s vm=%s\n' "$(date -Is)" "$mode" "$VM_NAME" >>"$CONSOLE_LOG"
  case "$mode" in
    keep)
      notify_user "Windows Bridge" "Leaving profile; Windows VM kept running."
      ;;
    pause|suspend)
      notify_user "Windows Bridge" "Pausing Windows VM."
      virsh -c qemu:///system suspend "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
      ;;
    shutdown)
      notify_user "Windows Bridge" "Shutting down Windows VM."
      virsh -c qemu:///system shutdown "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
      ;;
    destroy|force)
      notify_user "Windows Bridge" "Force-stopping Windows VM."
      virsh -c qemu:///system destroy "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
      ;;
    managedsave|save|"")
      notify_user "Windows Bridge" "Saving Windows VM state and freeing resources."
      if ! virsh -c qemu:///system managedsave "$VM_NAME" >>"$CONSOLE_LOG" 2>&1; then
        log_warn "managedsave failed; falling back to graceful shutdown. See: $CONSOLE_LOG"
        virsh -c qemu:///system shutdown "$VM_NAME" >>"$CONSOLE_LOG" 2>&1 || true
      fi
      ;;
    *)
      log_error "Unsupported Windows leave mode: $mode"
      log_warn "Use one of: managedsave, shutdown, pause, keep, destroy"
      release_vm_lock
      return 1
      ;;
  esac
  release_vm_lock
}

sync_action() {
  local profile
  profile="$(active_profile)"
  if is_dry_run; then
    printf 'active profile: %s\n' "${profile:-unknown}"
    printf 'if profile == windows: seven windows enter\n'
    printf 'else: seven windows leave\n'
    return 0
  fi

  mkdir -p "$LOG_DIR"
  printf '[%s] sync profile=%s vm=%s state=%s\n' "$(date -Is)" "${profile:-unknown}" "$VM_NAME" "$(vm_domstate || true)" >>"$CONSOLE_LOG"
  if [[ "$profile" == "windows" ]]; then
    enter_action
  else
    SEVENOS_WINDOWS_AUTO_STOPPED_BY_PROFILE=1 leave_action
  fi
}

stop_action() {
  if is_dry_run; then
    printf 'virsh -c qemu:///system shutdown %q\n' "$VM_NAME"
    return 0
  fi
  require_command virsh
  virsh -c qemu:///system shutdown "$VM_NAME"
}

case "$ACTION" in
  status)
    if [[ "${1:-}" == "--json" && -x "$ROOT_DIR/bin/seven-windows-assistant" ]]; then
      "$ROOT_DIR/bin/seven-windows-assistant" status --json
    else
      status_action
    fi
    ;;
  bridge-status|runtime-status|sync-status)
    if [[ "${1:-}" == "--json" ]]; then
      bridge_status_json
    else
      bridge_status_human
    fi
    ;;
  plan|guide|catalog|resolve|prepare|diagnose|doctor|run|open|apps|bottles|vm|virt-manager|network|check)
    "$ROOT_DIR/bin/seven-windows-assistant" "$ACTION" "$@"
    ;;
  enter)
    enter_action
    ;;
  leave|exit)
    leave_action
    ;;
  sync|reconcile)
    sync_action
    ;;
  close-console)
    close_console_action
    ;;
  create)
    "$ROOT_DIR/vm/windows-vm.sh" "$@"
    ;;
  start)
    start_action
    ;;
  console)
    console_action
    ;;
  boot-installer|installer-boot)
    boot_installer_action
    ;;
  fix-network|network-fix)
    fix_network_action
    ;;
  watch-enter)
    watch_enter_action
    ;;
  stop)
    stop_action
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "Unknown Windows Mode action: $ACTION"
    usage
    exit 1
    ;;
esac
