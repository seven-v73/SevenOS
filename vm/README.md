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
seven windows status
seven windows status --json
seven windows plan
seven windows plan --json
```

This checks:

- CPU virtualization flags
- `/dev/kvm`
- QEMU, Virt Manager, virt-install, virsh
- required packages
- `libvirtd.service`
- current user membership in `libvirt`
- libvirt default network

`seven windows plan --json` is the machine-readable setup plan consumed by
Seven Hub, Seven Server and the Control Plane. It turns missing Wine/Bottles,
KVM, libvirt network and VM creation steps into ordered actions instead of
leaving the user to read raw VM diagnostics.

Start and autostart the default network:

```bash
./install.sh vm-network
```

## Create A Windows VM

Preview the command first:

```bash
./install.sh vm-windows \
  --iso /path/to/windows.iso \
  --virtio-iso /path/to/virtio-win.iso \
  --os win11 \
  --dry-run
```

Launch VM creation:

```bash
./install.sh vm-windows \
  --iso /path/to/windows.iso \
  --virtio-iso /path/to/virtio-win.iso \
  --os win11
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
  --virtio-iso /path/to/virtio-win.iso \
  --os win11 \
  --name sevenos-win11 \
  --ram 12288 \
  --vcpus 6 \
  --disk 120
```

## VirtIO Drivers

Windows may need VirtIO drivers during installation to detect the disk or network device. Use `--virtio-iso /path/to/virtio-win.iso` to attach the driver ISO as a second CD-ROM.

Use `--os win10` or `--os win11` to select the libvirt OS variant.

## GPU Passthrough

GPU passthrough is not automated yet. It needs hardware-specific checks for IOMMU groups, GPU binding, bootloader parameters, and fallback display safety.
