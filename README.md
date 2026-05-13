# SevenOS

SevenOS is an experimental Arch Linux based system layer focused on a modern Hyprland desktop, modular work profiles, security tooling, creative production, and Windows compatibility.

This repository currently targets **Phase 1**: a reproducible post-install setup for an existing Arch Linux installation. It is not yet a complete ISO or standalone distribution.

## Vision

SevenOS aims to provide:

- a lightweight Arch Linux foundation
- a Wayland desktop based on Hyprland
- modular profiles for development, cybersecurity, and creation
- Windows application compatibility through Wine, Bottles, Lutris, and later KVM/QEMU
- a future Seven Hub control center
- an afro-futurist visual identity with dark, gold, and earth-tone accents

## Current Status

Implemented:

- repository structure
- base installer entrypoint
- modular profile scripts
- package manifests
- starter Hyprland, Waybar, and Rofi configuration
- placeholders for VM, security, Seven Hub, and ISO work

Not implemented yet:

- full Arch installation automation
- ISO generation
- Seven Hub GUI
- automated Windows VM provisioning
- GPU passthrough automation

## Repository Layout

```text
SevenOS/
├── install.sh
├── bootstrap.sh
├── profiles/
│   ├── dev.sh
│   ├── cybersecurity.sh
│   ├── creation.sh
│   ├── windows.sh
│   └── all.sh
├── hyprland/
│   ├── hyprland.conf
│   ├── waybar/
│   └── rofi/
├── scripts/
│   ├── lib.sh
│   ├── packages-base.txt
│   ├── packages-dev.txt
│   ├── packages-cybersecurity.txt
│   ├── packages-creation.txt
│   └── packages-windows.txt
├── vm/
├── security/
├── seven-hub/
└── archiso/
```

## Requirements

- Arch Linux or Arch-based system
- `pacman`
- `sudo`
- internet connection
- 8 GB RAM minimum, 16 GB recommended
- CPU virtualization support for future VM workflows

## Usage

Clone the repository:

```bash
git clone https://github.com/seven-v73/SevenOS.git
cd SevenOS
```

Install the base desktop layer:

```bash
chmod +x install.sh bootstrap.sh profiles/*.sh
./install.sh base
```

Install a profile:

```bash
./install.sh dev
./install.sh cybersecurity
./install.sh creation
./install.sh windows
./install.sh security
```

Check whether the current host is ready for SevenOS features:

```bash
./install.sh doctor
```

Install everything:

```bash
./install.sh all
```

Preview without installing packages:

```bash
./install.sh dev --dry-run
```

Run local checks:

```bash
./scripts/check.sh
```

## Profiles

### DEV

Installs development tools such as Git, Node.js, Python, Rust, Docker, Helix, Neovim, and VS Code-compatible tooling where available.

### CYBERSECURITY

Installs security and network analysis tools such as Nmap, Wireshark, John the Ripper, Aircrack-ng, Metasploit, and related utilities.

Use responsibly and only on systems and networks where you have permission.

### CREATION

Installs creative tools such as GIMP, Krita, Inkscape, Blender, Kdenlive, OBS Studio, and audio/video utilities.

DaVinci Resolve is not installed automatically because it is not distributed through the official Arch repositories.

### WINDOWS

Installs compatibility tools such as Wine, Winetricks, Lutris, Flatpak, QEMU, and Virt Manager.

Bottles is expected to be installed later through Flatpak or an AUR workflow.

The installer configures Flathub, installs Bottles through Flatpak when possible, enables `libvirtd`, and adds the current user to the `libvirt` group.

### SECURITY

Installs a base hardening layer with UFW, Firejail, Bubblewrap, OpenSSH, GnuPG, KeePassXC, rkhunter, and Lynis.

The installer enables UFW with denied incoming traffic and allowed outgoing traffic by default.

Windows VM provisioning and GPU passthrough will be handled in later phases.

## Roadmap

### Phase 1

- Arch post-install scripts
- Hyprland desktop layer
- modular profiles
- package manifests
- first reproducible Git workflow

### Phase 2

- Seven Hub GUI
- profile toggles
- software management UI
- theme management

### Phase 3

- Archiso integration
- bootable SevenOS ISO
- installer flow

### Phase 4

- complete distribution packaging
- release channel
- hardware validation

### Phase 5

- SevenOS ecosystem
- app store
- cloud services
- deeper Windows integration

## License

License not selected yet.
