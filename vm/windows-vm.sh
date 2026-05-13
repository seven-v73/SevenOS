#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

VM_NAME="sevenos-windows"
RAM_MB="8192"
VCPUS="4"
DISK_SIZE_GB="80"
WINDOWS_ISO=""
VIRTIO_ISO=""
OS_VARIANT="win11"
DRY_RUN="${SEVENOS_DRY_RUN:-0}"

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
    --dry-run) DRY_RUN=1; export SEVENOS_DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$WINDOWS_ISO" ]]; then
  usage
  log_error "Missing Windows ISO path. Use --iso /path/to/windows.iso"
  exit 1
fi

if [[ "$DRY_RUN" != "1" && ! -f "$WINDOWS_ISO" ]]; then
  log_error "Windows ISO not found: $WINDOWS_ISO"
  exit 1
fi

if [[ -n "$VIRTIO_ISO" && "$DRY_RUN" != "1" && ! -f "$VIRTIO_ISO" ]]; then
  log_error "VirtIO ISO not found: $VIRTIO_ISO"
  exit 1
fi

if [[ "$DRY_RUN" != "1" ]]; then
  require_command virt-install
  require_command virsh
fi

VM_DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"

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
  --disk "path=${VM_DISK_PATH},size=${DISK_SIZE_GB},bus=virtio,format=qcow2"
  --cdrom "$WINDOWS_ISO"
  --network network=default,model=virtio
  --graphics spice
  --video virtio
  --sound ich9
  --channel spicevmc
  --rng /dev/urandom
)

if [[ -n "$VIRTIO_ISO" ]]; then
  virt_args+=(--disk "path=${VIRTIO_ISO},device=cdrom,readonly=on")
fi

log_info "Preparing Windows VM: $VM_NAME"
if [[ -n "$VIRTIO_ISO" ]]; then
  log_info "VirtIO driver ISO attached: $VIRTIO_ISO"
else
  log_warn "No VirtIO driver ISO provided. Windows may not detect the disk or network device."
fi

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'virt-install'
  printf ' %q' "${virt_args[@]}"
  printf '\n'
  exit 0
fi

if ! virsh -c qemu:///system net-info default >/dev/null 2>&1; then
  log_info "Creating libvirt default network..."
  sudo virsh -c qemu:///system net-define /usr/share/libvirt/networks/default.xml
fi

sudo virsh -c qemu:///system net-start default >/dev/null 2>&1 || true
sudo virsh -c qemu:///system net-autostart default >/dev/null 2>&1 || true
sudo virt-install "${virt_args[@]}"

log_success "Windows VM install launched: $VM_NAME"
