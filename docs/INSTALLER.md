# SevenOS Installer Direction

SevenOS does not yet install itself to disk from the live ISO.

The current ISO is a live environment that contains the SevenOS repository at:

```text
/opt/SevenOS
```

The current installer implementation is a non-destructive planning TUI:

```bash
./install.sh installer-plan
./install.sh installer-check
./install.sh installer-script
```

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
