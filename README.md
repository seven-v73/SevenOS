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

For a public-style machine, install the managed SevenOS tree into `/opt/SevenOS`
and refresh the global command wrappers:

```bash
./install.sh system-install --yes
```

After the first install:

```bash
seven setup doctor
./install.sh language
seven post-install
seven status
seven doctor
```

Public update route from anywhere:

```bash
seven update check
seven update install --yes
seven update rollback
seven quality doctor
seven identity experience
seven identity open
seven upgrade --yes
```

This creates a SevenOS rollback snapshot, updates `/opt/SevenOS`, backs up
protected user state, refreshes command wrappers and then applies package/app
updates through the SevenOS route. `seven quality doctor` is the public
experience gate for health, native surfaces, update, mini OS readiness, Shell
runtime, Server/Deploy policy, release freeze and the SevenOS identity
experience. `seven identity experience` verifies the Prism-first OS signature:
native surfaces, language, themes, mini OS context and guided maintenance.
`seven identity open` shows the same signal as a native SevenOS surface.

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

Language repair route:

```bash
./install.sh language
seven language doctor
seven language set fr_FR.UTF-8
seven language set en_US.UTF-8
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
seven setup doctor
seven profile status
sevenpkg plan
sevenpkg profile-limits
sevenpkg forge sources
sevenpkg forge helper paru
sevenpkg forge install code --source pacman
sevenpkg studio packages --query blender
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
seven-help docs-index
seven-help doc architecture
seven-help future
```

The helper contains installation details, shortcuts, mini OS behavior, package
scopes, repair routes, Windows Bridge setup, developer checks and the full
`docs/` architecture reference.

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
