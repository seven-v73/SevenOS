# SevenOS

SevenOS is an experimental Arch Linux based ecosystem focused on a modern Hyprland desktop, modular work profiles, security tooling, creative production, Windows compatibility, and an African first product identity.

This repository currently contains foundations for **Phase 1, Phase 2, and Phase 3**: post-install setup, a lightweight Seven Hub control center, VM helpers, identity assets, and an early Archiso live profile. It is not yet a complete installable distribution.

## Vision

SevenOS aims to become an afro-futurist Linux ecosystem for productivity, creation, cybersecurity, Windows compatibility, and digital sovereignty.

It is built around three pillars:

- `seven` as the system controller
- `sevenpkg` as the package and application manager
- Seven Hub as the user-facing control center

SevenOS aims to provide:

- a lightweight Arch Linux foundation
- a Wayland desktop based on Hyprland
- modular profiles for development, cybersecurity, and creation
- Windows application compatibility through Wine, Bottles, Lutris, and later KVM/QEMU
- a Seven Hub control center
- an African first visual identity with obsidian, ancestral gold, clay, baobab green, and indigo accents
- a vocabulary and workflow model that makes Linux easier to live with

## Current Status

Implemented:

- repository structure
- base installer entrypoint
- modular profile scripts
- package manifests
- starter Hyprland, Waybar, and Rofi configuration
- Seven Hub MVP
- `seven` system controller
- `sevenpkg` package/application manager
- initial Archiso profile and ISO build script
- African first identity foundation
- placeholders for advanced VM work

Not implemented yet:

- full Arch installation automation
- final ISO installer flow
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
├── identity/
│   ├── README.md
│   ├── palette.sh
│   └── wallpaper/
├── scripts/
│   ├── lib.sh
│   ├── packages-base.txt
│   ├── packages-dev.txt
│   ├── packages-cybersecurity.txt
│   ├── packages-creation.txt
│   └── packages-windows.txt
├── vm/
├── security/
├── docs/
│   ├── VISION.md
│   ├── PRODUCT_STRATEGY.md
│   ├── UX_PRINCIPLES.md
│   └── VOCABULARY.md
├── seven-hub/
│   ├── bin/
│   ├── install.sh
│   └── seven-hub.desktop
└── archiso/
    └── profile/
```

## Requirements

- Arch Linux or Arch-based system
- `pacman`
- `sudo`
- internet connection
- 8 GB RAM minimum, 16 GB recommended
- CPU virtualization support for future VM workflows

## Product Direction

Start here before making strategic changes:

- `docs/VISION.md`
- `docs/PRODUCT_STRATEGY.md`
- `docs/UX_PRINCIPLES.md`
- `docs/VOCABULARY.md`
- `docs/OS_CRITERIA.md`

SevenOS is guided by one product question:

> Does this make Linux more sovereign, more fluid, more culturally coherent,
> and easier to live with every day?

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

The base layer installs packages, SevenOS branding, `sevenosctl`, the desktop theme, and the wallpaper.
It also installs the newer `seven` and `sevenpkg` commands.

Install a profile:

```bash
./install.sh dev
./install.sh cybersecurity
./install.sh cyber-audit
./install.sh cyber-lab --name webapp
./install.sh creation
./install.sh windows
./install.sh security
./install.sh cli
./install.sh branding
./install.sh theme
./install.sh hub
./install.sh iso-tools
./install.sh vm-check
./install.sh vm-network
./install.sh blackarch-setup --dry-run
./install.sh installer-plan
./install.sh installer-check
./install.sh installer-script
```

Check whether the current host is ready for SevenOS features:

```bash
./install.sh doctor
```

Show the current SevenOS installation status:

```bash
./install.sh status
seven status
seven welcome
seven dashboard
seven readiness
seven improve
seven improve security --apply --yes
seven windows status
sevenosctl status
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

Build a live ISO:

```bash
./install.sh iso-tools
./install.sh iso
```

Preview the ISO build commands:

```bash
./install.sh iso --dry-run
```

Check VM readiness:

```bash
./install.sh vm-check
```

Start the libvirt default network:

```bash
./install.sh vm-network
```

Preview a Windows VM creation command:

```bash
./install.sh vm-windows \
  --iso /path/to/windows.iso \
  --virtio-iso /path/to/virtio-win.iso \
  --os win11 \
  --dry-run
```

Create a non-destructive installation plan:

```bash
./install.sh installer-plan
./install.sh installer-check
./install.sh installer-script
```

The installer plan currently covers disk target, hostname, user, LUKS, filesystem, bootloader, timezone, locale, keymap, swap strategy, and SevenOS profiles.

Launch Seven Hub after installing it:

```bash
seven-hub
```

## Identity

SevenOS uses an African first identity system: dark graphite surfaces, ancestral gold for action, clay for signal, baobab green for system health, and restrained geometric rhythm inspired by African material culture.

The identity source of truth lives in `identity/README.md`.

The current desktop theme uses liquid glass surfaces, SevenOS SVG icons, and a rendered wallpaper applied through Hyprpaper.

For the complete icon experience, install the base profile package set, which includes `ttf-jetbrains-mono-nerd`.

SevenOS provides `sevenosctl`, a small CLI for daily system control:

```bash
seven status
seven welcome
seven dashboard
seven readiness
seven improve
seven doctor
seven profile forge
seven profile list
seven profile status
seven shield audit
seven-power
sevenpkg meta
sevenpkg status
sevenpkg info shield
sevenpkg install forge
sevenosctl status
sevenosctl doctor
sevenosctl hub
sevenosctl theme
sevenosctl branding
```

`seven` is the main SevenOS system controller. `sevenpkg` is the package and
application manager over pacman, paru, SevenOS meta-packages, and future
SevenRepo packages. See `docs/package-manager.md`.

Desktop controls:

```bash
seven-hub
seven-power
seven-power lock
```

Seven Hub is organized into focused spaces: Dashboard, Profiles, Cyber, Desktop,
VM & Windows, Installer, and Apps.

Apply only the desktop theme:

```bash
./install.sh theme
```

## Profiles

### DEV

Installs development tools such as Git, Node.js, Python, Rust, Docker, Helix, Neovim, and VS Code-compatible tooling where available.

### CYBERSECURITY

Installs a broad official Arch cybersecurity layer:

- core network, web, cracking, and exploitation tools
- forensic analysis tools
- reverse engineering tools
- wireless testing tools
- sandbox and isolation helpers

Audit the current machine:

```bash
./install.sh cyber-audit
```

Install by category when you do not want the full cyber layer:

```bash
./install.sh cybersecurity core
./install.sh cybersecurity forensics
./install.sh cybersecurity reversing
./install.sh cybersecurity wireless
./install.sh cybersecurity sandbox
```

Open an isolated lab shell:

```bash
./install.sh cyber-lab --name webapp
./install.sh cyber-lab --name reversing --offline
```

SevenOS also provides an optional BlackArch bridge for specialized tools:

```bash
./install.sh blackarch-setup --dry-run
./install.sh blackarch-setup --yes
./install.sh blackarch-category webapp
./install.sh blackarch-tool feroxbuster
```

BlackArch is opt-in because it adds an external package repository. SevenOS should stay stable for daily use, then scale up when deeper security work is needed.

Use responsibly and only on systems and networks where you have permission.

### CREATION

Installs creative tools such as GIMP, Krita, Inkscape, Blender, Kdenlive, OBS Studio, and audio/video utilities.

DaVinci Resolve is not installed automatically because it is not distributed through the official Arch repositories.

### WINDOWS

Installs compatibility tools such as Wine, Winetricks, Lutris, Flatpak, QEMU, and Virt Manager.

Bottles is expected to be installed later through Flatpak or an AUR workflow.

The installer configures Flathub, installs Bottles through Flatpak when possible, enables `libvirtd`, and adds the current user to the `libvirt` group.

Windows VM helpers:

```bash
./install.sh vm-check
./install.sh vm-network
./install.sh vm-windows \
  --iso /path/to/windows.iso \
  --virtio-iso /path/to/virtio-win.iso \
  --os win11
```

Use `--os win10` for a Windows 10 VM.

### SECURITY

Installs a base hardening layer with UFW, Firejail, Bubblewrap, OpenSSH, GnuPG, KeePassXC, rkhunter, and Lynis.

The installer enables UFW with denied incoming traffic and allowed outgoing traffic by default.

### SEVEN HUB

Installs a lightweight Rofi-based control center with terminal fallback. Seven Hub exposes the same installer targets as the CLI: status, doctor, base, profiles, Windows compatibility, security hardening, and dry-run preview.

Windows VM provisioning and GPU passthrough will be handled in later phases.

## Roadmap

### Phase 1

- Arch post-install scripts
- Hyprland desktop layer
- modular profiles
- package manifests
- first reproducible Git workflow

### Phase 2

- Seven Hub MVP
- profile launch actions
- Windows and VM launch actions
- dry-run installation preview

### Phase 3

- Archiso integration
- live SevenOS ISO profile
- non-destructive installer planning TUI
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

SevenOS is licensed under the MIT License. See `LICENSE`.
