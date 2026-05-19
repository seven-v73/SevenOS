#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

VM_NAME="sevenos-windows"
ACTION="${1:-status}"
shift || true

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
  apps                Open Bottles for Windows applications
  vm                  Open Virt Manager for the Windows VM
  create [options]    Create/install Windows VM, forwards options to vm-windows
  start [--name VM]   Start Windows VM
  console [--name VM] Open Windows VM console in Virt Manager
  stop [--name VM]    Gracefully stop Windows VM

Examples:
  ./install.sh windows-mode status
  ./install.sh windows-mode guide
  ./install.sh windows-mode resolve photoshop --json
  ./install.sh windows-mode run /path/setup.exe
  ./install.sh windows-mode apps
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
  printf '  ./install.sh windows-mode create --iso /path/windows.iso --virtio-iso /path/virtio.iso\n'
}

start_action() {
  if is_dry_run; then
    printf 'virsh -c qemu:///system start %q\n' "$VM_NAME"
    return 0
  fi
  require_command virsh
  virsh -c qemu:///system start "$VM_NAME"
}

console_action() {
  if is_dry_run; then
    printf 'virt-manager --connect qemu:///system --show-domain-console %q\n' "$VM_NAME"
    return 0
  fi
  require_command virt-manager
  virt-manager --connect qemu:///system --show-domain-console "$VM_NAME"
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
  plan|guide|catalog|resolve|prepare|diagnose|doctor|run|open|apps|bottles|vm|virt-manager|network|check)
    "$ROOT_DIR/bin/seven-windows-assistant" "$ACTION" "$@"
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
