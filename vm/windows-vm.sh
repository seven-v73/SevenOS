#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

VM_NAME="sevenos-windows"
RAM_MB="8192"
VCPUS="4"
DISK_SIZE_GB="80"
DISK_BUS="${SEVENOS_WINDOWS_DISK_BUS:-sata}"
PROVISIONED_DISK_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/sevenos/vm/windows/${VM_NAME}.qcow2"
VM_DISK_PATH=""
WINDOWS_ISO=""
VIRTIO_ISO=""
OS_VARIANT="win11"
DRY_RUN="${SEVENOS_DRY_RUN:-0}"
LIBVIRT_USER="${SEVENOS_LIBVIRT_USER:-libvirt-qemu}"
NETWORK_MODE="${SEVENOS_WINDOWS_NETWORK_MODE:-user}"
NETWORK_MODEL="${SEVENOS_WINDOWS_NETWORK_MODEL:-e1000e}"

usage() {
  cat <<'EOF'
SevenOS Windows VM assistant

Usage:
  ./install.sh vm-windows --iso /path/to/windows.iso [options]

Options:
  --iso PATH       Windows 10/11 ISO path
  --virtio-iso PATH
                   Optional VirtIO driver ISO path
  --os win10|win11 OS variant, default: win11
  --name NAME      VM name, default: sevenos-windows
  --ram MB         RAM in MB, default: 8192
  --vcpus N        vCPU count, default: 4
  --disk GB        Disk size in GB, default: 80
  --disk-path PATH Use an existing qcow2 disk path
  --disk-bus sata|virtio
                   VM disk bus, default: sata so Windows installer sees it.
  --network-mode user|default
                   Network backend, default: user. Use default for libvirt bridge.
  --network-model e1000e|virtio
                   Network card model, default: e1000e so Windows has network before drivers.
  --dry-run        Print the virt-install command only
  -h, --help       Show this help

Notes:
  This creates a standard UEFI Windows VM through libvirt.
  Use --virtio-iso for Windows storage and network drivers.
  GPU passthrough is intentionally not automated yet.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --iso) WINDOWS_ISO="${2:-}"; shift 2 ;;
    --virtio-iso) VIRTIO_ISO="${2:-}"; shift 2 ;;
    --os)
      case "${2:-}" in
        win10|win11) OS_VARIANT="$2" ;;
        *) log_error "Unsupported OS variant: ${2:-}"; usage; exit 1 ;;
      esac
      shift 2
      ;;
    --name) VM_NAME="${2:-}"; shift 2 ;;
    --ram) RAM_MB="${2:-}"; shift 2 ;;
    --vcpus) VCPUS="${2:-}"; shift 2 ;;
    --disk) DISK_SIZE_GB="${2:-}"; shift 2 ;;
    --disk-path) VM_DISK_PATH="${2:-}"; shift 2 ;;
    --disk-bus)
      case "${2:-}" in
        sata|virtio) DISK_BUS="$2" ;;
        *) log_error "Unsupported disk bus: ${2:-}"; usage; exit 1 ;;
      esac
      shift 2
      ;;
    --network-mode)
      case "${2:-}" in
        user|default) NETWORK_MODE="$2" ;;
        *) log_error "Unsupported network mode: ${2:-}"; usage; exit 1 ;;
      esac
      shift 2
      ;;
    --network-model)
      case "${2:-}" in
        e1000e|virtio) NETWORK_MODEL="$2" ;;
        *) log_error "Unsupported network model: ${2:-}"; usage; exit 1 ;;
      esac
      shift 2
      ;;
    --dry-run) DRY_RUN=1; export SEVENOS_DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

iso_state() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    printf 'MISS'
    return 0
  fi
  if command -v file >/dev/null 2>&1 && file -b "$path" 2>/dev/null | grep -qi 'ISO 9660'; then
    printf 'OK'
    return 0
  fi
  printf 'INVALID'
}

ensure_tun() {
  if [[ -c /dev/net/tun ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'sudo modprobe tun\n'
    return 0
  fi
  log_info "Loading tun kernel module for libvirt networking..."
  sudo modprobe tun
  if [[ ! -c /dev/net/tun ]]; then
    log_error "/dev/net/tun is still unavailable after modprobe tun"
    log_warn "Try: sudo modprobe tun && sudo systemctl restart libvirtd"
    exit 1
  fi
}

grant_libvirt_file_access() {
  local path="$1"
  local mode="$2"
  local dir parent
  [[ "$DRY_RUN" == "1" ]] && return 0
  [[ "$path" == "$HOME"/* ]] || return 0
  getent passwd "$LIBVIRT_USER" >/dev/null 2>&1 || return 0
  command -v setfacl >/dev/null 2>&1 || {
    log_warn "setfacl is missing; libvirt may not access $path under your home directory"
    return 0
  }

  log_info "Granting $LIBVIRT_USER access to VM media under your home directory..."
  parent="$(dirname "$path")"
  dir="$HOME"
  sudo setfacl -m "u:${LIBVIRT_USER}:--x" "$dir" 2>/dev/null || true
  local relative="${parent#"$HOME"/}"
  local part
  IFS='/' read -r -a parts <<<"$relative"
  for part in "${parts[@]}"; do
    [[ -n "$part" ]] || continue
    dir="$dir/$part"
    sudo setfacl -m "u:${LIBVIRT_USER}:--x" "$dir" 2>/dev/null || true
  done
  sudo setfacl -m "u:${LIBVIRT_USER}:${mode}" "$path"
}

if [[ -z "$WINDOWS_ISO" ]]; then
  usage
  log_error "Missing Windows ISO path. Use --iso /path/to/windows.iso"
  exit 1
fi

if [[ "$DRY_RUN" != "1" && ! -f "$WINDOWS_ISO" ]]; then
  log_error "Windows ISO not found: $WINDOWS_ISO"
  exit 1
fi
if [[ "$DRY_RUN" != "1" && "$(iso_state "$WINDOWS_ISO")" != "OK" ]]; then
  log_error "Windows media is not a valid ISO: $WINDOWS_ISO"
  exit 1
fi

if [[ -n "$VIRTIO_ISO" && "$DRY_RUN" != "1" && ! -f "$VIRTIO_ISO" ]]; then
  log_error "VirtIO ISO not found: $VIRTIO_ISO"
  if [[ -s "${VIRTIO_ISO}.part" ]]; then
    log_warn "A partial VirtIO download exists: ${VIRTIO_ISO}.part"
    log_warn "Resume it with: seven windows virtio --yes"
  else
    log_warn "Download it with: seven windows virtio --yes"
  fi
  exit 1
fi
if [[ -n "$VIRTIO_ISO" && "$DRY_RUN" != "1" && "$(iso_state "$VIRTIO_ISO")" != "OK" ]]; then
  log_error "VirtIO media is not a valid ISO: $VIRTIO_ISO"
  log_warn "Re-download it with: seven windows virtio --yes"
  exit 1
fi

if [[ "$DRY_RUN" != "1" ]]; then
  require_command virt-install
  require_command virsh
  if [[ "$NETWORK_MODE" == "default" ]]; then
    ensure_tun
  fi
fi

if [[ -z "$VM_DISK_PATH" ]]; then
  if [[ -f "$PROVISIONED_DISK_PATH" ]]; then
    VM_DISK_PATH="$PROVISIONED_DISK_PATH"
  else
    VM_DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
  fi
fi

if [[ "$DRY_RUN" != "1" ]] && virsh -c qemu:///system dominfo "$VM_NAME" >/dev/null 2>&1; then
  vm_state="$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null || printf 'unknown')"
  log_success "Windows VM is already registered: $VM_NAME ($vm_state)"
  log_info "SevenOS will keep the existing VM instead of recreating it."
  log_info "Open the console with: seven windows console"
  log_info "Synchronize the bridge with: seven windows sync"
  exit 0
fi

disk_spec="path=${VM_DISK_PATH},bus=${DISK_BUS},format=qcow2"
if [[ ! -f "$VM_DISK_PATH" ]]; then
  disk_spec="${disk_spec},size=${DISK_SIZE_GB}"
fi

virt_args=(
  --connect qemu:///system
  --name "$VM_NAME"
  --memory "$RAM_MB"
  --vcpus "$VCPUS"
  --cpu host-passthrough
  --machine q35
  --features kvm_hidden=on
  --os-variant "$OS_VARIANT"
  --boot uefi
  --disk "$disk_spec"
  --cdrom "$WINDOWS_ISO"
  --graphics spice
  --video virtio
  --sound ich9
  --channel spicevmc
  --rng /dev/urandom
)

case "$NETWORK_MODE" in
  user)
    virt_args+=(--network "user,model=${NETWORK_MODEL}")
    ;;
  default)
    virt_args+=(--network "network=default,model=${NETWORK_MODEL}")
    ;;
esac

if [[ -n "$VIRTIO_ISO" ]]; then
  virt_args+=(--disk "path=${VIRTIO_ISO},device=cdrom,readonly=on")
fi
virt_args+=(--noautoconsole)

log_info "Preparing Windows VM: $VM_NAME"
log_info "VM disk: $VM_DISK_PATH"
log_info "Disk bus: $DISK_BUS"
if [[ "$VM_DISK_PATH" == "$HOME"/* ]]; then
  log_warn "The disk is under your home directory. SevenOS will grant libvirt scoped ACL access."
fi
if [[ -n "$VIRTIO_ISO" ]]; then
  log_info "VirtIO driver ISO attached: $VIRTIO_ISO"
else
  log_warn "No VirtIO driver ISO provided. Windows network/performance drivers may be unavailable."
fi
if [[ "$NETWORK_MODE" == "user" ]]; then
  log_info "Network mode: user-mode NAT (no /dev/net/tun dependency during install)"
else
  log_info "Network mode: libvirt default bridge"
fi
log_info "Network model: $NETWORK_MODEL"

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'virt-install'
  printf ' %q' "${virt_args[@]}"
  printf '\n'
  exit 0
fi

if [[ "$NETWORK_MODE" == "default" ]]; then
  if ! virsh -c qemu:///system net-info default >/dev/null 2>&1; then
    log_info "Creating libvirt default network..."
    sudo virsh -c qemu:///system net-define /usr/share/libvirt/networks/default.xml
  fi
  sudo virsh -c qemu:///system net-start default >/dev/null 2>&1 || true
  sudo virsh -c qemu:///system net-autostart default >/dev/null 2>&1 || true
fi
grant_libvirt_file_access "$WINDOWS_ISO" "r--"
if [[ -n "$VIRTIO_ISO" ]]; then
  grant_libvirt_file_access "$VIRTIO_ISO" "r--"
fi
if [[ -f "$VM_DISK_PATH" ]]; then
  grant_libvirt_file_access "$VM_DISK_PATH" "rw-"
fi
sudo virt-install "${virt_args[@]}"

log_success "Windows VM install launched: $VM_NAME"
log_info "Open the console with: seven windows console"
