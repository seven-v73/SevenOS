# SevenOS Archiso

This directory contains the first SevenOS live ISO profile.

The profile is intentionally minimal: it creates a bootable Arch-based live environment, injects the SevenOS repository into `/opt/SevenOS`, and provides a small welcome command with the SevenOS African first identity.

## Build

From the repository root:

```bash
./install.sh iso-tools
./install.sh iso
```

Preview the build:

```bash
./install.sh iso --dry-run
```

The ISO is written to:

```text
out/iso/
```

Temporary build files are written to:

```text
out/archiso/
```

## Live Environment

Inside the ISO:

- hostname is `sevenos-live`
- repository is available at `/opt/SevenOS`
- user `seven` is created with passwordless sudo
- NetworkManager and SSH are enabled
- `sevenos-welcome` prints the first commands to run

## Current Scope

Implemented:

- Archiso profile
- package set
- live environment branding
- repository injection
- ISO build script

Still planned:

- graphical installer
- Calamares or custom installer evaluation
- SevenOS boot splash and theme assets
- hardware-specific package variants
- release signing and checksum workflow
