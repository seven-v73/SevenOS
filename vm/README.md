# SevenOS VM Layer

This directory will contain the Windows VM workflow for SevenOS.

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
