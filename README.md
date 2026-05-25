# SevenOS

SevenOS is an Arch-based professional OS layer built around native system
surfaces, autonomous mini OS profiles and a SevenOS-first software workflow.

The project is currently in **test-machine consolidation before public ISO**.
It is usable for real hardware testing, but the final graphical ISO installer
and release channel are still being prepared.

## Install

Run SevenOS as a normal user. Do not use `sudo ./install.sh`; the installer asks
for administrator privileges only when a step needs them.

```bash
git clone https://github.com/seven-v73/SevenOS.git
cd SevenOS
chmod +x install.sh bootstrap.sh profiles/*.sh
./install.sh new-device --yes
```

After the first install:

```bash
seven post-install
seven status
seven doctor
```

Optional extended setup:

```bash
seven new --optional
seven new --optional --rootfs
```

Network/Wi-Fi repair route:

```bash
./install.sh network --yes
seven post-install
```

Build a live ISO from a prepared host:

```bash
./install.sh iso-tools --yes
./install.sh iso
```

## Daily Commands

```bash
seven-help
seven settings
seven home
seven store
seven profile status
sevenpkg plan
sevenpkg profile-limits
seven pre-push
```

## System Model

- Equinox is the main system/admin profile with access to the primary home and
  global Arch packages.
- Forge, Shield, Studio, Baobab, Windows and Pulse run as focused mini OS
  profiles with separated state and profile-scoped package roots.
- `sevenpkg` installs software through the SevenOS policy layer. Use
  `sevenpkg --help` or the graphical Settings/Store surfaces for normal use.
- SevenOS keeps pacman, yay, paru, Flatpak and system services behind
  SevenOS-first routes for public workflows.

## Local Help

The full guide lives inside SevenOS:

```bash
seven-help
seven-help-native
```

The helper contains installation details, shortcuts, mini OS behavior, package
scopes, repair routes, Windows Bridge setup and developer checks.

## Requirements

- Arch Linux or Arch-based host for the current post-install layer
- `pacman`, `sudo` and an internet connection
- 8 GB RAM minimum, 16 GB recommended
- CPU virtualization support for Windows Bridge / VM workflows

## Project References

- Product architecture: `docs/SYSTEM_EXPERIENCE_LAYER.md`
- Distribution autonomy: `docs/DISTRIBUTION_AUTONOMY.md`
- Test-machine consolidation: `docs/B3_CONSOLIDATION.md`
- Pre-push checks: `docs/PRE_PUSH.md`
