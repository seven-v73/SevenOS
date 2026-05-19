# SevenOS VM Layer

This directory contains the SevenOS Windows Compatibility Layer.

The default philosophy is now app-first and VM-optional:

```bash
seven run photoshop
seven windows run /path/to/setup.exe
seven windows resolve photoshop --json
```

SevenOS should try Wine, Bottles, Proton or Lutris before asking the user to
create a full Windows VM. The VM path remains available for heavy or
driver-sensitive applications.

Planned scope:

- app-first Windows workflows
- Wine/Bottles/Proton/Lutris resolver
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

## App-First Windows Workflows

```bash
seven windows catalog
seven windows catalog --json
seven windows resolve photoshop
seven windows resolve photoshop --json
seven windows prepare office
SEVENOS_DRY_RUN=1 seven run photoshop
SEVENOS_DRY_RUN=1 seven windows run /path/to/setup.exe
seven windows diagnose /path/to/setup.exe
```

The resolver reports:

- preferred engines for the app
- current engine readiness
- whether the app can open as a native Wayland/Hyprland window
- whether an ISO-backed VM is only an optional fallback
- next actions when Wine, Bottles, Proton, Lutris or the VM are missing

For Microsoft Office and Microsoft 365 installers, SevenOS uses a dedicated
Office prefix instead of treating `OfficeSetup.exe` as a generic executable:

```bash
seven windows prepare office
seven windows run OfficeSetup.exe
seven windows diagnose OfficeSetup.exe
```

The diagnostic command explains common failures such as network, disk-space and
online-installer errors like `0-2031`. It also detects Click-to-Run/Wine-Mono
crashes and explains when the right daily-use path is Bottles or the Windows VM
instead of repeatedly retrying the plain Wine installer.

SevenOS does not download, redistribute or require unofficial Windows images.
If the user wants a lightweight Windows VM, they must provide their own legal
Windows ISO or image.

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
