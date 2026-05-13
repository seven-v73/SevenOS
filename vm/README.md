# SevenOS VM Layer

This directory contains the first Windows VM workflow for SevenOS.

Planned scope:

- KVM/QEMU setup validation
- Virt Manager integration
- Windows 10/11 VM templates
- shared folders
- SPICE tools guidance
- optional GPU passthrough documentation

The Phase 1 installer only installs the required packages through `scripts/packages-windows.txt`.

Current Phase 1 behavior:

- installs QEMU, Virt Manager, SPICE viewer tooling, OVMF firmware, and network helpers
- enables `libvirtd`
- adds the current user to the `libvirt` group
- installs Bottles through Flatpak when possible

After installation, log out and back in before using Virt Manager without elevated permissions.

## Check Readiness

```bash
./install.sh vm-check
```

This checks:

- CPU virtualization flags
- `/dev/kvm`
- QEMU, Virt Manager, virt-install, virsh
- required packages
- `libvirtd.service`
- current user membership in `libvirt`
- libvirt default network

Start and autostart the default network:

```bash
./install.sh vm-network
```

## Create A Windows VM

Preview the command first:

```bash
./install.sh vm-windows --iso /path/to/windows.iso --dry-run
```

Launch VM creation:

```bash
./install.sh vm-windows --iso /path/to/windows.iso
```

Defaults:

- VM name: `sevenos-windows`
- RAM: 8192 MB
- vCPU: 4
- disk: 80 GB
- firmware: UEFI
- graphics: SPICE
- disk/network bus: VirtIO

Customize:

```bash
./install.sh vm-windows \
  --iso /path/to/windows.iso \
  --name sevenos-win11 \
  --ram 12288 \
  --vcpus 6 \
  --disk 120
```

## VirtIO Drivers

Windows may need VirtIO drivers during installation to detect the disk or network device. The helper prepares a performant VirtIO VM, but driver ISO handling will be improved in a later phase.

## GPU Passthrough

GPU passthrough is not automated yet. It needs hardware-specific checks for IOMMU groups, GPU binding, bootloader parameters, and fallback display safety.
