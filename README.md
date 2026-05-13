# SevenOS

SevenOS is an experimental Arch Linux based ecosystem focused on a modern Hyprland desktop, modular work profiles, security tooling, creative production, Windows compatibility, and an African first product identity.

This repository currently contains foundations for **Phase 1, Phase 2, Phase 3, and early Phase 4**: post-install setup, Seven Hub, `seven`/`sevenpkg`, VM helpers, identity assets, server/deploy foundations, repair planning, and an early Archiso live profile. It is not yet a complete installable distribution.

## Vision

SevenOS aims to become an afro-futurist Linux ecosystem for productivity, creation, cybersecurity, Windows compatibility, deployment, personal cloud workflows, and digital sovereignty.

It is built around three pillars:

- `seven` as the system controller
- `sevenpkg` as the package and application manager
- Seven Hub as the user-facing control center
- Seven Ecosystem as the roadmap for AI, cloud, marketplace, containers, automation, and identity modules

SevenOS aims to provide:

- a lightweight Arch Linux foundation
- a Wayland desktop based on Hyprland
- modular profiles for development, cybersecurity, and creation
- Windows application compatibility through Wine, Bottles, Lutris, and later KVM/QEMU
- local deployment through `seven-server` and `seven-deploy`
- future intelligent modules such as SevenAI, SevenCloud, SevenStore, SevenBox, SevenFlow, and SevenIdentity
- a Seven Hub control center
- an African first visual identity with obsidian, ancestral gold, clay, baobab green, and indigo accents
- a vocabulary and workflow model that makes Linux easier to live with

## Current Status

Implemented:

- repository structure
- base installer entrypoint
- modular profile scripts
- package manifests
- Hyprland, Waybar, Rofi, Kitty, Mako and Hyprpaper configuration
- Seven Hub MVP
- `seven` system controller
- `sevenpkg` package/application manager
- `seven repair` guided repair planner
- `seven ecosystem` innovation roadmap
- `seven-server` local API foundation
- `seven-deploy` deployment planner
- initial Archiso profile and ISO build script
- African first identity foundation
- Windows Mode helper workflow

Not implemented yet:

- full Arch installation automation
- final ISO installer flow
- Seven Hub GUI
- automated Windows VM provisioning
- GPU passthrough automation
- real SevenAI/SevenCloud/SevenStore implementations

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
- `docs/ECOSYSTEM.md`
- `docs/DEPLOYMENT.md`
- `docs/PHASE_GATE.md`
- `docs/TEST_MACHINE.md`
- `docs/PRE_PUSH.md`

SevenOS is guided by one product question:

> Does this make Linux more sovereign, more fluid, more culturally coherent,
> and easier to live with every day?

## Usage

For a complete test-machine flow, use:

```text
docs/TEST_MACHINE.md
```

Before pushing a phase to GitHub, use:

```text
docs/PRE_PUSH.md
```

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

Do not run `sudo ./install.sh ...`. The installer must run as your normal user;
it asks for `sudo` internally only when needed.

The base layer installs packages, SevenOS branding, `seven`, `sevenpkg`, the desktop theme, Kitty polish, terminal country signals, and the wallpaper.
`sevenosctl` remains available only as a legacy compatibility helper.

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
./install.sh server
```

Check whether the current host is ready for SevenOS features:

```bash
./install.sh doctor
./install.sh post-install
```

Show the current SevenOS installation status:

```bash
./install.sh status
seven status
seven post-install
seven welcome
seven hub
seven dashboard
seven ecosystem
seven ecosystem roadmap
seven readiness
seven phase-gate
seven repair
seven repair ux --apply
seven doctor fix
seven improve
seven improve security --apply --yes
seven windows status
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
./scripts/ux-check.sh
./scripts/phase-gate.sh
./scripts/post-install.sh
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
seven hub
```

The Rofi command palette remains available as `seven-hub`.

## Identity

SevenOS uses an African first identity system: dark graphite surfaces, ancestral gold for action, clay for signal, baobab green for system health, and restrained geometric rhythm inspired by African material culture.

The identity source of truth lives in `identity/README.md`.

The current desktop theme uses liquid glass surfaces, SevenOS SVG icons, and a rendered wallpaper applied through Hyprpaper.

For the complete icon experience, install the base profile package set, which includes `ttf-jetbrains-mono-nerd`.

The theme layer also writes GTK and Qt preferences so file manager windows,
settings dialogs, Rofi, Waybar, Kitty, Mako, and Seven Hub stay on the same
dark Sovereign Graphite identity instead of mixing white and black surfaces.

SevenOS provides `seven`, the main CLI for daily system control:

```bash
seven status
seven welcome
seven hub
seven dashboard
seven readiness
seven phase-gate
seven ecosystem
seven ecosystem roadmap
seven server status
seven deploy ./my-project
seven improve
seven doctor
seven profile forge
seven profile list
seven profile status
seven shield audit
seven files
seven files menu
seven-power
sevenpkg meta
sevenpkg status
sevenpkg info shield
sevenpkg install forge
```

`seven` is the main SevenOS system controller. `sevenpkg` is the package and
application manager over pacman, paru, SevenOS meta-packages, and future
SevenRepo packages. See `docs/package-manager.md`.

Desktop controls:

```bash
seven hub
seven-control-center open
seven-hub
seven-files
seven-files menu
seven-power
seven-power lock
```

`seven hub` opens the SevenOS Control Center dashboard. `seven-hub` opens the
keyboard-first command palette organized into focused spaces: Dashboard,
Profiles, Cyber, Desktop, VM & Windows, Server & Deploy, Ecosystem, Installer,
and Apps.

If the graphical dashboard cannot open a browser, it prints the local URL and
falls back to the `seven-hub` command palette.

`seven files` opens the SevenOS file experience. It prefers Nautilus for a
polished Wayland desktop and falls back to other file managers or `xdg-open`.
The base layer installs GVfs, archive support, network shares, phone mounting,
recent files, trash support, and quick previews.

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

The lab uses a private Firejail home and may show a prompt such as
`sevenos-webapp`. Type `exit` to return to your normal SevenOS shell before
running general `seven` commands.

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

Installs the SevenOS Control Center dashboard plus the Rofi command palette.
Both expose the same installer and `seven` actions as the CLI: status, doctor,
base, profiles, Windows compatibility, security hardening, deployment status,
theme repair, and dry-run preview.

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
