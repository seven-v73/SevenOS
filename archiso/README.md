# SevenOS Archiso

This directory contains the first SevenOS live ISO profile.

The profile is intentionally minimal: it creates a bootable Arch-based live environment, injects the SevenOS repository into `/opt/SevenOS`, and provides a small welcome command with the SevenOS African first ecosystem identity.

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
- NetworkManager is enabled
- SSH is installed but not enabled by default
- `sevenos-welcome` prints the first commands to run
- `seven` is installed in `/usr/local/bin`
- `sevenpkg` is installed in `/usr/local/bin`
- `seven-country` is installed in `/usr/local/bin`
- `sevenosctl` is still installed as a legacy compatibility helper
- `/etc/os-release` identifies the live system as SevenOS
- `seven ecosystem` exposes the innovation roadmap

## Current Scope

Implemented:

- Archiso profile
- package set
- live environment branding
- repository injection
- ISO build script

Still planned:

- graphical installer through Calamares
- Archinstall automation bridge for advanced/non-GUI paths
- SevenOS boot splash and theme assets
- hardware-specific package variants
- release signing and checksum workflow
