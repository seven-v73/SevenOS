# SevenOS Installer Direction

SevenOS does not yet install itself to disk from the live ISO.

For testing on an already installed Arch machine, follow:

```text
docs/TEST_MACHINE.md
```

The current ISO is a live environment that contains the SevenOS repository at:

```text
/opt/SevenOS
```

The current installer implementation is a non-destructive planning TUI:

```bash
seven installer status --json
seven installer plan
seven installer plan --json
./install.sh installer-plan
./install.sh installer-check
./install.sh installer-script
```

`seven installer plan --json` is the machine-readable contract consumed by
Seven Hub, Seven Server and the Control Plane. It tracks Archinstall,
Calamares, Archiso and ISO build readiness before SevenOS becomes a public
installable distribution.

## Options Under Review

### Scripted TUI Installer

Best fit for early SevenOS:

- transparent Bash workflow
- easy to review
- aligned with current scripts
- less heavy than a full GUI installer

### Calamares

Good long-term option for a polished graphical install flow:

- mature distro installer
- partitioning UI
- localization support
- more packaging and maintenance overhead

### Custom Seven Hub Installer

Possible later:

- strongest brand fit
- more development work
- should only happen after CLI install flow is proven

## Current Recommendation

Build a scripted TUI installer first, then evaluate Calamares after the disk workflow is stable.

Until then, SevenOS should be tested as a post-install layer:

```bash
git clone https://github.com/seven-v73/SevenOS.git
cd SevenOS
./install.sh base --dry-run
./install.sh base --yes
seven phase-gate
```

## Minimum TUI Scope

- disk selection
- partition confirmation
- LUKS option
- filesystem selection
- bootloader selection
- timezone, locale, and keymap
- swap strategy
- base system install
- bootloader setup
- user creation
- profile selection
- post-install SevenOS bootstrap
