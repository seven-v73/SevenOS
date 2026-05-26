# Pulse Gaming Mini OS

Pulse is the SevenOS mini OS dedicated to Linux gaming. It keeps game launchers,
overlays, captures and tuning tools in the Pulse profile instead of spreading
them across Forge, Studio, Shield or Baobab.

## Boundaries

- Game launchers belong in the Pulse rootfs through `sevenpkg pulse install`.
- GPU drivers, kernel modules, Mesa and multilib stay on Equinox because the
  Linux kernel and GPU stack are shared by all mini OS profiles.
- Pulse should not install development, cyber, cloud or creator stacks.
- Steam, Lutris, Heroic, MangoHud and Gamescope are Pulse-owned user tools.

## Commands

```bash
seven pulse doctor
seven pulse plan --json
seven pulse install
seven pulse rootfs
seven pulse activate
seven-pulse launchers
seven-pulse hud
seven-pulse helper
sevenpkg pulse install steam --source pacman
sevenpkg pulse install lutris gamescope mangohud --source pacman
sevenpkg pulse install heroic-games-launcher-bin --source paru
sevenpkg pulse limits
```

## New Machine Flow

1. Run `seven pulse doctor`.
2. Install required Pulse basics with `seven pulse install`.
3. Prepare the private rootfs with `seven pulse rootfs`.
4. Enable Arch multilib on Equinox if Steam/Proton packages are unavailable.
5. Install launchers into Pulse with `seven-pulse launchers`.
6. Install HUD/frame pacing tools with `seven-pulse hud`.
7. Use `sevenpkg pulse packages` to verify what is private to Pulse.

## Public User Rule

The user should not need to know whether a package comes from pacman, paru or
yay for normal gaming setup. Pulse exposes simple actions first, while SevenPkg
keeps advanced source selection available for expert installs.
